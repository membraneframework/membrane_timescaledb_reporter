defmodule Membrane.Telemetry.TimescaleDB.Repo.Migrations.AddElementTable do
  use Ecto.Migration

  def change do
    create table(:elements, primary_key: false) do
      add(:time, :naive_datetime_usec, null: false)
      add(:path, :string, null: false)
      add(:terminated, :bool, null: false)
    end

    create unique_index(:elements, [:path, :terminated])
  end
end
