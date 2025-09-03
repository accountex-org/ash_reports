defmodule Cldr.Utils.MixProject do
  use Mix.Project

  @version "2.28.3"
  @source_url "https://github.com/elixir-cldr/cldr_utils"

  def project do
    [
      app: :cldr_utils,
      version: @version,
      elixir: "~> 1.12",
      description: description(),
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      package: package(),
      docs: docs(),
      test_coverage: [tool: ExCoveralls],
      aliases: aliases(),
      elixirc_paths: elixirc_paths(Mix.env()),
      dialyzer: [
        ignore_warnings: ".dialyzer_ignore_warnings",
        plt_add_apps: ~w(inets decimal certifi castore)a
      ],
      compilers: Mix.compilers()
    ]
  end

  defp description do
    """
    Map, Calendar, Digits, Decimal, HTTP, Macro, Math, and String helpers for ex_cldr.
    """
  end

  def application do
    [
      extra_applications: [:logger, :inets, :ssl]
    ]
  end

  defp deps do
    [
      {:decimal, "~> 1.9 or ~> 2.0"},
      {:castore, "~> 0.1 or ~> 1.0", optional: true},
      {:certifi, "~> 2.5", optional: true},
      {:ex_doc, ">= 0.0.0", optional: true, only: [:dev, :release], runtime: false},
      {:stream_data, "~> 1.0", optional: true, only: :test},
      {:dialyxir, "~> 1.0", optional: true, only: [:dev, :test], runtime: false},
      {:benchee, "~> 1.0", optional: true, only: [:dev], runtime: false}
    ]
  end

  defp package do
    [
      maintainers: ["Kip Cole"],
      licenses: ["Apache-2.0"],
      links: links(),
      files: [
        "lib",
        "config",
        "mix.exs",
        "README*",
        "CHANGELOG*",
        "LICENSE*"
      ]
    ]
  end

  def links do
    %{
      "GitHub" => @source_url,
      "Readme" => "#{@source_url}/blob/v#{@version}/README.md",
      "Changelog" => "#{@source_url}/blob/v#{@version}/CHANGELOG.md"
    }
  end

  def docs do
    [
      extras: [
        "CHANGELOG.md",
        "LICENSE.md",
        "README.md"
      ],
      main: "readme",
      source_url: @source_url,
      source_ref: "v#{@version}",
      formatters: ["html"],
      logo: "logo.png",
      skip_undefined_reference_warnings_on: ["CHANGELOG.md"]
    ]
  end

  defp elixirc_paths(:test), do: ["lib", "mix", "test"]
  defp elixirc_paths(:dev), do: ["lib", "mix", "benchee"]
  defp elixirc_paths(_), do: ["lib"]

  def aliases do
    []
  end
end
