defmodule Membrane.Telemetry.TimescaleDB.Metrics do
  @moduledoc """
  Lists all membrane core's metrics that are currently being handled.

  For more information about metric's event names and measurement types please refer to Membrane's Core hex documentation in `Membrane.Telemetry` module.
  """

  @type event_name_t :: [atom(), ...]

  @typedoc """
  Metric registration type.

  * `event_name` - event prefix to listen on
  * `cache?` - whether to cache incoming measurements before flushing (recommended for high frequency measurements)
  """
  @type metric_t :: %{
          event_name: event_name_t(),
          cache?: boolean()
        }

  @doc """
  Returns list of metrics handled by TimescaleDB reporter.
  """
  @spec all() :: list(metric_t())
  def all() do
    [
      %{
        event_name: [:membrane, :metric, :value],
        cache?: true
      },
      %{
        event_name: [:membrane, :link, :new],
        cache?: false
      }
    ] ++
      Enum.flat_map([:bin, :element], fn type ->
        [
          %{event_name: [:membrane, type, :init], cache?: false},
          %{event_name: [:membrane, type, :terminate], cache?: false}
        ]
      end)
  end
end
