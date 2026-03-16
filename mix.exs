defmodule Cldr.Collation.MixProject do
  use Mix.Project

  @version "1.0.0"

  def project do
    [
      app: :ex_cldr_collation,
      version: @version,
      name: "Cldr Collation",
      docs: docs(),
      source_url: "https://github.com/elixir-cldr/cldr_collation",
      elixir: "~> 1.12",
      build_embedded: Mix.env() == :prod,
      start_permanent: Mix.env() == :prod,
      compilers: maybe_elixir_make() ++ Mix.compilers(),
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
      mod: {Cldr.Collation.Application, []},
      extra_applications: [:logger]
    ]
  end

  defp description do
    """
    Elixir implementation of the Cldr Collation algorithm, providing
    language-aware string sorting and comparison. An opt-in NIF is
    provided for high performance collating.
    """
  end

  defp deps do
    [
      {:unicode, "~> 1.21"},
      {:ex_cldr, "~> 2.40", optional: true},
      {:elixir_make, "~> 0.4", runtime: false, optional: true},
      {:benchee, "~> 1.0", only: :dev, runtime: false},
      {:ex_doc, "~> 0.19", only: :dev, runtime: false, optional: true},
      {:dialyxir, "~> 1.4", only: [:dev, :test], runtime: false}
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
        "priv/FractionalUCA.txt",
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
      "GitHub" => "https://github.com/elixir-cldr/cldr_collation",
      "Readme" => "https://github.com/elixir-cldr/cldr_collation/blob/v#{@version}/README.md",
      "Changelog" =>
        "https://github.com/elixir-cldr/cldr_collation/blob/v#{@version}/CHANGELOG.md"
    }
  end

  def docs do
    [
      source_ref: "v#{@version}",
      main: "readme",
      extras: [
        "README.md",
        "LICENSE.md",
        "CHANGELOG.md",
        "COLLATION_OPTIONS.md"
      ],
      formatters: ["html", "markdown"],
      skip_undefined_reference_warnings_on: ["changelog", "CHANGELOG.md"]
    ]
  end

  # Only add the :elixir_make compiler when the NIF build is opted-in
  # via the CLDR_COLLATION_NIF=true environment variable or by setting
  # `config :ex_cldr_collation, :nif, true` in config.exs.
  defp maybe_elixir_make do
    if nif_enabled?() do
      [:elixir_make]
    else
      []
    end
  end

  defp elixirc_paths(:test), do: ["lib", "mix", "c_src", "test"]
  defp elixirc_paths(:dev), do: ["lib", "mix", "c_src"]
  defp elixirc_paths(_), do: ["lib", "c_src"]

  @doc false
  def nif_enabled? do
    String.downcase(System.get_env("CLDR_COLLATION_NIF", "false")) == "true" or
      Application.get_env(:ex_cldr_collation, :nif, false) == true
  end
end
