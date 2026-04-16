defmodule Emakola.Cart.CartServer do
  @moduledoc """
  GenServer that owns the cart ETS table. If this process crashes,
  the supervisor restarts it and the table is recreated.
  """
  use GenServer

  def start_link(_opts) do
    GenServer.start_link(__MODULE__, [], name: __MODULE__)
  end

  @impl true
  def init(_) do
    Emakola.Cart.CartStore.init()
    {:ok, %{}}
  end
end
