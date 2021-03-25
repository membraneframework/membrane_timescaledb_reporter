defmodule Membrane.Telemetry.TimescaleDB.Metrics do
  @moduledoc """
  Lists all membrane core's metrics that are currently being handled.

  For more information about metric's event names and measurement types please refer to Membrane's Core hex documentation in `Membrane.Telemetry` module.
  """

  @type event_name_t :: [atom(), ...]

  @typedoc """
  Metric registration type.

  * `event_name` - event prefix to listen on
  * `cache?` - whether to cache incoming measurements before flushing (recomended for high frequency measurements)
  """
  @type metric_t :: %{
          event_name: event_name_t(),
          cache?: boolean()
        }

  @doc """
  Returns list of metrics hanled by TimescaleDB reporter.
  """
  @spec all() :: list(metric_t())
  def all() do
    [
      %{
        event_name: [:membrane, :input_buffer, :size],
        cache?: true
      },
      %{
        event_name: [:membrane, :mailbox, :size],
        cache?: true
      },
      %{
        event_name: [:membrane, :link, :new],
        cache?: false
      }
    ]
  end
end
