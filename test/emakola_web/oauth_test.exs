defmodule EmakolaWeb.OAuthTest do
  # async: false — these tests mutate the global :oauth application env.
  use ExUnit.Case, async: false

  alias EmakolaWeb.OAuth

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

  describe "enabled_providers/0" do
    test "returns [] when nothing is configured" do
      Application.delete_env(:emakola, :oauth)
      assert OAuth.enabled_providers() == []
    end

    test "returns [] when credentials are present but blank" do
      Application.put_env(:emakola, :oauth, google: %{client_id: "id", client_secret: ""})
      assert OAuth.enabled_providers() == []
    end

    test "includes :google only when both client_id and client_secret are set" do
      Application.put_env(:emakola, :oauth, google: %{client_id: "id", client_secret: "secret"})
      assert OAuth.enabled_providers() == [:google]
    end

    test "apple requires client_id, team_id, private_key_id and private_key_path" do
      Application.put_env(:emakola, :oauth,
        apple: %{client_id: "id", team_id: "t", private_key_id: "k", private_key_path: nil}
      )

      assert OAuth.enabled_providers() == []

      Application.put_env(:emakola, :oauth,
        apple: %{client_id: "id", team_id: "t", private_key_id: "k", private_key_path: "/key.p8"}
      )

      assert OAuth.enabled_providers() == [:apple]
    end

    test "preserves declared provider order (google, facebook, apple)" do
      Application.put_env(:emakola, :oauth,
        facebook: %{client_id: "id", client_secret: "s"},
        google: %{client_id: "id", client_secret: "s"}
      )

      assert OAuth.enabled_providers() == [:google, :facebook]
    end
  end

  describe "enabled?/1" do
    test "reflects whether a single provider is configured" do
      Application.put_env(:emakola, :oauth, facebook: %{client_id: "id", client_secret: "s"})
      assert OAuth.enabled?(:facebook)
      refute OAuth.enabled?(:google)
    end
  end
end
