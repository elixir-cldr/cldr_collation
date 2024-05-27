defmodule CldrCollation.MixProject do
  use Mix.Project

  @version "0.7.3"

  def project do
    [
      app: :ex_cldr_collation,
      version: @version,
      name: "Cldr Collation",
      docs: docs(),
      source_url: "https://github.com/elixir-cldr/cldr_collation",
      elixir: "~> 1.10",
      build_embedded: Mix.env() == :prod,
      start_permanent: Mix.env() == :prod,
      compilers: [:elixir_make] ++ Mix.compilers(),
      deps: deps(),
      elixirc_paths: elixirc_paths(Mix.env()),
      make_makefile: "c_src/Makefile",
      description: description(),
      package: package(),
      dialyzer: [
        ignore_warnings: ".dialyzer_ignore_warnings",
        plt_add_apps: ~w(inets mix)a
      ]
    ]
  end

  def application do
    [
      extra_applications: [:logger, :inets]
    ]
  end

  defp description do
    """
    Common Locale Data Repository (CLDR) icu4c NIF-based collator providing Unicode
    default collation sorting. Useful sorting not-ASCII strings.
    """
  end

  defp deps do
    [
      {:elixir_make, "~> 0.4", runtime: false},
      {:ex_doc, "~> 0.19", only: :dev, runtime: false, optional: true},
      {:dialyxir, "~> 1.4", only: [:dev], runtime: false}
    ]
  end

  defp package do
    [
      maintainers: ["Kip Cole"],
      licenses: ["Apache-2.0"],
      links: links(),
      files: [
        "lib",
        "c_src/platform",
        "c_src/*.c",
        "c_src/Makefile",
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
      "GitHub" => "https://github.com/kipcole9/cldr_collation",
      "Readme" => "https://github.com/kipcole9/cldr_collation/blob/v#{@version}/README.md",
      "Changelog" => "https://github.com/kipcole9/cldr_collation/blob/v#{@version}/CHANGELOG.md",
    }
  end

  def docs do
    [
      source_ref: "v#{@version}",
      main: "readme",
      extras: [
        "README.md",
        "LICENSE.md",
        "CHANGELOG.md"
      ],
      skip_undefined_reference_warnings_on: ["changelog", "CHANGELOG.md"]
    ]
  end

  defp elixirc_paths(:test), do: ["lib", "mix", "c_src", "test"]
  defp elixirc_paths(:dev), do: ["lib", "mix", "c_src"]
  defp elixirc_paths(_), do: ["lib", "c_src"]
end
