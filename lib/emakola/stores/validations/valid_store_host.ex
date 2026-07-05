defmodule Emakola.Stores.Validations.ValidStoreHost do
  @moduledoc """
  Validates a `StoreDomain` host: it must be a well-formed hostname, and — for
  `:subdomain` types — its first label must not be a reserved platform word
  (so a merchant can't claim `admin.makola.io`, `api.makola.io`, etc.).

  The host is normalized (trimmed + downcased) before checking, matching the
  normalization the create action applies before persisting.
  """

  use Ash.Resource.Validation

  # Labels a merchant must never be able to take on `*.makola.io` — they collide
  # with platform infrastructure, the apex's own routes, or common service names.
  @reserved ~w(
    www admin api app mail smtp imap pop ftp ns ns1 ns2 dns mx
    blog shop store dashboard staging stage dev test cdn assets static
    help support docs status billing pay checkout cart account accounts
    login signup signin auth oauth platform internal system root
    media images img video uploads files download downloads
  )

  # RFC-1123-ish: lowercase labels of [a-z0-9-] (no leading/trailing hyphen),
  # at least two dot-separated labels (a bare label is never a valid host here).
  @host_regex ~r/^[a-z0-9]([a-z0-9-]*[a-z0-9])?(\.[a-z0-9]([a-z0-9-]*[a-z0-9])?)+$/

  @impl true
  def validate(changeset, _opts, _context) do
    host = changeset |> Ash.Changeset.get_attribute(:host) |> normalize()
    type = Ash.Changeset.get_attribute(changeset, :type) || :subdomain

    cond do
      is_nil(host) or host == "" ->
        error(:host, "is required")

      not Regex.match?(@host_regex, host) ->
        error(:host, "is not a valid hostname")

      type == :subdomain and reserved_label?(host) ->
        error(:host, "uses a reserved subdomain name")

      true ->
        :ok
    end
  end

  defp normalize(nil), do: nil
  defp normalize(host), do: host |> to_string() |> String.trim() |> String.downcase()

  @doc """
  Returns true if the host's first label is a reserved platform word
  (`admin`, `api`, `www`, …). Accepts a bare label too. Shared with
  `EmakolaWeb.Plugs.ResolveStoreByHost` so an implicit `<slug>.<base>` subdomain
  can never shadow a reserved name.
  """
  def reserved_label?(host) do
    host |> String.split(".") |> List.first() |> Kernel.in(@reserved)
  end

  defp error(field, message) do
    {:error, Ash.Error.Changes.InvalidAttribute.exception(field: field, message: message)}
  end
end
