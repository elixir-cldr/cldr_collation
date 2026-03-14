defmodule Collation.Application do
  @moduledoc false

  use Application

  @impl true
  def start(_type \\ :normal, _args \\ []) do
    children = [
      Collation.Table,
      Collation.Han
    ]

    options = [strategy: :one_for_one, name: Collation.Supervisor]
    Supervisor.start_link(children, options)
  end
end
