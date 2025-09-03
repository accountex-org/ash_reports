defmodule Cldr.Currencies.MixProject do
  use Mix.Project

  @version "2.16.5"

  def project do
    [
      app: :ex_cldr_currencies,
      version: @version,
      elixir: "~> 1.12",
      name: "Cldr Currencies",
      description: description(),
      source_url: "https://github.com/elixir-cldr/cldr_currencies",
      docs: docs(),
      build_embedded: Mix.env() == :prod,
      start_permanent: Mix.env() == :prod,
      elixirc_paths: elixirc_paths(Mix.env()),
      deps: deps(),
      package: package(),
      dialyzer: [
        ignore_warnings: ".dialyzer_ignore_warnings",
        plt_add_apps: ~w(inets jason mix)a,
        flags: [
          :error_handling,
          :unknown,
          :underspecs,
          :extra_return,
          :missing_return
        ]
      ]
    ]
  end

  defp description do
    """
    Currency localization data encapsulation functions for the Common Locale Data Repository (CLDR).
    """
  end

  def application do
    [
      extra_applications: [:logger]
    ]
  end

  defp deps do
    [
      {:ex_cldr, "~> 2.38"},
      {:jason, "~> 1.0", optional: true},
      {:ex_doc, "~> 0.18", only: [:dev, :release], runtime: false, optional: true},
      {:dialyxir, "~> 1.0", only: [:dev, :test], runtime: false},
      {:benchee, "~> 1.0", only: :dev, optional: true}
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

  def docs do
    [
      source_ref: "v#{@version}",
      main: "readme",
      extras: ["README.md", "CHANGELOG.md", "LICENSE.md"],
      logo: "logo.png",
      formatters: ["html"],
      skip_undefined_reference_warnings_on: ["changelog", "CHANGELOG.md"]
    ]
  end

  def links do
    %{
      "GitHub" => "https://github.com/elixir-cldr/cldr_currencies",
      "Readme" => "https://github.com/elixir-cldr/cldr_currencies/blob/v#{@version}/README.md",
      "Changelog" =>
        "https://github.com/elixir-cldr/cldr_currencies/blob/v#{@version}/CHANGELOG.md"
    }
  end

  defp elixirc_paths(:test), do: ["lib", "test"]
  defp elixirc_paths(:dev), do: ["lib", "mix"]
  defp elixirc_paths(_), do: ["lib"]
end
