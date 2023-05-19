defmodule Cldr.Collation.Nif do
  use Rustler,
    otp_app: :ex_cldr_collation

  def sort(_locale, _list, _opts), do: :erlang.nif_error(:nif_not_loaded)
end
