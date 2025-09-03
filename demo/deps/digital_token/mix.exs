defmodule DigitalToken.MixProject do
  use Mix.Project

  @version "1.0.0"

  def project do
    [
      app: :digital_token,
      version: @version,
      elixir: "~> 1.10",
      name: "Digital Token",
      description: description(),
      source_url: "https://github.com/kipcole9/digital_token",
      docs: docs(),
      build_embedded: Mix.env() == :prod,
      start_permanent: Mix.env() == :prod,
      elixirc_paths: elixirc_paths(Mix.env()),
      deps: deps(),
      package: package(),
      dialyzer: [
        ignore_warnings: ".dialyzer_ignore_warnings",
        plt_add_apps: ~w(inets jason mix)a
      ]
    ]
  end

  defp description do
    """
    Elixir integration for ISO 24165 Digital Tokens (crypto currencies) through
    the DTIF registry data.
    """
  end

  def application do
    [
      extra_applications: [:logger]
    ]
  end

  defp deps do
    [
      {:cldr_utils, "~> 2.17"},
      {:jason, "~> 1.0", optional: true},
      {:ex_doc, "~> 0.18", only: [:dev, :release], optional: true, runtime: false},
      {:dialyxir, "~> 1.0", only: [:dev], runtime: false}
    ]
  end

  defp package do
    [
      maintainers: ["Kip Cole"],
      licenses: ["Apache-2.0"],
      links: links(),
      files: [
        "lib",
        "mix.exs",
        "README*",
        "CHANGELOG*",
        "LICENSE*",
        "priv/digital_token_registry.etf",
        "priv/digital_token_symbols.etf"
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
      "GitHub" => "https://github.com/kipcole9/digital_token",
      "Readme" => "https://github.com/kipcole9/digital_token/blob/v#{@version}/README.md",
      "Changelog" => "https://github.com/kipcole9/digital_token/blob/v#{@version}/CHANGELOG.md"
    }
  end

  defp elixirc_paths(:test), do: ["lib", "test", "mix"]
  defp elixirc_paths(:dev), do: ["lib", "mix"]
  defp elixirc_paths(_), do: ["lib"]
end
