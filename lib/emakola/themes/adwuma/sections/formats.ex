defmodule Emakola.Themes.Adwuma.Sections.Formats do
  @moduledoc """
  What this shop sells, in the reference's greyscale logo-strip slot.

  The reference borrows brand logos for credibility the shop has not earned.
  This renders the merchant's own `enabled_product_types` instead — a fact the
  merchant set, about their own shop. A physical-only store renders nothing.
  """
  @behaviour Emakola.Themes.Section

  use Phoenix.Component

  @impl true
  def key, do: "adwuma/formats"
  @impl true
  def label, do: "What this shop sells"

  @impl true
  def settings_schema do
    [%{key: "heading", type: :string, label: "Heading", default: ""}]
  end

  @impl true
  def render(assigns) do
    assigns = assign(assigns, :labels, labels(assigns))

    ~H"""
    <section
      :if={@labels != []}
      class="border-y border-[color:var(--adw-rule)] bg-white px-4 py-8 [font-family:var(--adw-body)] sm:px-6"
    >
      <div class="mx-auto max-w-5xl">
        <p
          :if={@settings["heading"] not in [nil, ""]}
          class="mb-4 text-center text-xs font-semibold uppercase tracking-widest text-[color:var(--adw-muted)]"
        >
          {@settings["heading"]}
        </p>
        <ul class="flex flex-wrap items-center justify-center gap-x-10 gap-y-3">
          <li
            :for={label <- @labels}
            class="text-sm font-medium uppercase tracking-wide text-[color:var(--adw-muted)]"
          >
            {label}
          </li>
        </ul>
      </div>
    </section>
    """
  end

  defp labels(assigns) do
    types =
      assigns.store
      |> Map.get(:enabled_product_types)
      |> Kernel.||([])
      |> Enum.reject(&(&1 == :physical))
      |> Enum.map(&type_label/1)

    extra =
      (Map.get(assigns, :theme) || %{})
      |> get_in([:formats, :items])
      |> Kernel.||([])
      |> Enum.map(&Emakola.Themes.Item.field(&1, :label, ""))
      |> Enum.reject(&(&1 in [nil, ""]))

    Enum.uniq(types ++ extra)
  end

  defp type_label(:digital_download), do: "Downloads"
  defp type_label(:license_key), do: "Licences"
  defp type_label(:streaming), do: "Streaming"
  defp type_label(:course), do: "Courses"
  defp type_label(:print_on_demand), do: "Print on demand"
  defp type_label(other), do: other |> to_string() |> String.replace("_", " ")
end
