# Benchmark: NIF vs Pure Elixir Collation Sorting
#
# Compares sorting performance between the ICU NIF backend and the pure Elixir
# implementation across different string lengths and casing modes.
#
# Run with:
#   CLDR_COLLATION_NIF=true mix compile && mix run bench/sort_benchmark.exs

unless Cldr.Collation.Nif.available?() do
  IO.puts("""
  \e[31mError: NIF backend is not available.\e[0m

  Compile with NIF support first:

      CLDR_COLLATION_NIF=true mix compile

  Then run the benchmark:

      mix run bench/sort_benchmark.exs
  """)

  System.halt(1)
end

# Ensure collation tables are loaded before benchmarking
Cldr.Collation.ensure_loaded()

# --- Data Generation ---

# Character ranges for random string generation:
# Latin, accented Latin, Greek, Cyrillic
character_ranges = [
  ?a..?z,
  ?A..?Z,
  0x00C0..0x00FF,
  0x0100..0x017F,
  0x0391..0x03C9,
  0x0410..0x044F
]

all_chars =
  character_ranges
  |> Enum.flat_map(&Enum.to_list/1)
  |> Enum.filter(fn cp ->
    try do
      <<cp::utf8>>
      true
    rescue
      _ -> false
    end
  end)

generate_string = fn length ->
  1..length
  |> Enum.map(fn _ -> Enum.random(all_chars) end)
  |> List.to_string()
end

# Use a fixed seed for reproducibility
:rand.seed(:exsss, {42, 42, 42})

list_size = 100

data =
  for length <- [5, 10, 20, 50], into: %{} do
    strings = Enum.map(1..list_size, fn _ -> generate_string.(length) end)
    {length, strings}
  end

IO.puts("Generated #{list_size} random Unicode strings at each length: 5, 10, 20, 50 chars")
IO.puts("Character set: Latin, accented Latin, Greek, Cyrillic\n")

# --- Benchmark ---

scenarios =
  for length <- [5, 10, 20, 50], casing <- [:sensitive, :insensitive], reduce: %{} do
    acc ->
      strings = data[length]
      casing_label = if casing == :sensitive, do: "cased", else: "uncased"
      strength = if casing == :sensitive, do: :tertiary, else: :secondary

      nif_key = "NIF #{casing_label} (#{length} chars)"
      elixir_key = "Elixir #{casing_label} (#{length} chars)"

      acc
      |> Map.put(nif_key, fn ->
        Cldr.Collation.sort(strings, backend: :nif, casing: casing)
      end)
      |> Map.put(elixir_key, fn ->
        Cldr.Collation.sort(strings, backend: :elixir, strength: strength)
      end)
  end

Benchee.run(
  scenarios,
  warmup: 2,
  time: 5,
  memory_time: 2,
  print: [
    configuration: true,
    benchmarking: true
  ]
)
