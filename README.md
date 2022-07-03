# Speedtest


[![Hex Docs](https://img.shields.io/badge/hex-docs-lightgreen.svg)](https://hexdocs.pm/speedtest/)
[![Hex.pm](https://img.shields.io/hexpm/dt/speedtest.svg)](https://hex.pm/packages/speedtest)
[![License](https://img.shields.io/hexpm/l/speedtest.svg)](https://github.com/mithereal/ex_gasoline_price/blob/master/LICENSE)
[![Last Updated](https://img.shields.io/github/last-commit/mithereal/ex_speedtest.svg)](https://github.com/mithereal/ex_speedtest/commits/master)

**Elixir module for testing internet bandwidth using speedtest.net**

## Installation

If [available in Hex](https://hex.pm/docs/publish), the package can be installed
by adding `speedtest` to your list of dependencies in `mix.exs`:

```elixir
def deps do
  [
    {:speedtest, "~> 1.1.0"}
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

