defmodule Speedtest.MixProject do
  use Mix.Project

  @version "1.1.0"
  @source_url "https://github.com/mithereal/ex_speedtest.git"

  def project do
    [
      app: :speedtest,
      version: @version,
      elixir: "~> 1.9",
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

  # Run "mix help compile.app" to learn about applications.
  def application do
    [
      extra_applications: [:logger]
    ]
  end

  # Run "mix help deps" to learn about dependencies.
  defp deps do
    [
      {:ex_doc, "~> 0.25", only: :dev, runtime: false},
      {:httpoison, "~> 1.8"},
      {:sweet_xml, "~> 0.7"},
      {:geocalc, "~> 0.8"},
      {:inch_ex, ">= 0.0.0", only: [:test, :dev]},
      {:mix_test_watch, "~> 0.8", only: :dev, runtime: false}
    ]
  end

  defp description() do
    "A Speedtest.net Client for Elixir"
  end

  defp package() do
    [
      name: "speedtest",
      files: ~w(lib .formatter.exs mix.exs README* LICENSE*),
      licenses: ["Apache-2.0"],
      links: %{"GitHub" => "https://github.com/mithereal/ex_speedtest"}
    ]
  end

  defp docs() do
    [
      main: "readme",
      name: "Speedtest",
      source_ref: "v#{@version}",
      canonical: "http://hexdocs.pm/speedtest",
      source_url: @source_url,
      extras: ["README.md", "LICENSE"]
    ]
  end
end
