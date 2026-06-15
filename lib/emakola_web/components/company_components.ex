defmodule EmakolaWeb.CompanyComponents do
  @moduledoc """
  Shared building blocks for the apex company/legal pages
  (About, Careers, Press, Contact, Legal, Privacy, Terms, Cookie).
  Stateless function components matching the marketing aesthetic.
  """
  use Phoenix.Component

  attr :eyebrow, :string, default: nil
  attr :title, :string, required: true
  attr :subtitle, :string, default: nil

  def page_hero(assigns) do
    ~H"""
    <section class="px-4 pt-16 pb-12 lg:pt-24 lg:pb-16 bg-gradient-to-b from-[#f8fafc] to-white">
      <div class="max-w-4xl mx-auto text-center">
        <p
          :if={@eyebrow}
          class="inline-block mb-4 px-3 py-1 rounded-full text-xs font-semibold uppercase tracking-wider text-[#0c1526] bg-[#d4a843]/15"
        >
          {@eyebrow}
        </p>
        <h1 class="text-3xl lg:text-5xl font-headline font-bold text-[#0c1526] leading-tight">
          {@title}
        </h1>
        <p :if={@subtitle} class="mt-4 text-base lg:text-lg text-[#5f6b7a] max-w-2xl mx-auto">
          {@subtitle}
        </p>
      </div>
    </section>
    """
  end

  attr :icon, :string, default: nil
  attr :title, :string, required: true
  slot :inner_block, required: true

  def value_card(assigns) do
    ~H"""
    <div class="p-6 rounded-2xl border border-slate-200 bg-white hover:shadow-md transition-shadow">
      <span :if={@icon} class="material-symbols-outlined text-2xl text-[#d4a843] mb-3 block">
        {@icon}
      </span>
      <h3 class="text-lg font-headline font-semibold text-[#0c1526] mb-2">{@title}</h3>
      <p class="text-sm text-[#5f6b7a] leading-relaxed">{render_slot(@inner_block)}</p>
    </div>
    """
  end

  attr :value, :string, required: true
  attr :label, :string, required: true

  def stat(assigns) do
    ~H"""
    <div class="text-center">
      <p class="text-2xl lg:text-3xl font-headline font-bold text-[#0c1526]">{@value}</p>
      <p class="text-sm text-[#5f6b7a] mt-1">{@label}</p>
    </div>
    """
  end

  attr :icon, :string, default: nil
  attr :title, :string, required: true
  slot :inner_block, required: true

  def benefit_item(assigns) do
    ~H"""
    <div class="flex gap-3">
      <span :if={@icon} class="material-symbols-outlined text-xl text-[#d4a843] shrink-0">
        {@icon}
      </span>
      <div>
        <h3 class="text-base font-semibold text-[#0c1526]">{@title}</h3>
        <p class="text-sm text-[#5f6b7a] mt-1 leading-relaxed">{render_slot(@inner_block)}</p>
      </div>
    </div>
    """
  end

  attr :title, :string, required: true
  attr :subtitle, :string, default: nil
  attr :primary_label, :string, required: true
  attr :primary_href, :string, required: true
  attr :secondary_label, :string, default: nil
  attr :secondary_href, :string, default: nil

  def cta_band(assigns) do
    ~H"""
    <section class="px-4 py-16">
      <div class="max-w-4xl mx-auto text-center rounded-3xl bg-[#0c1526] px-6 py-12 lg:py-16">
        <h2 class="text-2xl lg:text-3xl font-headline font-bold text-[#f1f5f9]">{@title}</h2>
        <p :if={@subtitle} class="mt-3 text-[#8896ab] max-w-xl mx-auto">{@subtitle}</p>
        <div class="mt-8 flex flex-col sm:flex-row items-center justify-center gap-3">
          <a
            href={@primary_href}
            class="inline-flex items-center px-6 py-3 text-sm font-semibold text-[#0c1526] bg-[#d4a843] rounded-lg hover:bg-[#c49a3a] transition-colors"
          >
            {@primary_label}
          </a>
          <a
            :if={@secondary_label}
            href={@secondary_href}
            class="inline-flex items-center px-6 py-3 text-sm font-semibold text-[#f1f5f9] border border-[#1a2744] rounded-lg hover:border-[#d4a843] transition-colors"
          >
            {@secondary_label}
          </a>
        </div>
      </div>
    </section>
    """
  end

  @doc """
  Legal-document chrome: disclaimer banner, sticky TOC (desktop) / collapsible
  (mobile), and anchored prose sections. Each `:section` slot supplies `id` and
  `title`; its inner block is the prose (write paragraphs with explicit classes,
  e.g. `<p class="text-[#5f6b7a] leading-relaxed mb-4">…</p>`).
  """
  attr :title, :string, required: true
  attr :last_updated, :string, required: true

  slot :section, required: true do
    attr :id, :string, required: true
    attr :title, :string, required: true
  end

  def legal_layout(assigns) do
    ~H"""
    <section class="px-4 py-12 lg:py-16">
      <div class="max-w-5xl mx-auto">
        <h1 class="text-3xl lg:text-4xl font-headline font-bold text-[#0c1526]">{@title}</h1>
        <p class="mt-2 text-sm text-[#8896ab]">Last updated {@last_updated}</p>

        <div class="mt-6 p-4 rounded-xl bg-amber-50 border border-amber-200 text-sm text-amber-900">
          This document is a template provided for information only and is <strong>not legal advice</strong>. Have it reviewed by qualified counsel
          before relying on it.
        </div>

        <div class="mt-10 grid lg:grid-cols-[240px_1fr] gap-10">
          <%!-- Table of contents --%>
          <nav class="lg:sticky lg:top-24 lg:self-start">
            <details open>
              <summary class="lg:hidden cursor-pointer text-sm font-semibold text-[#0c1526] mb-2">
                On this page
              </summary>
              <p class="hidden lg:block text-xs font-semibold uppercase tracking-wider text-[#8896ab] mb-3">
                On this page
              </p>
              <ul class="space-y-2">
                <li :for={s <- @section}>
                  <a
                    href={"#" <> s.id}
                    class="text-sm text-[#5f6b7a] hover:text-[#0c1526] transition-colors"
                  >
                    {s.title}
                  </a>
                </li>
              </ul>
            </details>
          </nav>

          <%!-- Prose --%>
          <article class="min-w-0">
            <section :for={s <- @section} id={s.id} class="mb-10 scroll-mt-24">
              <h2 class="text-xl font-headline font-semibold text-[#0c1526] mb-4">{s.title}</h2>
              <div class="space-y-4">{render_slot(s)}</div>
            </section>
          </article>
        </div>
      </div>
    </section>
    """
  end
end
