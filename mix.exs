defmodule Cldr.Collation.MixProject do
  use Mix.Project

  @version "1.0.0"

  def project do
    [
      app: :ex_cldr_collation,
      version: @version,
      elixir: "~> 1.18",
      start_permanent: Mix.env() == :prod,
      compilers: maybe_elixir_make() ++ Mix.compilers(),
      make_makefile: "c_src/Makefile",
      deps: deps()
    ]
  end

  # Run "mix help compile.app" to learn about applications.
  def application do
    [
      mod: {Cldr.Collation.Application, []},
      extra_applications: [:logger]
    ]
  end

  # Run "mix help deps" to learn about dependencies.
  defp deps do
    [
      {:unicode, "~> 1.21"},
      {:ex_cldr, "~> 2.40", optional: true},
      {:elixir_make, "~> 0.4", runtime: false, optional: true},
      {:benchee, "~> 1.0", only: :dev, runtime: false}
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

  @doc false
  def nif_enabled? do
    System.get_env("CLDR_COLLATION_NIF") == "true" or
      Application.get_env(:ex_cldr_collation, :nif, false) == true
  end
end
