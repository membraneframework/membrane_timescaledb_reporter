defmodule Membrane.Telemetry.TimescaleDB.Model.ComponentPath do
  @moduledoc false

  require Logger
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :id, autogenerate: true}
  schema "component_paths" do
    field(:path, :string)
  end

  def changeset(schema, params) do
    schema
    |> cast(params, [:path])
    |> validate_required([:path])
  end
end
