defmodule Membrane.Telemetry.TimescaleDB.ModelTest do
  use Membrane.Telemetry.TimescaleDB.RepoCase

  alias Membrane.Telemetry.TimescaleDB.Repo
  alias Membrane.Telemetry.TimescaleDB.Model
  alias Membrane.Telemetry.TimescaleDB.Model.{Measurement, ComponentPath, Link}

  @measurement %{component_path: "path", metric: "metric", value: 10}
  @link %{
    parent_path: "pipeline@<480.0>",
    from: "from element",
    to: "to element",
    pad_from: "pad to",
    pad_to: "pad to"
  }

  # applying offset can ensure that any two measurements will be identical
  defp apply_time(model, offset \\ 0) do
    time =
      NaiveDateTime.utc_now()
      |> NaiveDateTime.add(offset, :microsecond)

    Map.put(model, :time, time)
  end

  describe "Model" do
    test "creates entries in 'measurements' and 'component_paths' tables" do
      assert Enum.empty?(Repo.all(Measurement))
      assert Enum.empty?(Repo.all(ComponentPath))

      assert {:ok, %{insert_all_measurements: 1}} =
               Model.add_all_measurements([apply_time(@measurement)])

      assert Enum.count(Repo.all(Measurement)) == 1
      assert Enum.count(Repo.all(ComponentPath)) == 1
    end

    test "creates Link entry" do
      assert Enum.empty?(Repo.all(Link))

      assert {:ok, _} = Link.changeset(%Link{}, apply_time(@link)) |> Repo.insert()

      assert Enum.count(Repo.all(Link)) == 1
    end

    test "creates ComponentPath uniquely" do
      # create two batches
      1..10 |> Enum.map(fn i -> apply_time(@measurement, i) end) |> Model.add_all_measurements()
      1..10 |> Enum.map(fn i -> apply_time(@measurement, i) end) |> Model.add_all_measurements()
      assert [component_path] = Repo.all(ComponentPath)
      assert component_path.path == @measurement.component_path

      assert Enum.count(Repo.all(Measurement)) == 20
    end

    test "returns error on incomplete Link" do
      assert {:error, %{valid?: false}} = Link.changeset(%Link{}, %{}) |> Repo.insert()
    end
  end
end
