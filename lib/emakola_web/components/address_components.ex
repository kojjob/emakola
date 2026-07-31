defmodule EmakolaWeb.AddressComponents do
  @moduledoc """
  Shared GhanaPost digital-address + landmark fieldset, used by both the
  checkout renderer's flat form and the pay-link page's `buyer[...]` map
  form. Both inputs are optional and fire no events of their own — they
  just ride whichever submit the parent form already has.
  """
  use Phoenix.Component

  @doc """
  Renders the digital-address and landmark inputs.

  `field_prefix` controls the `name`/`id` shape: `""` renders bare
  `name="digital_address"` (the checkout renderer's flat form); any other
  value, e.g. `"buyer"`, renders `name="buyer[digital_address]"`.
  """
  attr :digital_address, :string, default: ""
  attr :landmark, :string, default: ""
  attr :field_prefix, :string, required: true
  attr :show_hint, :boolean, default: true

  def gh_address_fields(assigns) do
    assigns =
      assigns
      |> assign(:digital_address_name, field_name(assigns.field_prefix, "digital_address"))
      |> assign(:digital_address_id, field_id(assigns.field_prefix, "digital_address"))
      |> assign(:landmark_name, field_name(assigns.field_prefix, "landmark"))
      |> assign(:landmark_id, field_id(assigns.field_prefix, "landmark"))

    ~H"""
    <div class="space-y-4">
      <div>
        <label for={@digital_address_id} class="block text-sm font-medium text-stone-900 mb-1.5">
          GhanaPost Digital Address <span class="text-stone-400 font-normal">(optional)</span>
        </label>
        <input
          type="text"
          id={@digital_address_id}
          name={@digital_address_name}
          value={@digital_address}
          placeholder="GA-183-8164"
          class="w-full bg-white border border-stone-200 rounded-xl px-4 py-3.5 text-sm text-stone-900 placeholder:text-stone-400 focus:ring-2 focus:ring-store-accent/30 focus:border-store-accent transition-all"
        />
      </div>

      <div>
        <label for={@landmark_id} class="block text-sm font-medium text-stone-900 mb-1.5">
          Landmark <span class="text-stone-400 font-normal">(optional)</span>
        </label>
        <input
          type="text"
          id={@landmark_id}
          name={@landmark_name}
          value={@landmark}
          maxlength="200"
          placeholder="e.g. behind Achimota Melcom, blue gate"
          class="w-full bg-white border border-stone-200 rounded-xl px-4 py-3.5 text-sm text-stone-900 placeholder:text-stone-400 focus:ring-2 focus:ring-store-accent/30 focus:border-store-accent transition-all"
        />
        <p :if={@show_hint} class="text-xs text-stone-500 mt-1">
          Helps the rider find you faster
        </p>
      </div>
    </div>
    """
  end

  defp field_name("", field), do: field
  defp field_name(prefix, field), do: "#{prefix}[#{field}]"

  defp field_id("", field), do: field
  defp field_id(prefix, field), do: "#{prefix}_#{field}"
end
