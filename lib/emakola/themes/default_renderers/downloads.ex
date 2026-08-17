defmodule Emakola.Themes.DefaultRenderers.Downloads do
  @moduledoc """
  Default render for the storefront customer downloads page.

  Used by `EmakolaWeb.Storefront.AccountDownloadsLive` when no theme
  overrides `:render_downloads`. Lists the customer's `DownloadGrant`
  records with a render-time status badge and download link.

  Data loading and event handling stay in the LiveView; this module
  is render-only.

  See `docs/PATTERN-default-renderer-extraction.md`.
  """

  use Phoenix.Component

  import EmakolaWeb.Storefront.Path

  def render(assigns) do
    ~H"""
    <Emakola.Themes.DefaultRenderers.Chrome.navbar
      theme_module={assigns[:theme_module]}
      theme={assigns[:theme] || %{}}
      store={@store}
      cart_count={@cart_count}
      active_path="account"
    />

    <section class="mx-auto max-w-4xl px-4 py-10 sm:px-6 lg:px-8">
      <header class="mb-8">
        <h1 class="text-2xl font-semibold text-stone-900">My Downloads</h1>
        <p class="mt-1 text-sm text-stone-500">
          Files you've purchased. Download links expire and limits are enforced at the moment you click.
        </p>
      </header>

      <%= if @grants == [] do %>
        <div class="rounded-lg border border-stone-200 bg-white p-8 text-center">
          <p class="text-stone-700">You have no downloads yet.</p>
          <p class="mt-2 text-sm text-stone-500">
            When you purchase a digital product, it will appear here.
          </p>
          <.link
            navigate={store_path(@store.slug, "/products")}
            class="mt-4 inline-block text-store-accent underline"
          >
            Browse the store
          </.link>
        </div>
      <% else %>
        <ul role="list" class="divide-y divide-stone-200 rounded-lg border border-stone-200 bg-white">
          <li :for={grant <- @grants} class="flex items-center justify-between gap-4 p-4 sm:p-5">
            <div class="min-w-0 flex-1">
              <p class="truncate text-sm font-medium text-stone-900">
                {grant.digital_file.file_name}
              </p>
              <p class="mt-0.5 text-xs text-stone-500">
                {format_size(grant.digital_file.byte_size)} • {downloads_used(grant)}
                <span :if={grant.expires_at}>
                  • Expires {Calendar.strftime(grant.expires_at, "%b %-d, %Y")}
                </span>
              </p>
            </div>

            <div class="flex items-center gap-3">
              <span class={[
                "inline-flex items-center rounded-full px-2.5 py-0.5 text-xs font-medium",
                badge_classes(grant_state(grant))
              ]}>
                {badge_label(grant_state(grant))}
              </span>

              <%= case grant_state(grant) do %>
                <% :active -> %>
                  <.link
                    href={store_path(@store.slug, "/downloads/#{grant.id}")}
                    class="rounded-md bg-cta-dark px-3 py-1.5 text-sm font-medium text-white hover:opacity-90"
                  >
                    Download
                  </.link>
                <% _ -> %>
                  <button
                    type="button"
                    disabled
                    class="rounded-md bg-stone-100 px-3 py-1.5 text-sm font-medium text-stone-400 cursor-not-allowed"
                  >
                    Download
                  </button>
              <% end %>
            </div>
          </li>
        </ul>
      <% end %>
    </section>

    <Emakola.Themes.DefaultRenderers.Chrome.footer
      theme_module={assigns[:theme_module]}
      theme={assigns[:theme] || %{}}
      store={@store}
    />
    """
  end

  # ── Derived state ───────────────────────────────────────────────

  # A grant's state is computed from its fields, never stored. Lets us
  # avoid a "mark expired" worker — the moment the clock crosses
  # expires_at, the grant is :expired everywhere.
  defp grant_state(grant) do
    cond do
      expired?(grant) -> :expired
      limit_reached?(grant) -> :limit_reached
      true -> :active
    end
  end

  defp expired?(%{expires_at: nil}), do: false

  defp expired?(%{expires_at: expires_at}),
    do: DateTime.compare(expires_at, DateTime.utc_now()) != :gt

  defp limit_reached?(%{download_limit: nil}), do: false
  defp limit_reached?(%{download_limit: limit, downloaded_count: count}), do: count >= limit

  defp badge_label(:active), do: "Active"
  defp badge_label(:expired), do: "Expired"
  defp badge_label(:limit_reached), do: "Limit reached"

  defp badge_classes(:active), do: "bg-emerald-50 text-emerald-700"
  defp badge_classes(:expired), do: "bg-stone-100 text-stone-600"
  defp badge_classes(:limit_reached), do: "bg-stone-100 text-stone-600"

  defp downloads_used(%{download_limit: nil, downloaded_count: count}),
    do: "#{count} #{pluralize("download", count)}"

  defp downloads_used(%{download_limit: limit, downloaded_count: count}),
    do: "#{count} of #{limit} downloads used"

  defp pluralize(word, 1), do: word
  defp pluralize(word, _), do: word <> "s"

  # ── Size formatting ─────────────────────────────────────────────

  defp format_size(bytes) when bytes >= 1_073_741_824,
    do: "#{Float.round(bytes / 1_073_741_824, 2)} GB"

  defp format_size(bytes) when bytes >= 1_048_576,
    do: "#{Float.round(bytes / 1_048_576, 1)} MB"

  defp format_size(bytes) when bytes >= 1_024,
    do: "#{Float.round(bytes / 1_024, 1)} KB"

  defp format_size(bytes), do: "#{bytes} B"
end
