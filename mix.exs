defmodule CldrCollation.MixProject do
  use Mix.Project

  def project do
    [
      app: :cldr_collation,
      version: "0.1.0",
      elixir: "~> 1.7",
      start_permanent: Mix.env() == :prod,
      compilers: [:elixir_make] ++ Mix.compilers(),
      deps: deps(),
      elixirc_paths: elixirc_paths(Mix.env()),
      make_makefile: "c_src/Makefile"
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
      {:elixir_make, "~> 0.4", runtime: false}
    ]
  end

  defp elixirc_paths(:test), do: ["lib", "mix", "src", "c_src", "test"]
  defp elixirc_paths(:dev), do: ["lib", "mix", "src", "c_src"]
  defp elixirc_paths(_), do: ["lib", "src", "c_src"]
end
