defmodule Membrane.Telemetry.TimescaleDB.Mixfile do
  use Mix.Project

  @version "0.1.0"
  @github_url "https://github.com/membraneframework/membrane_timescaledb_reporter"

  def project do
    [
      app: :membrane_timescaledb_reporter,
      version: @version,
      elixir: "~> 1.10",
      elixirc_paths: elixirc_paths(Mix.env()),
      start_permanent: Mix.env() == :prod,
      deps: deps(),

      # hex
      description: "Membrane Multimedia Framework (TimescaleDB metrics reporter)",
      package: package(),

      # docs
      name: "Membrane Telemetry TimescaleDB",
      source_url: @github_url,
      homepage_url: "https://membraneframework.org",
      docs: docs(),
      aliases: aliases()
    ]
  end

  def application do
    [
      extra_applications: [:logger],
      mod: {Membrane.Telemetry.TimescaleDB, []},
      start_phases: [migrate: []]
    ]
  end

  defp elixirc_paths(:test), do: ["lib", "test/support"]
  defp elixirc_paths(_env), do: ["lib"]

  defp deps do
    [
      {:ecto_sql, "~> 3.0"},
      {:telemetry, "~> 0.4"},
      {:postgrex, ">= 0.0.0"},
      {:dialyxir, "~> 1.0", only: [:dev], runtime: false},
      {:ex_doc, "~> 0.22", only: :dev, runtime: false}
    ]
  end

  defp package do
    [
      maintainers: ["Membrane Team"],
      licenses: ["Apache 2.0"],
      links: %{
        "GitHub" => @github_url,
        "Membrane Framework Homepage" => "https://membraneframework.org"
      }
    ]
  end

  defp docs do
    [
      main: "readme",
      extras: ["README.md", LICENSE: [title: "License"]],
      source_ref: "v#{@version}",
      nest_modules_by_prefix: [Membrane.Telemetry.TimescaleDB]
    ]
  end

  defp aliases do
    [
      test: ["ecto.create", "ecto.migrate", "test"]
    ]
  end
end
