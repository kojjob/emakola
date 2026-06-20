defmodule EmakolaWeb.OAuthComponents do
  @moduledoc """
  Social-login button row. Renders one "Continue with <provider>" link per
  *enabled* provider (`EmakolaWeb.OAuth.enabled_providers/0`), pointing at the
  ash_authentication OAuth request path. Renders nothing when no provider is
  configured, so the whole row is invisible until social login is switched on.
  """
  use Phoenix.Component

  @doc """
  Renders the enabled social-login buttons.

  `subject` is the ash_authentication subject route segment ("merchant" now;
  "customer" once storefront OAuth lands).
  """
  attr :subject, :string, default: "merchant"
  attr :store_slug, :string, default: nil
  attr :class, :string, default: nil

  def oauth_buttons(assigns) do
    assigns = assign(assigns, :providers, EmakolaWeb.OAuth.enabled_providers())

    ~H"""
    <div :if={@providers != []} class={["space-y-3", @class]}>
      <a
        :for={provider <- @providers}
        href={request_path(@subject, provider, @store_slug)}
        data-provider={provider}
        class="w-full flex items-center justify-center gap-2 bg-white border border-gray-300 hover:bg-gray-50 text-[#0c1526] font-semibold py-3 rounded-xl text-sm transition-all active:scale-[0.98] shadow-sm"
      >
        <span class="material-symbols-outlined text-lg">login</span> Continue with {label(provider)}
      </a>
    </div>
    """
  end

  # Customer OAuth needs the store carried into the round-trip (the callback is a
  # fixed path); merchant OAuth has no store, so the slug is omitted.
  defp request_path(subject, provider, nil), do: "/oauth/#{subject}/#{provider}"

  defp request_path(subject, provider, slug),
    do: "/oauth/#{subject}/#{provider}?store_slug=#{slug}"

  defp label(:google), do: "Google"
  defp label(:facebook), do: "Facebook"
  defp label(:apple), do: "Apple"
end
