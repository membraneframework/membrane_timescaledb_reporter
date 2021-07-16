defmodule Membrane.Telemetry.TimescaleDB.Repo.Migrations.CreateExtensionTimescaledb do
  use Ecto.Migration

  alias Membrane.Telemetry.TimescaleDB.Repo

  @chunk_time_interval Application.get_env(:membrane_timescaledb_reporter, Repo)[:chunk_time_interval] || "1 minute"
  @chunk_compress_policy_interval Application.get_env(:membrane_timescaledb_reporter,Repo)[:chunk_compress_policy_interval] || "1 minute"

  def up() do
    create table(:component_paths, primary_key: {:id, :id, autogenerate: true}) do
      add(:path, :string, null: false)
    end

    create unique_index(:component_paths, :path)

    execute("CREATE EXTENSION IF NOT EXISTS timescaledb CASCADE")


    create table(:measurements, primary_key: false) do
      add(:time, :naive_datetime_usec, null: false)
      add(:component_path_id, references(:component_paths), null: false)
      add(:metric, :string, null: false)
      add(:value, :integer, null: false)
    end

    execute("SELECT create_hypertable('measurements', 'time', chunk_time_interval => INTERVAL '#{@chunk_time_interval}')")

    execute("""
    ALTER TABLE measurements SET (
      timescaledb.compress,
      timescaledb.compress_segmentby = 'component_path_id,metric'
    );
    """)

    execute("SELECT add_compress_chunks_policy('measurements', INTERVAL '#{@chunk_compress_policy_interval}')")
  end


  def down() do
    drop table(:component_paths)
    drop table(:measurements)
    execute("DROP EXTENSION IF EXISTS timescaledb CASCADE")
  end
end
