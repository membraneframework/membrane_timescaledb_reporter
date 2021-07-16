defmodule Membrane.Telemetry.TimescaleDB.Model.Element do
  @moduledoc false
  require Logger
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key false
  schema "elements" do
    field(:time, :naive_datetime_usec)
    field(:path, :string)
    field(:terminated, :boolean)
  end

  def changeset(schema, params) do
    schema
    |> cast(params, [:time, :path, :terminated])
    |> validate_required([:time, :path, :terminated])
  end
end
