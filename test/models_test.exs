defmodule Membrane.Telemetry.TimescaleDB.ModelTest do
  use Membrane.Telemetry.TimescaleDB.RepoCase

  alias Membrane.Telemetry.TimescaleDB.Repo
  alias Membrane.Telemetry.TimescaleDB.Model
  alias Membrane.Telemetry.TimescaleDB.Model.{Measurement, ElementPath, Link}

  @measurement %{element_path: "path", metric: "metric", value: 10}
  @link %{
    parent_path: "pipeline@<480.0>",
    from: "from element",
    to: "to element",
    pad_from: "pad to",
    pad_to: "pad to"
  }

  defp apply_time(model) do
    Map.put(model, :time, NaiveDateTime.utc_now())
  end

  describe "Model" do
    test "creates entries in 'measurements' and 'element_paths' tables" do
      assert Enum.empty?(Repo.all(Measurement))
      assert Enum.empty?(Repo.all(ElementPath))

      assert {:ok, %{insert_all_measurements: 1}} =
               Model.add_all_measurements([apply_time(@measurement)])

      assert Enum.count(Repo.all(Measurement)) == 1
      assert Enum.count(Repo.all(ElementPath)) == 1
    end

    test "creates Link entry" do
      assert Enum.empty?(Repo.all(Link))

      assert {:ok, _} = Link.changeset(%Link{}, apply_time(@link)) |> Repo.insert()

      assert Enum.count(Repo.all(Link)) == 1
    end

    test "creates ElementPath uniquely" do
      # create two batches
      1..10 |> Enum.map(fn _ -> apply_time(@measurement) end) |> Model.add_all_measurements()
      1..10 |> Enum.map(fn _ -> apply_time(@measurement) end) |> Model.add_all_measurements()

      assert [element_path] = Repo.all(ElementPath)
      assert element_path.path == @measurement.element_path

      assert Enum.count(Repo.all(Measurement)) == 20
    end

    test "returns error on duplicated Measurement" do
      measurement = apply_time(@measurement)
      result = [measurement, measurement] |> Model.add_all_measurements()
      assert {:error, %Postgrex.Error{postgres: %{code: :unique_violation}}} = result
    end

    test "returns error on incomplete Link" do
      assert {:error, %{valid?: false}} = Link.changeset(%Link{}, %{}) |> Repo.insert()
    end
  end
end
