defmodule Emakola.Privacy do
  @moduledoc """
  Small, dependency-free helpers for keeping personal data out of logs.

  These functions are intentionally lossy. Logs should carry enough context to
  correlate a delivery attempt without becoming a second store of customer
  contact details or provider credentials.
  """

  @redacted "[redacted]"

  @doc "Masks a phone number, retaining only a country-code hint and the final four digits."
  @spec mask_phone(term()) :: String.t()
  def mask_phone(value) do
    raw = stringify(value)
    digits = String.replace(raw, ~r/\D/u, "")
    length = String.length(digits)

    cond do
      length <= 4 ->
        @redacted

      String.starts_with?(String.trim(raw), "+") and length >= 8 ->
        country_hint = String.slice(digits, 0, 3)
        tail = String.slice(digits, length - 4, 4)
        "+#{country_hint}****#{tail}"

      true ->
        tail = String.slice(digits, length - 4, 4)
        "****#{tail}"
    end
  end

  @doc "Masks the local part of an email address while retaining its delivery domain."
  @spec mask_email(term()) :: String.t()
  def mask_email(value) do
    value
    |> stringify()
    |> String.split("@", parts: 2)
    |> case do
      [local, domain] when local != "" and domain != "" ->
        "#{String.first(local)}***@#{domain}"

      _other ->
        @redacted
    end
  end

  @doc "Returns a coarse error category without serialising provider response data."
  @spec error_type(term()) :: String.t()
  def error_type(%{__struct__: module}) when is_atom(module) do
    module
    |> Module.split()
    |> Enum.join(".")
  end

  def error_type({type, _details}) when is_atom(type), do: Atom.to_string(type)
  def error_type(type) when is_atom(type), do: Atom.to_string(type)
  def error_type(_other), do: "unknown"

  @doc "Allows only the conservative labels used for provider/template names."
  @spec safe_label(term()) :: String.t()
  def safe_label(value) when is_binary(value) do
    if Regex.match?(~r/\A[a-z0-9_]+\z/, value), do: value, else: "invalid"
  end

  def safe_label(_value), do: "invalid"

  @doc "Returns a UUID-shaped identifier or a non-sensitive placeholder."
  @spec safe_uuid(term()) :: String.t()
  def safe_uuid(value) when is_binary(value) do
    if Regex.match?(
         ~r/\A[0-9a-f]{8}-[0-9a-f]{4}-[1-8][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}\z/i,
         value
       ),
       do: value,
       else: "unknown"
  end

  def safe_uuid(_value), do: "unknown"

  defp stringify(value) when is_binary(value), do: value
  defp stringify(nil), do: ""

  defp stringify(value) do
    case String.Chars.impl_for(value) do
      nil -> ""
      _implementation -> to_string(value)
    end
  end
end
