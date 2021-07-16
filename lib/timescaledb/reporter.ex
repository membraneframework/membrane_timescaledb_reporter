defmodule Membrane.Telemetry.TimescaleDB.Reporter do
  @moduledoc """
  Receives measurements via `send_measurement/1` then, based on event names, eventually persists them to TimescaleDB database.
  """

  use GenServer
  require Logger
  alias Membrane.Telemetry.TimescaleDB.Model
  alias Membrane.Telemetry.TimescaleDB.TelemetryHandler

  @log_prefix "[#{__MODULE__}]"

  @spec start_link(any) :: :ignore | {:error, any} | {:ok, pid}
  def start_link(opts) do
    metrics =
      opts[:metrics] ||
        raise ArgumentError, "the `:metrics` options is required by #{inspect(__MODULE__)}"

    GenServer.start_link(__MODULE__, [metrics: metrics], name: __MODULE__)
  end

  @doc """
  Sends measurement to GenServer which, based on event name, will eventually persist it to database.

  Logs warning on invalid/unsupported measurement event name or format.

  ## Supported events
    * `[:membrane, :metric, :value]` - caches measurements to a certain threshold and flushes them to the database via `Membrane.Telemetry.TimescaleDB.Model.add_all_measurements/1`.
    * `[:membrane, :link, :new]` - instantly passes measurement to `Membrane.Telemetry.TimescaleDB.Model.add_link/1`.
    * `[:membrane, :pipeline | :bin | :element, :init | :terminate]` - instantly persists information about component being initialized or terminated
  """
  @spec send_measurement(list(atom()), map()) :: :ok
  def send_measurement(event_name, measurement)

  def send_measurement(
        [:membrane, :metric, :value] = event_name,
        %{component_path: path, metric: metric, value: value} = measurement
      )
      when is_binary(path) and is_binary(metric) and is_integer(value) do
    measurement =
      measurement
      |> Map.merge(%{
        component_path: extend_with_os_pid(path),
        time: NaiveDateTime.utc_now()
      })

    GenServer.cast(
      __MODULE__,
      {:measurement, event_name, measurement}
    )
  end

  def send_measurement(
        [:membrane, :link, :new],
        %{parent_path: parent_path, from: from, to: to, pad_from: pad_from, pad_to: pad_to} = link
      )
      when is_binary(parent_path) and is_binary(from) and is_binary(to) and is_binary(pad_from) and
             is_binary(pad_to) do
    link =
      link
      |> Map.merge(%{
        parent_path: extend_with_os_pid(parent_path),
        time: NaiveDateTime.utc_now()
      })

    GenServer.cast(
      __MODULE__,
      {:link, link}
    )
  end

  def send_measurement([:membrane, element_type, event_type], %{path: _path} = measurement)
      when element_type in [:pipeline, :bin, :element] and event_type in [:init, :terminate] do
    GenServer.cast(
      __MODULE__,
      {:lifecycle_event, element_type,
       Map.put(measurement, :terminated, event_type == :terminate)}
    )
  end

  def send_measurement(event_name, measurement) do
    Logger.warn(
      "#{__MODULE__}: Either event name: #{inspect(event_name)} or measurement format: #{inspect(measurement)} is not supported"
    )
  end

  @doc """
  Flushes cached measurements to the database.
  """
  @spec flush() :: :ok
  def flush() do
    GenServer.cast(__MODULE__, :flush)
  end

  @doc """
  Resets cached measurements.
  """
  @spec reset() :: :ok
  def reset() do
    GenServer.cast(__MODULE__, :reset)
  end

  @doc """
  Returns cached measurements.
  """
  @spec get_cached_measurements() :: list(map())
  def get_cached_measurements() do
    GenServer.call(__MODULE__, :get_cached_measurements)
  end

  @doc """
  Returns list of metrics registered by GenServer.
  """
  @spec get_metrics() :: list(list(atom()))
  def get_metrics() do
    GenServer.call(__MODULE__, :metrics)
  end

  @impl true
  def init(metrics: metrics) do
    Process.flag(:trap_exit, true)
    Membrane.Telemetry.TimescaleDB.TelemetryHandler.register_metrics(metrics)

    flush_timeout = Application.get_env(:membrane_timescaledb_reporter, :flush_timeout, 5000)
    flush_threshold = Application.get_env(:membrane_timescaledb_reporter, :flush_threshold, 1000)

    Process.send_after(self(), :force_flush, flush_timeout)

    {:ok,
     %{
       measurements: [],
       flush_timeout: flush_timeout,
       flush_threshold: flush_threshold,
       metrics: metrics
     }}
  end

  @impl true
  def handle_cast(
        {:measurement, event_name, measurement},
        %{metrics: metrics} = state
      ) do
    cache? = Enum.find(metrics, %{cache?: false}, &(&1.event_name == event_name)).cache?
    state = process_measurement({measurement, cache?}, state)
    {:noreply, state}
  end

  def handle_cast({:link, link}, state) do
    case Model.add_link(link) do
      {:ok, _} ->
        Logger.debug("#{@log_prefix} Added new link")

      {:error, reason} ->
        Logger.error("#{@log_prefix} Error while adding new link: #{inspect(reason)}")
    end

    {:noreply, state}
  end

  # ignore pipeline events
  def handle_cast({:lifecycle_event, type, measurement}, state) when type in [:bin, :element] do
    case Model.add_element_event(Map.put(measurement, :time, NaiveDateTime.utc_now())) do
      {:ok, _} ->
        Logger.debug("#{@log_prefix} Added #{type} event")

      {:error, reason} ->
        Logger.error("#{@log_prefix} Error while adding #{type} event: #{inspect(reason)}")
    end

    {:noreply, state}
  end

  def handle_cast({:lifecycle_event, _type, _measurement}, state) do
    {:noreply, state}
  end

  def handle_cast(:flush, %{measurements: measurements} = state) do
    flush_measurements(measurements)
    {:noreply, %{state | measurements: []}}
  end

  def handle_cast(:reset, state) do
    {:noreply, %{state | measurements: []}}
  end

  @impl true
  def handle_call(:get_cached_measurements, _from, %{measurements: measurements} = state) do
    {:reply, measurements, state}
  end

  def handle_call(:metrics, _from, %{metrics: metrics} = state) do
    {:reply, metrics, state}
  end

  @impl true
  def handle_info(:force_flush, %{flush_timeout: flush_timeout} = state) do
    Logger.debug("#{@log_prefix} Reached flush timeout: #{flush_timeout}, flushing...")
    flush()
    Process.send_after(self(), :force_flush, flush_timeout)
    {:noreply, state}
  end

  @impl true
  def terminate(reason, _state) do
    Logger.debug(
      "#{__MODULE__}.terminate/2 called with reason #{inspect(reason)}, unregistering handler"
    )

    TelemetryHandler.unregister_handler()
  end

  defp extend_with_os_pid(path) do
    String.replace_prefix(path, "pipeline@", "pipeline@#{System.pid()}@")
  end

  defp process_measurement(
         {measurement, cache?},
         %{measurements: measurements, flush_threshold: flush_threshold} = state
       )
       when cache? == true do
    measurements = [measurement | measurements]

    if length(measurements) >= flush_threshold do
      flush_measurements(measurements)
      %{state | measurements: []}
    else
      %{state | measurements: measurements}
    end
  end

  defp process_measurement({measurement, cache?}, state) when cache? == false do
    case Model.add_measurement(measurement) do
      {:ok, _} ->
        Logger.debug("#{@log_prefix} Added new measurement")

      {:error, reason} ->
        Logger.error("#{@log_prefix} Error while adding new measurement: #{inspect(reason)}")
    end

    state
  end

  defp flush_measurements(measurements) when length(measurements) > 0 do
    case Model.add_all_measurements(measurements) do
      {:ok, %{insert_all_measurements: inserted}} ->
        Logger.debug("#{@log_prefix} Flushed #{inserted} measurements")

      {:error, operation, value, changes} ->
        Logger.error("#{@log_prefix} Encountered error: #{operation} #{value} #{changes}")
    end
  end

  defp flush_measurements(_) do
    :ok
  end
end
