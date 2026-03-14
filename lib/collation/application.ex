defmodule Collation.Application do
  @moduledoc false

  use Application

  @impl true
  def start(_type, _args) do
    children = [
      Collation.Table,
      Collation.Han
    ]

    opts = [strategy: :one_for_one, name: Collation.Supervisor]
    Supervisor.start_link(children, opts)
  end
end
