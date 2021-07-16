defmodule Membrane.Telemetry.TimescaleDB.Repo.Migrations.AddLinksTable do
  use Ecto.Migration

  def change do
    create table(:links, primary_key: false) do
      add(:time, :naive_datetime_usec, null: false)
      add(:parent_path, :string, null: false)
      add(:from, :string, null: false)
      add(:to, :string, null: false)
      add(:pad_from, :string, null: false)
      add(:pad_to, :string, null: false)
    end
  end
end
