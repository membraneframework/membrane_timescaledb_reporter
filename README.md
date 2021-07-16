# Membrane.Telemetry.TimescaleDB

TimescaleDB metrics reporter for telemetry events emitted by [Membrane Core](https://hex.pm/packages/membrane_core).

Reporter attaches itself to [Telemetry package](https://hex.pm/packages/telemetry) and listens for events declared and documented in Membrane Core's module `Membrane.Telemetry`.

## Requirements
 - PostgreSQL server instance compatible with TimescaleDB extension.
 
 ** IMPORTANT **
 This reporter is only compatible with TimescaleDB version < 2.0. Make sure to use latest 1.* version.
 
 ### TODO
 Upgrade TimescaleDB to 2.*.

## Installation

To make use of the reporter you should add it as a dependency in your application along with `membrane_core`.

```elixir
def deps do
  [
    {:membrane_timescaledb_reporter, "~> 0.1.0"}
  ]
end
```

First of all you will need to enable telemetry in your `config.exs`:
```elixir
config :membrane_core,
  enable_telemetry: true
```

Additionally, provide database information inside your `config.exs` e.g: 
```elixir
config :membrane_timescaledb_reporter, Membrane.Telemetry.TimescaleDB.Repo,
  database: "membrane_timescaledb_reporter",
  username: "postgres",
  password: "postgres",
  hostname: "localhost",
  chunk_time_interval: "3 minutes",
  chunk_compress_policy_interval: "1 minute",
  log: false
```

There are two TimescaleDB specific attributes worth mentioning:
 - `chunk_time_interval` - used for hyper table creation, more in [documentation](https://docs.timescale.com/latest/api#hypertable-management)
 - `chunk_compress_policy_interval` - used as time interval for timescale's daemon compressing chunks, more in [documentation](https://docs.timescale.com/latest/api#add_compress_chunks_policy).

Adjust them accordingly to your membrane pipeline configuration and
amount of incoming events. For quick testing shorter intervals might be preferable as metrics can accumulate very fast. 

Last attribute - `log` - if is set to `false`, decreases number of logs for higher readibility and better performance.

Additional reporter options are:
```elixir
config :membrane_timescaledb_reporter,
  reporter_name: "membrane-timescaledb-handler",
  flush_timeout: 5000,
  flush_threshold: 1000
```

 - `reporter name` - name under which reporter will register its handler inside Telemetry package

 Some metrics can be sent hundreds times per second, to avoid database performance issues, measurements of certain event names are cached and later flushed to database in batches.
 - `flush_timeout` - timeout in miliseconds after which cached measurements will be flushed, no matter how many of them are currently in the buffer
 - `flush_threshold` - threshold after which cached measurements will be flushed to TimescaleDB  


## Database migrations
Application will try to perform auto migrations on application start due to `Membrane.Telemetry.TimescaleDB.start_phase/3`.

## Database Architecture
Reporter's repository will create three tables:

#### Table: measurements
**Used for generic measurements**

|      Column       |             Type            |
|:-----------------:|:---------------------------:|
|       time        | timestamp without time zone |
| component_path_id |           integer           |
|      metric       |    character varying(255)   |
|      value        |           integer           |

### Table: component_paths
**Helper table for registering element paths**

| Column |          Type          |
|:------:|:----------------------:|
|   id   |         bigint         |
|  path  | character varying(255) |


### Table: links
**Used for managing new link events**

|    Column   |             Type            |
|:-----------:|:---------------------------:|
|     time    | timestamp without time zone |
| parent_path |    character varying(255)   |
|     from    |    character varying(255)   |
|      to     |    character varying(255)   |
|   pad_from  |    character varying(255)   |
|    pad_to   |    character varying(255)   |


Tables `measurements` and `component_paths` are correlated via component_id from `measurements` table.
Full element paths can be quite lengthy and repeat frequently so they are stored in separate table.

Timescale will create hyper table based on `measurements` table and only this table will be chunked and further compressed.

## Copyright and License

Copyright 2020, [Software Mansion](https://swmansion.com/?utm_source=git&utm_medium=readme&utm_campaign=membrane)

[![Software Mansion](https://logo.swmansion.com/logo?color=white&variant=desktop&width=200&tag=membrane-github)](https://swmansion.com/?utm_source=git&utm_medium=readme&utm_campaign=membrane)

Licensed under the [Apache License, Version 2.0](LICENSE)
