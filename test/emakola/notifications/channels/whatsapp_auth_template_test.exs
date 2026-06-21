defmodule Emakola.Notifications.Channels.WhatsAppAuthTemplateTest do
  use ExUnit.Case, async: true
  import Mox
  alias Emakola.Notifications.Channels.WhatsApp

  setup :verify_on_exit!

  test "auth_code template renders the code as its single body parameter" do
    msg =
      WhatsApp.build_template_message("+233501234567", "auth_code", [
        %{type: "text", text: "123456"}
      ])

    assert %{template: %{name: "auth_code", components: [%{parameters: [%{text: "123456"}]}]}} =
             msg
  end

  test "send_message knows the auth_code parameter order" do
    # @template_param_order must include "auth_code" => [:code]. With the order
    # registered, send_message builds positional parameters and posts (mocked);
    # without it, it returns {:error, {:unknown_template, _}}.
    stub(Emakola.HTTPClientMock, :post, fn _url, _opts ->
      {:ok, %{status: 200, body: %{}}}
    end)

    refute match?(
             {:error, {:unknown_template, _}},
             WhatsApp.send_message("x", "auth_code", %{code: "1"}, bypass_rate_limit: true)
           )
  end
end
