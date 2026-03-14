defmodule Cldr.Collation.Application do
  @moduledoc false

  use Application

  @impl true
  def start(_type \\ :normal, _args \\ []) do
    children = [
      Cldr.Collation.Table,
      Cldr.Collation.Han
    ]

    options = [strategy: :one_for_one, name: Cldr.Collation.Supervisor]
    Supervisor.start_link(children, options)
  end
end
