defmodule Emakola.AI.Providers.AnthropicTest do
  # async: false — sets the :anthropic_api_key / :http_client application env.
  use ExUnit.Case, async: false

  import Mox

  alias Emakola.AI.Providers.Anthropic
  alias Emakola.AI.{Request, Response}

  setup :verify_on_exit!

  setup do
    # Pin the mock HTTP client explicitly so this test never makes a real call,
    # even if a concurrent test left :http_client unset (see ClaudeTest note).
    Application.put_env(:emakola, :http_client, Emakola.HTTPClientMock)
    prev_key = Application.get_env(:emakola, :anthropic_api_key)
    Application.put_env(:emakola, :anthropic_api_key, "test-key")

    on_exit(fn ->
      Application.put_env(:emakola, :http_client, Emakola.HTTPClientMock)

      if prev_key,
        do: Application.put_env(:emakola, :anthropic_api_key, prev_key),
        else: Application.delete_env(:emakola, :anthropic_api_key)
    end)

    :ok
  end

  defp text_request do
    %Request{
      model: "claude-haiku-4-5",
      system: "be helpful",
      messages: [%{role: :user, content: "Describe Kente Cloth"}],
      max_tokens: 400
    }
  end

  defp anthropic_response(text, usage \\ %{"input_tokens" => 0, "output_tokens" => 0}) do
    {:ok,
     %{
       "model" => "claude-haiku-4-5",
       "content" => [%{"type" => "text", "text" => text}],
       "usage" => usage
     }}
  end

  test "builds the Anthropic request with model, system, messages and auth headers" do
    expect(Emakola.HTTPClientMock, :post, fn url, opts ->
      assert url == "https://api.anthropic.com/v1/messages"
      body = opts[:json]
      assert body.model == "claude-haiku-4-5"
      assert body.system == "be helpful"
      assert [%{role: "user", content: "Describe Kente Cloth"}] = body.messages
      assert {"x-api-key", "test-key"} in opts[:headers]
      assert {"anthropic-version", "2023-06-01"} in opts[:headers]
      anthropic_response("A handwoven kente cloth.")
    end)

    assert {:ok, %Response{text: "A handwoven kente cloth."}} = Anthropic.complete(text_request())
  end

  test "captures the usage block from the response" do
    expect(Emakola.HTTPClientMock, :post, fn _url, _opts ->
      anthropic_response("ok", %{
        "input_tokens" => 120,
        "output_tokens" => 45,
        "cache_read_input_tokens" => 10
      })
    end)

    assert {:ok, %Response{usage: usage}} = Anthropic.complete(text_request())
    assert usage.input_tokens == 120
    assert usage.output_tokens == 45
    assert usage.cache_read == 10
  end

  test "decodes JSON into parsed when response_format is :json" do
    expect(Emakola.HTTPClientMock, :post, fn _url, _opts ->
      anthropic_response(~s({"title": "Kente", "description": "Authentic handwoven kente."}))
    end)

    request = %{text_request() | response_format: :json}
    assert {:ok, %Response{parsed: %{"title" => "Kente"}}} = Anthropic.complete(request)
  end

  test "translates a vision content block into Anthropic's image source shape" do
    expect(Emakola.HTTPClientMock, :post, fn _url, opts ->
      [%{role: "user", content: content}] = opts[:json].messages
      assert %{type: "image", source: %{type: "url", url: "https://cdn/x.jpg"}} in content
      anthropic_response("Handwoven kente in gold")
    end)

    request = %Request{
      model: "claude-haiku-4-5",
      messages: [
        %{
          role: :user,
          content: [%{type: :image, url: "https://cdn/x.jpg"}, %{type: :text, text: "alt?"}]
        }
      ],
      max_tokens: 100
    }

    assert {:ok, %Response{text: "Handwoven kente in gold"}} = Anthropic.complete(request)
  end

  test "sends thinking disabled on the wire when the request asks for it" do
    expect(Emakola.HTTPClientMock, :post, fn _url, opts ->
      assert opts[:json].thinking == %{type: "disabled"}
      anthropic_response("ok")
    end)

    request = %{text_request() | thinking: :disabled}
    assert {:ok, %Response{}} = Anthropic.complete(request)
  end

  test "omits the thinking key entirely when the request does not set it" do
    expect(Emakola.HTTPClientMock, :post, fn _url, opts ->
      refute Map.has_key?(opts[:json], :thinking)
      anthropic_response("ok")
    end)

    assert {:ok, %Response{}} = Anthropic.complete(text_request())
  end

  test "ships dark: returns {:error, :not_configured} with no API key" do
    Application.delete_env(:emakola, :anthropic_api_key)
    assert {:error, :not_configured} = Anthropic.complete(text_request())
  end

  test "surfaces an HTTP error" do
    expect(Emakola.HTTPClientMock, :post, fn _url, _opts -> {:error, :timeout} end)
    assert {:error, :timeout} = Anthropic.complete(text_request())
  end
end
