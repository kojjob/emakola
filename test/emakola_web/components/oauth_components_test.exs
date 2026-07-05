defmodule EmakolaWeb.OAuthComponentsTest do
  # async: false — mutates the global :oauth application env.
  use ExUnit.Case, async: false

  import Phoenix.LiveViewTest

  setup do
    previous = Application.get_env(:emakola, :oauth)

    on_exit(fn ->
      if previous do
        Application.put_env(:emakola, :oauth, previous)
      else
        Application.delete_env(:emakola, :oauth)
      end
    end)

    :ok
  end

  test "renders nothing when no provider is configured (ship-dark)" do
    Application.delete_env(:emakola, :oauth)

    html = render_component(&EmakolaWeb.OAuthComponents.oauth_buttons/1, subject: "merchant")

    refute html =~ "Continue with"
  end

  test "renders an enabled provider's button pointing at its request path" do
    Application.put_env(:emakola, :oauth, google: %{client_id: "id", client_secret: "secret"})

    html = render_component(&EmakolaWeb.OAuthComponents.oauth_buttons/1, subject: "merchant")

    assert html =~ "Continue with Google"
    assert html =~ ~s(href="/oauth/merchant/google")
    refute html =~ "Continue with Facebook"
  end
end
