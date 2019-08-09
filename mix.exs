defmodule Speedtest.MixProject do
  use Mix.Project

  def project do
    [
      app: :speedtest,
      version: "0.1.0",
      elixir: "~> 1.8",
      build_embedded: Mix.env() == :prod,
      start_permanent: Mix.env() == :prod,
      description: description(),
      package: package(),
      deps: deps(),
      name: "Speedtest",
      source_url: "https://github.com/mithereal/speedtest.git"
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
      # {:dep_from_hexpm, "~> 0.3.0"},
      # {:dep_from_git, git: "https://github.com/elixir-lang/my_dep.git", tag: "0.1.0"}
      {:ex_doc, "~> 0.14", only: :dev, runtime: false},
      {:httpoison, "~> 1.5"},
      {:sweet_xml, "~> 0.6.6"},
      {:geocalc, "~> 0.5"},
      {:inch_ex, ">= 0.0.0", only: [:test, :dev]},
      {:mix_test_watch, "~> 0.8", only: :dev, runtime: false}
    ]
  end

  defp description() do
    "A Speedtest.net Client for Elixir"
  end

  defp package() do
    [
      # This option is only needed when you don't want to use the OTP application name
      name: "speedtest",
      # These are the default files included in the package
      files: ~w(lib .formatter.exs mix.exs README* LICENSE*),
      licenses: ["Apache-2.0"],
      links: %{"GitHub" => "https://github.com/mithereal/speedtest"}
    ]
  end
end
