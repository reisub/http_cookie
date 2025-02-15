defmodule HttpCookie.Util do
  @moduledoc false

  @doc false
  @spec pretty_module(module()) :: String.t()
  def pretty_module(module) do
    module
    |> Module.split()
    |> Enum.join(".")
  end
end
