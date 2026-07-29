defmodule EmakolaWeb.Hooks.NoIndex do
  @moduledoc """
  Marks a LiveView as private or transactional for search crawlers.

  The page remains crawlable so search engines can read the `noindex`
  directive. Access control must always be enforced by the page itself;
  robots.txt is not an authorization mechanism.
  """

  import Phoenix.Component, only: [assign: 3]

  def on_mount(:default, _params, _session, socket) do
    {:cont, assign(socket, :robots, "noindex, nofollow")}
  end
end
