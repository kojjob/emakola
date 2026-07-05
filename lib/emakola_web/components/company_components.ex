defmodule EmakolaWeb.CompanyComponents do
  @moduledoc """
  Shared building blocks for the apex company/legal pages
  (About, Careers, Press, Contact, Legal, Privacy, Terms, Cookie).
  Stateless function components matching the marketing aesthetic.
  """
  use Phoenix.Component

  @doc """
  Dark cinematic marketing hero shared by the company pages: gold eyebrow
  pill, headline with an optional gold-underlined trailing word, and subtitle.
  Entrance animation via the `about-rise` utility; reduced-motion safe.

  The full "title highlight" string is rendered once as `sr-only` for screen
  readers, with the visual (split) copy marked `aria-hidden`.
  """
  attr :eyebrow, :string, required: true
  attr :title, :string, required: true
  attr :highlight, :string, default: nil
  attr :subtitle, :string, default: nil
  attr :padding, :string, default: "py-24 lg:py-32"

  def marketing_hero(assigns) do
    ~H"""
    <section class="relative isolate overflow-hidden bg-[#0c1526] text-[#f1f5f9] pt-16">
      <div
        aria-hidden="true"
        class="absolute inset-0 -z-10"
        style="background:
          radial-gradient(58rem 30rem at 85% -12%, rgba(212,168,67,0.20), transparent 60%),
          radial-gradient(46rem 28rem at -4% 110%, rgba(181,83,46,0.16), transparent 55%);"
      >
      </div>

      <div class={["relative max-w-4xl mx-auto px-4 sm:px-6 text-center", @padding]}>
        <span class="about-rise inline-flex items-center gap-2 px-4 py-1.5 rounded-full border border-[#d4a843]/30 bg-[#d4a843]/10 text-xs font-semibold uppercase tracking-[0.22em] text-[#d4a843]">
          <span class="w-1.5 h-1.5 rounded-full bg-[#d4a843] animate-pulse"></span> {@eyebrow}
        </span>
        <h1
          class="about-rise mt-7 text-4xl sm:text-5xl lg:text-6xl font-headline font-extrabold leading-[1.08] [text-shadow:0_2px_20px_rgba(12,21,38,0.55)]"
          style="animation-delay: 0.12s"
        >
          <span :if={@highlight} class="sr-only">{@title} {@highlight}</span>
          <span aria-hidden={@highlight && "true"}>
            {@title}
            <span :if={@highlight} class="relative whitespace-nowrap text-[#d4a843]">
              {@highlight}
              <svg
                viewBox="0 0 200 14"
                preserveAspectRatio="none"
                class="absolute -bottom-2 left-0 w-full h-2.5 text-[#d4a843]/70"
              >
                <path
                  class="about-underline"
                  d="M2 9 C 50 3, 100 3, 135 7 S 188 11, 198 5"
                  fill="none"
                  stroke="currentColor"
                  stroke-width="3"
                  stroke-linecap="round"
                />
              </svg>
            </span>
          </span>
        </h1>
        <p
          :if={@subtitle}
          class="about-rise mt-8 text-base lg:text-xl text-[#cbd5e1] max-w-2xl mx-auto leading-relaxed"
          style="animation-delay: 0.24s"
        >
          {@subtitle}
        </p>
      </div>
    </section>
    """
  end

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
  attr :subtitle, :string, default: nil

  slot :section, required: true do
    attr :id, :string, required: true
    attr :title, :string, required: true
  end

  def legal_layout(assigns) do
    ~H"""
    <%!-- Dark brand hero --%>
    <section class="relative isolate overflow-hidden bg-[#0c1526] text-[#f1f5f9] pt-16">
      <div
        aria-hidden="true"
        class="absolute inset-0 -z-10"
        style="background:
          radial-gradient(54rem 26rem at 86% -20%, rgba(212,168,67,0.18), transparent 60%),
          radial-gradient(40rem 24rem at -4% 120%, rgba(181,83,46,0.12), transparent 55%);"
      >
      </div>

      <div class="max-w-5xl mx-auto px-4 sm:px-6 py-16 lg:py-20">
        <span class="inline-flex items-center gap-2 px-4 py-1.5 rounded-full border border-[#d4a843]/30 bg-[#d4a843]/10 text-xs font-semibold uppercase tracking-[0.22em] text-[#d4a843]">
          <span class="w-1.5 h-1.5 rounded-full bg-[#d4a843]"></span> Legal
        </span>
        <h1 class="mt-6 text-4xl lg:text-5xl font-headline font-extrabold leading-[1.08] [text-shadow:0_2px_20px_rgba(12,21,38,0.55)]">
          {@title}
        </h1>
        <p
          :if={@subtitle}
          class="mt-4 text-base lg:text-lg text-[#cbd5e1] max-w-2xl leading-relaxed"
        >
          {@subtitle}
        </p>
        <span class="mt-6 inline-flex items-center gap-2 text-sm text-[#8896ab]">
          <span class="material-symbols-outlined text-base text-[#d4a843]">update</span>
          Last updated {@last_updated}
        </span>
      </div>
    </section>

    <%!-- Document body --%>
    <section class="px-4 sm:px-6 py-12 lg:py-16">
      <div class="max-w-5xl mx-auto">
        <div class="grid lg:grid-cols-[240px_1fr] gap-10 lg:gap-14">
          <%!-- Table of contents --%>
          <nav class="lg:sticky lg:top-24 lg:self-start">
            <details open>
              <summary class="lg:hidden cursor-pointer text-sm font-semibold text-[#0c1526] mb-3">
                On this page
              </summary>
              <p class="hidden lg:block text-[10px] font-semibold uppercase tracking-[0.2em] text-[#8896ab] mb-4">
                On this page
              </p>
              <ul class="space-y-1">
                <li :for={s <- @section}>
                  <a
                    href={"#" <> s.id}
                    class="block py-1.5 pl-3 text-sm border-l-2 border-transparent text-[#5f6b7a] hover:text-[#0c1526] hover:border-[#d4a843] transition-colors"
                  >
                    {s.title}
                  </a>
                </li>
              </ul>
            </details>
          </nav>

          <%!-- Prose --%>
          <article class="min-w-0 max-w-2xl">
            <section :for={s <- @section} id={s.id} class="mb-12 scroll-mt-24">
              <h2 class="text-xl lg:text-2xl font-headline font-bold text-[#0c1526] mb-4">
                {s.title}
              </h2>
              <div class="space-y-4">{render_slot(s)}</div>
            </section>
          </article>
        </div>
      </div>
    </section>
    """
  end
end
