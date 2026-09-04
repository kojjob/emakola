defmodule Emakola.AI.Sanitizer do
  @moduledoc """
  Strips emoji from AI replies before any caller sees them.

  Every prompt carries a house rule against emoji (`Emakola.AI.Prompts`);
  this is the guarantee for the times a model ignores it. A merchant's shop
  shows words, never a symbol the merchant did not type. Runs on the free
  text and on every string inside a parsed JSON reply, at any depth.
  """

  alias Emakola.AI.Response

  @spec clean(Response.t()) :: Response.t()
  def clean(%Response{} = response) do
    %{response | text: strip_nullable(response.text), parsed: strip_any(response.parsed)}
  end

  @doc "Removes emoji, their joiners and keycaps, then tidies the spacing left behind."
  @spec strip_emoji(String.t()) :: String.t()
  def strip_emoji(text) when is_binary(text) do
    text
    |> String.replace(emoji(), "")
    |> String.replace(space_before_punctuation(), "\\1")
    |> String.replace(repeated_spaces(), " ")
    |> String.replace(space_before_newline(), "\n")
    |> String.trim()
  end

  # Pictographs, emoticons and supplemental symbols; dingbats and misc
  # symbols; misc technical (watches, hourglasses); arrows and stars; and the
  # invisible variation selector, zero-width joiner and keycap that ride along
  # with them. Currency signs such as the cedi and accented letters sit
  # outside every range. Built per call: regexes cannot live in module
  # attributes on current Erlang.
  defp emoji do
    ~r/[\x{1F000}-\x{1FAFF}\x{2600}-\x{27BF}\x{2B00}-\x{2BFF}\x{2300}-\x{23FF}\x{FE0F}\x{200D}\x{20E3}]/u
  end

  defp space_before_punctuation, do: ~r/[ \t]+([.,;:!?])/u
  defp repeated_spaces, do: ~r/[ \t]{2,}/
  defp space_before_newline, do: ~r/[ \t]+\n/

  defp strip_nullable(nil), do: nil
  defp strip_nullable(text), do: strip_emoji(text)

  defp strip_any(text) when is_binary(text), do: strip_emoji(text)
  defp strip_any(list) when is_list(list), do: Enum.map(list, &strip_any/1)
  defp strip_any(%{} = map), do: Map.new(map, fn {key, value} -> {key, strip_any(value)} end)
  defp strip_any(other), do: other
end
