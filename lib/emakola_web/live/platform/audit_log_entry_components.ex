defmodule EmakolaWeb.Platform.AuditLogEntryComponents do
  @moduledoc """
  One row of the platform audit ledger. The row reads the entry's metadata
  into a named TARGET (the store, product, merchant or account the action
  touched) and a first DETAIL (the reason, the permissions, the amount);
  whatever is left folds into a "+N" count and opens as chips on click.
  """
  use Phoenix.Component

  import EmakolaWeb.CoreComponents, only: [icon: 1]
  import EmakolaWeb.PlatformComponents, only: [severity_pill: 1]

  alias Emakola.Accounts.PlatformAuditFamilies, as: Families
  alias Phoenix.LiveView.JS

  @detail_priority ~w(reason permissions amount count title note)

  @avatar_tints [
    "bg-rose-100 text-rose-600",
    "bg-amber-100 text-amber-600",
    "bg-blue-100 text-blue-600",
    "bg-emerald-100 text-emerald-600",
    "bg-sky-100 text-sky-600",
    "bg-violet-100 text-violet-600"
  ]

  @doc "Shared column template for the header row and every entry row."
  def ledger_grid,
    do:
      "grid grid-cols-1 gap-x-4 gap-y-1 lg:grid-cols-[76px_200px_150px_200px_minmax(0,1fr)_108px]"

  attr :dom_id, :string, required: true
  attr :entry, :map, required: true
  attr :actors, :map, required: true

  def entry_row(assigns) do
    meta = Map.new(assigns.entry.metadata || %{}, fn {key, value} -> {to_string(key), value} end)
    target = target(meta)
    {detail, more} = details(meta, target)

    assigns =
      assign(assigns,
        meta: meta,
        target: target,
        detail: detail,
        more: more,
        actor: actor(assigns.entry.actor_id, assigns.actors),
        severity: Families.severity_of(assigns.entry.action)
      )

    ~H"""
    <li
      id={@dom_id}
      data-severity={@severity}
      phx-click={JS.toggle(to: "##{@dom_id}-meta", display: "flex")}
      class={[
        ledger_grid(),
        "lg:items-center px-6 py-3 border-b border-gray-100 last:border-b-0",
        "hover:bg-gray-50/70 cursor-pointer transition-colors"
      ]}
    >
      <span
        class="font-mono text-xs text-gray-500 tabular-nums"
        title={Calendar.strftime(@entry.inserted_at, "%Y-%m-%d %H:%M:%S UTC")}
      >
        {Calendar.strftime(@entry.inserted_at, "%H:%M:%S")}
      </span>
      <div class="flex items-center gap-2.5 min-w-0">
        <span class={["h-2.5 w-2.5 rounded-full shrink-0", dot_class(@severity)]}></span>
        <.severity_pill label={action_label(@entry.action)} tone={pill_tone(@severity)} />
      </div>
      <div class="flex items-center gap-2 min-w-0" title={@actor.email}>
        <span
          :if={@actor.system?}
          class="flex h-6 w-6 shrink-0 items-center justify-center rounded-full bg-slate-100 text-slate-500"
        >
          <.icon name="hero-cog-6-tooth" class="size-3.5" />
        </span>
        <span
          :if={!@actor.system?}
          class={[
            "flex h-6 w-6 shrink-0 items-center justify-center rounded-full text-[10px] font-bold",
            @actor.tint
          ]}
        >
          {@actor.initials}
        </span>
        <span class={[
          "truncate text-[13px]",
          if(@actor.system?, do: "font-medium text-gray-500", else: "font-semibold text-gray-900")
        ]}>
          {@actor.label}
        </span>
      </div>
      <div class="flex items-center gap-2 min-w-0">
        <span
          :if={@target}
          class="flex h-6 w-6 shrink-0 items-center justify-center rounded-md bg-slate-100 text-slate-500"
        >
          <.icon name={@target.icon} class="size-3.5" />
        </span>
        <div :if={@target} class="min-w-0">
          <div class="truncate text-[13px] font-medium text-gray-900">{@target.name}</div>
          <div :if={@target.sub} class="truncate font-mono text-[11px] text-gray-400">
            {@target.sub}
          </div>
        </div>
      </div>
      <div class="flex items-center gap-2 min-w-0">
        <span :if={@detail} class="truncate text-[13px] text-gray-600">
          <span class="text-gray-400">{elem(@detail, 0)}:</span> {elem(@detail, 1)}
        </span>
        <span
          :if={@more > 0}
          class="detail-more shrink-0 rounded-md border border-gray-200 bg-gray-100 px-1.5 text-[11px] text-gray-600 tabular-nums"
        >
          +{@more}
        </span>
      </div>
      <span class="font-mono text-[11px] text-gray-400">{@entry.ip}</span>
      <div id={"#{@dom_id}-meta"} class="hidden col-span-full flex-wrap gap-1 pt-2">
        <span
          :for={{key, value} <- @meta}
          class="inline-block rounded-md bg-gray-50 border border-gray-200 px-2 py-0.5 text-xs text-gray-600"
        >
          {key}: {chip_value(value)}
        </span>
      </div>
    </li>
    """
  end

  # ── target and detail ──────────────────────────────────────────────

  defp target(meta) do
    cond do
      meta["store_name"] || meta["store_slug"] ->
        named(
          "hero-building-storefront",
          meta["store_name"],
          meta["store_slug"],
          ~w(store_name store_slug)
        )

      meta["product_title"] ->
        named("hero-cube", meta["product_title"], nil, ~w(product_title))

      meta["merchant_name"] || meta["merchant_email"] ->
        named(
          "hero-user",
          meta["merchant_name"],
          meta["merchant_email"],
          ~w(merchant_name merchant_email)
        )

      meta["email"] ->
        named("hero-user", meta["email"], nil, ~w(email))

      true ->
        nil
    end
  end

  # The sub-line repeats nothing: with no name, the slug or email IS the name.
  defp named(icon, nil, sub, keys), do: %{icon: icon, name: chip_value(sub), sub: nil, keys: keys}

  defp named(icon, name, sub, keys),
    do: %{icon: icon, name: chip_value(name), sub: sub && chip_value(sub), keys: keys}

  defp details(meta, target) do
    consumed = if target, do: target.keys, else: []
    remaining = meta |> Map.keys() |> Enum.reject(&(&1 in consumed))

    case primary_key(remaining) do
      nil -> {nil, 0}
      key -> {{key, chip_value(meta[key])}, length(remaining) - 1}
    end
  end

  # Human-written fields first; a bare id is the last thing worth a column.
  defp primary_key(keys) do
    Enum.find(@detail_priority, &(&1 in keys)) ||
      keys |> Enum.reject(&String.ends_with?(&1, "_id")) |> Enum.sort() |> List.first() ||
      keys |> Enum.sort() |> List.first()
  end

  # ── actor ──────────────────────────────────────────────────────────

  defp actor(nil, _actors), do: %{label: "system", email: nil, system?: true}

  defp actor(actor_id, actors) do
    case Map.get(actors, actor_id) do
      %{name: name, email: email} ->
        label = name || email

        %{
          label: label,
          email: email,
          system?: false,
          initials: initials(label),
          tint: tint(actor_id)
        }

      nil ->
        %{
          label: String.slice(actor_id, 0, 8) <> "…",
          email: nil,
          system?: false,
          initials: "?",
          tint: tint(actor_id)
        }
    end
  end

  defp initials(label) do
    label
    |> String.split(~r/[\s@.]+/, trim: true)
    |> Enum.take(2)
    |> Enum.map_join(&String.first/1)
    |> String.upcase()
  end

  defp tint(actor_id), do: Enum.at(@avatar_tints, :erlang.phash2(actor_id, length(@avatar_tints)))

  # ── colours and labels ─────────────────────────────────────────────

  defp dot_class(:red), do: "bg-red-500"
  defp dot_class(:amber), do: "bg-amber-500"
  defp dot_class(:green), do: "bg-emerald-500"
  defp dot_class(:neutral), do: "bg-gray-300"

  # severity_pill has no "neutral" tone; the neutral family wears slate.
  defp pill_tone(:neutral), do: "slate"
  defp pill_tone(severity), do: Atom.to_string(severity)

  defp action_label(action) do
    action |> Atom.to_string() |> String.replace("_", " ") |> String.capitalize()
  end

  @doc false
  def chip_value(value) when is_map(value), do: inspect(value)
  def chip_value(value) when is_list(value), do: Enum.map_join(value, ", ", &to_string/1)
  def chip_value(value), do: to_string(value)
end
