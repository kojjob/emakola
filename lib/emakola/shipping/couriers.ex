defmodule Emakola.Shipping.Couriers do
  @moduledoc """
  The couriers a merchant can attach to a tracking number, and where a buyer
  goes to look that number up.

  ## Why some entries have no URL

  A tracking link is only worth rendering if it lands somewhere real. A guessed
  URL sends the buyer to a 404 on a courier's site and looks like the *shop's*
  mistake — worse than showing the number plainly and letting them search.

  So `tracking_url/2` returns `nil` unless the template is known, and the
  caller renders the number as text in that case. `:other` exists precisely so
  a merchant using a local rider or a courier not listed here can still record
  a reference without the platform inventing a destination for it.

  Adding a courier is a two-line change: an entry in `@couriers` and, only if
  its public tracking URL has actually been checked, a `url` template with
  `{number}` where the reference goes.
  """

  @type courier :: %{id: atom(), label: String.t(), url: String.t() | nil}

  # `url` is nil wherever the public tracking endpoint has not been verified.
  # Do not fill one in from memory — check the courier's own site first.
  @couriers [
    %{
      id: :dhl,
      label: "DHL",
      url: "https://www.dhl.com/gh-en/home/tracking/tracking-express.html?tracking-id={number}"
    },
    %{
      id: :ems_ghana,
      label: "Ghana Post EMS",
      url: "https://ems.post/en/global-network/tracking?id={number}"
    },
    %{id: :speedaf, label: "Speedaf", url: nil},
    %{id: :jumia_express, label: "Jumia Express", url: nil},
    %{id: :local_rider, label: "Local rider / dispatch", url: nil},
    %{id: :other, label: "Other courier", url: nil}
  ]

  @doc "Every courier a merchant may choose, in display order."
  @spec list() :: [courier()]
  def list, do: @couriers

  @doc "The ids, for a resource's `one_of` constraint."
  @spec ids() :: [atom()]
  def ids, do: Enum.map(@couriers, & &1.id)

  @doc "Human label for a courier id. Unknown ids get a neutral fallback rather than raising."
  @spec label(atom() | nil) :: String.t()
  def label(id) do
    case Enum.find(@couriers, &(&1.id == id)) do
      %{label: label} -> label
      nil -> "Courier"
    end
  end

  @doc """
  A public tracking URL for this courier and reference, or `nil`.

  `nil` means "render the number as plain text" — either the courier has no
  verified template, or there is no number to look up.
  """
  @spec tracking_url(atom() | nil, String.t() | nil) :: String.t() | nil
  def tracking_url(nil, _number), do: nil
  def tracking_url(_id, nil), do: nil
  def tracking_url(_id, ""), do: nil

  def tracking_url(id, number) when is_atom(id) and is_binary(number) do
    case Enum.find(@couriers, &(&1.id == id)) do
      %{url: template} when is_binary(template) ->
        # The number is merchant-entered and lands in a query string.
        String.replace(template, "{number}", URI.encode_www_form(String.trim(number)))

      _ ->
        nil
    end
  end

  def tracking_url(_id, _number), do: nil
end
