defmodule Speedtest.MixProject do
  use Mix.Project

  @version "1.2.1"
  @source_url "https://github.com/mithereal/ex_speedtest"

  def project do
    [
      app: :speedtest,
      version: @version,
      elixir: "~> 1.11",
      build_embedded: Mix.env() == :prod,
      start_permanent: Mix.env() == :prod,
      description: description(),
      package: package(),
      deps: deps(),
      docs: docs(),
      name: "Speedtest",
      source_url: @source_url
    ]
  end

  def application do
    [
      extra_applications: [:logger, :crypto]
    ]
  end

  defp deps do
    [
      {:ex_doc, "~> 0.34", only: :dev, runtime: false},
      {:httpoison, "~> 2.2"},
      {:jason, "~> 1.4"},
      {:geocalc, "~> 0.8.5"},
      {:inch_ex, only: :docs},
      {:mix_audit, ">= 0.0.0", only: [:dev, :test], runtime: false},
      {:mox, "~> 1.1", only: :test}
    ]
  end

  defp description do
    "A Speedtest.net Client for Elixir"
  end

  defp package do
    [
      name: "speedtest",
      files: ~w(lib .formatter.exs mix.exs README* LICENSE* CHANGELOG*),
      licenses: ["Apache-2.0"],
      links: %{
        "Changelog" => "#{@source_url}/blob/master/CHANGELOG.md",
        "GitHub" => @source_url
      }
    ]
  end

  defp docs do
    [
      main: "readme",
      name: "Speedtest",
      source_ref: "v#{@version}",
      canonical: "https://hexdocs.pm/speedtest",
      source_url: @source_url,
      extras: ["README.md", "CHANGELOG.md", "LICENSE"]
    ]
  end
end
