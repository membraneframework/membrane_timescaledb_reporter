defmodule Membrane.Telemetry.TimescaleDB.Model.Measurement do
  @moduledoc false

  use Ecto.Schema
  import Ecto.Changeset

  @primary_key false
  schema "measurements" do
    field(:time, :naive_datetime_usec)
    field(:component_path_id, :id)
    field(:metric, :string)
    field(:value, :integer)
  end

  def changeset(schema, params) do
    schema
    |> cast(params, [:time, :component_path_id, :metric, :value])
    |> validate_required([:time, :component_path_id, :metric, :value])
  end
end
