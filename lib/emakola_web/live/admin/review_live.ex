defmodule EmakolaWeb.Admin.ReviewLive do
  @moduledoc """
  Admin review management page.

  Displays all reviews for the current store in a filterable table.
  Merchants can hide/unhide reviews and filter by status.
  """
  use EmakolaWeb, :live_view

  require Ash.Query

  @statuses [:all, :published, :hidden]

  @impl true
  def mount(_params, _session, socket) do
    store_id = get_store_id(socket)

    socket =
      socket
      |> assign(
        page_title: "Reviews",
        active_nav: :reviews,
        store_id: store_id,
        status_filter: :all,
        reviews: [],
        statuses: @statuses
      )
      |> load_reviews()

    {:ok, socket}
  end

  @impl true
  def handle_event("filter_status", %{"status" => status}, socket) do
    status_atom =
      case status do
        "all" -> :all
        "published" -> :published
        "hidden" -> :hidden
        _ -> :all
      end

    socket =
      socket
      |> assign(status_filter: status_atom)
      |> load_reviews()

    {:noreply, socket}
  end

  @impl true
  def handle_event("hide_review", %{"id" => id}, socket) do
    case find_review(id, socket.assigns.store_id) do
      nil ->
        {:noreply, put_flash(socket, :error, "Review not found")}

      review ->
        case review |> Ash.Changeset.for_update(:hide, %{}) |> Ash.update() do
          {:ok, _} ->
            {:noreply,
             socket
             |> load_reviews()
             |> put_flash(:info, "Review hidden")}

          {:error, _} ->
            {:noreply, put_flash(socket, :error, "Could not hide review")}
        end
    end
  end

  @impl true
  def handle_event("unhide_review", %{"id" => id}, socket) do
    case find_review(id, socket.assigns.store_id) do
      nil ->
        {:noreply, put_flash(socket, :error, "Review not found")}

      review ->
        case review |> Ash.Changeset.for_update(:unhide, %{}) |> Ash.update() do
          {:ok, _} ->
            {:noreply,
             socket
             |> load_reviews()
             |> put_flash(:info, "Review restored")}

          {:error, _} ->
            {:noreply, put_flash(socket, :error, "Could not restore review")}
        end
    end
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="space-y-6">
      <%!-- Page Header --%>
      <div>
        <h1 class="text-2xl font-bold text-slate-900">Reviews</h1>
        <p class="text-sm text-slate-500 mt-1">Manage customer reviews for your products</p>
      </div>

      <%!-- Status Filter --%>
      <div class="flex gap-2">
        <button
          :for={status <- @statuses}
          phx-click="filter_status"
          phx-value-status={status}
          class={[
            "px-3 py-1.5 rounded-md text-sm font-medium transition-colors",
            if(@status_filter == status,
              do: "bg-slate-900 text-white",
              else: "bg-slate-100 text-slate-600 hover:bg-slate-200"
            )
          ]}
        >
          {status_label(status)}
        </button>
      </div>

      <%!-- Reviews Table --%>
      <div class="bg-white rounded-lg border border-slate-200 overflow-hidden">
        <table :if={@reviews != []} class="w-full">
          <thead class="bg-slate-50 border-b border-slate-200">
            <tr>
              <th class="px-4 py-3 text-left text-xs font-semibold text-slate-500 uppercase tracking-wider">
                Product
              </th>
              <th class="px-4 py-3 text-left text-xs font-semibold text-slate-500 uppercase tracking-wider">
                Customer
              </th>
              <th class="px-4 py-3 text-left text-xs font-semibold text-slate-500 uppercase tracking-wider">
                Rating
              </th>
              <th class="px-4 py-3 text-left text-xs font-semibold text-slate-500 uppercase tracking-wider">
                Review
              </th>
              <th class="px-4 py-3 text-left text-xs font-semibold text-slate-500 uppercase tracking-wider">
                Status
              </th>
              <th class="px-4 py-3 text-right text-xs font-semibold text-slate-500 uppercase tracking-wider">
                Action
              </th>
            </tr>
          </thead>
          <tbody class="divide-y divide-slate-100">
            <tr :for={review <- @reviews} class="hover:bg-slate-50">
              <td class="px-4 py-3 text-sm text-slate-900">
                {product_name(review)}
              </td>
              <td class="px-4 py-3 text-sm text-slate-600">
                {customer_name(review)}
              </td>
              <td class="px-4 py-3">
                <EmakolaWeb.ReviewComponents.star_display
                  rating={review.rating * 1.0}
                  size="sm"
                />
              </td>
              <td class="px-4 py-3 text-sm text-slate-600 max-w-xs truncate">
                <span :if={review.title} class="font-medium text-slate-900">
                  {review.title}:
                </span>
                {String.slice(review.body || "", 0, 80)}{if String.length(review.body || "") > 80,
                  do: "...",
                  else: ""}
              </td>
              <td class="px-4 py-3">
                <.status_badge status={review.status} />
              </td>
              <td class="px-4 py-3 text-right">
                <button
                  :if={review.status == :published}
                  phx-click="hide_review"
                  phx-value-id={review.id}
                  class="text-sm text-red-600 hover:text-red-800 font-medium"
                >
                  Hide
                </button>
                <button
                  :if={review.status == :hidden}
                  phx-click="unhide_review"
                  phx-value-id={review.id}
                  class="text-sm text-emerald-600 hover:text-emerald-800 font-medium"
                >
                  Show
                </button>
              </td>
            </tr>
          </tbody>
        </table>

        <%!-- Empty State --%>
        <div :if={@reviews == []} class="py-12 text-center">
          <p class="text-slate-500">No reviews found</p>
        </div>
      </div>
    </div>
    """
  end

  # ── Components ──

  attr :status, :atom, required: true

  defp status_badge(assigns) do
    ~H"""
    <span class={[
      "inline-flex items-center rounded-full px-2 py-0.5 text-xs font-medium",
      status_badge_class(@status)
    ]}>
      {status_label(@status)}
    </span>
    """
  end

  # ── Helpers ──

  defp load_reviews(socket) do
    store_id = socket.assigns.store_id
    status_filter = socket.assigns.status_filter

    query =
      Emakola.Catalog.Review
      |> Ash.Query.filter(store_id == ^store_id)
      |> Ash.Query.sort(inserted_at: :desc)
      |> Ash.Query.load([:product, :customer])

    query =
      if status_filter == :all do
        query
      else
        Ash.Query.filter(query, status == ^status_filter)
      end

    reviews = Ash.read!(query, authorize?: false)
    assign(socket, :reviews, reviews)
  end

  defp find_review(id, store_id) do
    Emakola.Catalog.Review
    |> Ash.Query.filter(id == ^id and store_id == ^store_id)
    |> Ash.read_one!(authorize?: false)
  end

  defp product_name(%{product: %{title: title}}) when is_binary(title), do: title
  defp product_name(_), do: "Unknown product"

  defp customer_name(%{customer: %{name: name}}) when is_binary(name), do: name
  defp customer_name(%{customer: %{email: email}}) when is_binary(email), do: email
  defp customer_name(_), do: "Unknown"

  defp status_label(:all), do: "All"
  defp status_label(:published), do: "Published"
  defp status_label(:hidden), do: "Hidden"

  defp status_badge_class(:published),
    do: "bg-emerald-50 text-emerald-700 border border-emerald-200"

  defp status_badge_class(:hidden), do: "bg-red-50 text-red-700 border border-red-200"
  defp status_badge_class(_), do: "bg-slate-100 text-slate-600"

  defp get_store_id(socket) do
    case socket.assigns[:current_store] do
      %{id: id} -> id
      _ -> nil
    end
  end
end
