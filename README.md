# Speedtest

**Elixir module for testing internet bandwidth using speedtest.net**

## Installation

If [available in Hex](https://hex.pm/docs/publish), the package can be installed
by adding `speedtest` to your list of dependencies in `mix.exs`:

```elixir
def deps do
  [
    {:speedtest, "~> 1.0.0"}
  ]
end
```

## Usage

```elixir
iex> Speedtest.run()
```

## Configuration (optional)
```elixir
config :speedtest,
 key: "xxx",
threads: nil,
 include: nil,
exclude: nil
```

Documentation can be generated with [ExDoc](https://github.com/elixir-lang/ex_doc)
and published on [HexDocs](https://hexdocs.pm). Once published, the docs can
be found at [https://hexdocs.pm/speedtest](https://hexdocs.pm/speedtest).

