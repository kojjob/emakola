defmodule Emakola.Themes.Heirloom.Sections.Team do
  @moduledoc """
  Portrait cards for the people behind the store.

  Driven by `@theme.team.items`, which defaults to `[]`.

  The reference shipped three named people — Ethan Marlowe, Isla Thornton,
  Clara Winslow — with job titles and portraits. Carrying those across would
  have every Heirloom store claim the same three staff, which is the exact
  pattern removed from this codebase in PRs #321-328 and guarded now by
  `no_invented_provenance_test.exs`. The layout survives; the people are the
  merchant's own or the section does not exist.

  Each item is `%{"name" => ..., "role" => ..., "image_url" => ...}`. An
  item with no name is dropped — an anonymous portrait is not a team member.
  """
  @behaviour Emakola.Themes.Section

  use Phoenix.Component

  import EmakolaWeb.StorefrontComponents, only: [optimized_image: 1]

  @impl true
  def key, do: "heirloom/team"

  @impl true
  def label, do: "Team"

  @impl true
  def settings_schema do
    [%{key: "heading", type: :text, label: "Heading", default: ""}]
  end

  @impl true
  def render(assigns) do
    members =
      assigns.theme
      |> get_in([:team, :items])
      |> List.wrap()
      |> Enum.filter(&is_map/1)
      |> Enum.filter(&(field(&1, "name") != ""))

    assigns =
      assigns
      |> assign(:members, members)
      |> assign(:heading, present(assigns.settings["heading"]))

    ~H"""
    <section :if={@members != []} class="bg-[color:var(--hl-bg)] pb-24 sm:pb-32">
      <div class="mx-auto max-w-[1360px] px-5 sm:px-8">
        <p
          :if={@heading}
          class="mb-14 max-w-[34ch] text-2xl font-light leading-[1.25] tracking-tight text-[color:var(--hl-ink)] [font-family:var(--hl-display)] sm:text-3xl"
        >
          {@heading}
        </p>

        <ul class="grid gap-x-6 gap-y-10 sm:grid-cols-2 lg:grid-cols-3">
          <li :for={member <- @members}>
            <div class="overflow-hidden rounded-[28px] bg-[color:var(--hl-tile)]">
              <.optimized_image
                src={nilify(field(member, "image_url"))}
                alt={field(member, "name")}
                width={720}
                height={860}
                class="aspect-[5/6] w-full object-cover"
              />
            </div>
            <p class="mt-5 text-xl font-light text-[color:var(--hl-ink)] [font-family:var(--hl-display)]">
              {field(member, "name")}
            </p>
            <p
              :if={field(member, "role") != ""}
              class="mt-1 text-sm text-[color:var(--hl-muted)]"
            >
              {field(member, "role")}
            </p>
          </li>
        </ul>
      </div>
    </section>
    """
  end

  defp field(item, key) when is_map(item) do
    value = Map.get(item, key) || Map.get(item, safe_atom(key)) || ""
    if is_binary(value), do: String.trim(value), else: ""
  end

  defp safe_atom(key) do
    String.to_existing_atom(key)
  rescue
    ArgumentError -> nil
  end

  defp nilify(""), do: nil
  defp nilify(value), do: value

  defp present(value) when is_binary(value) do
    case String.trim(value) do
      "" -> nil
      trimmed -> trimmed
    end
  end

  defp present(_other), do: nil
end
