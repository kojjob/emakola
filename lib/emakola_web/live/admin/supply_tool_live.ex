defmodule EmakolaWeb.Admin.SupplyToolLive do
  @moduledoc """
  The pages behind the Partners hub's doors. `/tools/:tool` renders one
  tool's section on its own page; bare `/tools` is the whole workbench.
  Same data and the same events as the hub, so a merchant can act here
  and see it on the hub.
  """
  use EmakolaWeb, :live_view

  alias EmakolaWeb.Admin.SupplyNetworkLive.{Components, Data, Events, Inputs}

  # slug => {page title, section key}
  @tools %{
    "income-plan" => {"Income plan", :income_plan},
    "opportunities" => {"Opportunity radar", :opportunities},
    "content-studio" => {"Content studio", :content_studio},
    "commerce-passport" => {"Commerce passport", :commerce_passport},
    "collaborate" => {"Group buys, sales teams and franchises", :collaborate},
    "stock-holds" => {"Stock holds", :stock_holds},
    "products" => {"Partner products", :products},
    "sales-kits" => {"Sales kits", :sales_kits},
    "orders" => {"Orders to fulfil", :orders}
  }

  def tool_slugs, do: Map.keys(@tools)

  @impl true
  def mount(params, _session, socket) do
    case Map.fetch(params, "tool") do
      :error ->
        {:ok, load(socket, "Earn tools", nil)}

      {:ok, slug} ->
        case Map.fetch(@tools, slug) do
          {:ok, {title, key}} ->
            {:ok, load(socket, title, key)}

          :error ->
            {:ok,
             socket
             |> put_flash(:error, "That tool does not exist.")
             |> push_navigate(to: ~p"/admin/settings/supply-network")}
        end
    end
  end

  defp load(socket, title, tool) do
    socket
    |> assign(Inputs.default_assigns())
    |> assign(page_title: title, tool: tool)
    |> Data.load_all()
  end

  @impl true
  def handle_event(event, params, socket), do: Events.handle_event(event, params, socket)

  @impl true
  def render(%{tool: nil} = assigns), do: Components.workbench(assigns)
  def render(assigns), do: Components.tool_page(assigns)
end
