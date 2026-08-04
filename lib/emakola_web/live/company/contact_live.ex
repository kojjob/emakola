defmodule EmakolaWeb.Company.ContactLive do
  use EmakolaWeb, :live_view

  import EmakolaWeb.LandingComponents, only: [landing_nav: 1, landing_footer: 1]
  import EmakolaWeb.CompanyComponents, only: [marketing_hero: 1]

  alias Emakola.Notifications.ContactMailer

  @impl true
  def mount(_params, _session, socket) do
    {:ok,
     assign(socket,
       page_title: "Contact — Makola",
       meta_description:
         "Get in touch with the Makola team — contact form, WhatsApp, email, and phone.",
       og_image: url(~p"/images/og-image.png"),
       canonical_url: url(~p"/contact"),
       json_ld: EmakolaWeb.Helpers.SEO.json_ld_organization(),
       form: contact_form(empty_form()),
       sent: false,
       error: nil,
       support_email: Application.get_env(:emakola, :contact_email, "support@emakola.com"),
       whatsapp: Application.get_env(:emakola, :support_whatsapp, "233200000000"),
       phone: Application.get_env(:emakola, :support_phone, "+233 20 000 0000")
     ), layout: false}
  end

  @impl true
  def handle_event("submit", %{"contact" => params}, socket) do
    cond do
      # Honeypot: a real user never fills this hidden field. Pretend success.
      params["company_url"] not in [nil, ""] ->
        {:noreply, assign(socket, sent: true, error: nil)}

      not valid?(params) ->
        {:noreply,
         assign(socket,
           error: "Please enter your name, a valid email, and a message.",
           form: contact_form(params)
         )}

      true ->
        _ =
          ContactMailer.deliver_contact_message(%{
            name: params["name"],
            email: params["email"],
            subject: blank_to(params["subject"], "(no subject)"),
            message: params["message"]
          })

        {:noreply, assign(socket, sent: true, error: nil, form: contact_form(empty_form()))}
    end
  end

  defp empty_form,
    do: %{
      "name" => "",
      "email" => "",
      "subject" => "",
      "message" => "",
      "company_url" => ""
    }

  defp contact_form(params), do: to_form(params, as: :contact)

  defp valid?(params) do
    present?(params["name"]) and present?(params["message"]) and valid_email?(params["email"])
  end

  defp present?(v), do: is_binary(v) and String.trim(v) != ""
  defp valid_email?(v), do: is_binary(v) and Regex.match?(~r/^[^\s@]+@[^\s@]+\.[^\s@]+$/, v)
  defp blank_to(v, default), do: if(present?(v), do: v, else: default)

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} variant={:plain}>
      <div
        id="contact-scroll"
        phx-hook="ScrollReveal"
        class="min-h-screen bg-white font-body antialiased"
      >
        <.landing_nav />
        <main>
          <.marketing_hero
            eyebrow="We're here to help"
            title="Contact"
            highlight="us"
            subtitle="Questions, feedback, or need a hand? Send us a note and we'll get back to you, usually within a day."
            padding="pt-20 pb-16 lg:pt-28 lg:pb-40"
          />

          <section class="relative z-10 px-4 sm:px-6 pt-10 lg:pt-0 pb-20 lg:pb-28 lg:-mt-24">
            <div class="max-w-5xl mx-auto grid lg:grid-cols-2 gap-6 lg:gap-8 items-stretch">
              <.form_card form={@form} sent={@sent} error={@error} />
              <.channels
                support_email={@support_email}
                whatsapp={@whatsapp}
                phone={@phone}
              />
            </div>
          </section>
        </main>
        <.landing_footer />
      </div>
    </Layouts.app>
    """
  end

  # ─────────────────────────────────────────────────────────────────────
  # Form card — floats over the hero edge; premium inputs with gold focus.
  # ─────────────────────────────────────────────────────────────────────
  attr :form, Phoenix.HTML.Form, required: true
  attr :sent, :boolean, required: true
  attr :error, :string, default: nil

  defp form_card(assigns) do
    ~H"""
    <div
      data-reveal
      class="rounded-3xl border border-slate-200/80 bg-white p-7 sm:p-9 lg:p-10 shadow-xl shadow-[#0c1526]/[0.08]"
    >
      <div
        :if={@sent}
        id="contact-success"
        class="flex items-start gap-4 rounded-2xl bg-emerald-50 border border-emerald-200 p-6 text-emerald-800"
      >
        <span class="material-symbols-outlined text-2xl text-emerald-600">check_circle</span>
        <div>
          <p class="font-semibold">Message sent</p>
          <p class="mt-1 text-sm text-emerald-700">
            Thanks — we've got your note and will get back to you soon.
          </p>
        </div>
      </div>

      <.form :if={!@sent} for={@form} id="contact-form" phx-submit="submit" class="space-y-5">
        <p
          :if={@error}
          id="contact-form-error"
          class="flex items-center gap-2 rounded-xl bg-red-50 border border-red-200 px-4 py-3 text-sm text-red-700"
        >
          <span class="material-symbols-outlined text-lg">error</span>
          {@error}
        </p>

        <%!-- Honeypot: visually hidden, off the tab order --%>
        <div class="hidden" aria-hidden="true">
          <.input
            field={@form[:company_url]}
            type="text"
            label="Company URL"
            tabindex="-1"
            autocomplete="off"
          />
        </div>

        <div class="grid sm:grid-cols-2 gap-5">
          <div>
            <label class={label_class()} for="contact_name">Name</label>
            <.input
              field={@form[:name]}
              type="text"
              required
              placeholder="Your full name"
              class={input_class()}
            />
          </div>
          <div>
            <label class={label_class()} for="contact_email">Email</label>
            <.input
              field={@form[:email]}
              type="email"
              required
              placeholder="you@example.com"
              class={input_class()}
            />
          </div>
        </div>

        <div>
          <label class={label_class()} for="contact_subject">Subject</label>
          <.input
            field={@form[:subject]}
            type="text"
            placeholder="What's this about?"
            class={input_class()}
          />
        </div>

        <div>
          <label class={label_class()} for="contact_message">Message</label>
          <.input
            field={@form[:message]}
            type="textarea"
            rows="5"
            required
            placeholder="Tell us how we can help…"
            class={input_class()}
          />
        </div>

        <button
          type="submit"
          class="group inline-flex w-full sm:w-auto items-center justify-center gap-2 px-7 py-3.5 text-sm font-semibold text-[#0c1526] bg-[#d4a843] rounded-xl shadow-lg shadow-[#d4a843]/25 transition-all duration-200 hover:bg-[#c49a3a] hover:-translate-y-0.5 focus-visible:ring-2 focus-visible:ring-[#d4a843] focus-visible:ring-offset-2"
        >
          Send message
          <span class="material-symbols-outlined text-lg transition-transform duration-200 group-hover:translate-x-0.5">
            send
          </span>
        </button>
      </.form>
    </div>
    """
  end

  # ─────────────────────────────────────────────────────────────────────
  # Channels — dark navy card with gold-accented contact rows.
  # ─────────────────────────────────────────────────────────────────────
  attr :support_email, :string, required: true
  attr :whatsapp, :string, required: true
  attr :phone, :string, required: true

  defp channels(assigns) do
    ~H"""
    <div
      data-reveal
      style="transition-delay: 0.1s"
      class="rounded-3xl border border-slate-200/80 bg-white p-7 sm:p-9 lg:p-10 shadow-xl shadow-[#0c1526]/[0.08]"
    >
      <h2 class="text-lg font-headline font-bold text-[#0c1526]">Prefer to reach us directly?</h2>
      <p class="mt-2 text-sm text-[#5f6b7a]">Pick whatever's easiest for you.</p>

      <div class="mt-6 space-y-3">
        <.channel_row icon="mail" title="Email" href={"mailto:" <> @support_email}>
          {@support_email}
        </.channel_row>
        <.channel_row icon="chat" title="WhatsApp" href={"https://wa.me/" <> @whatsapp}>
          Chat with us on WhatsApp
        </.channel_row>
        <.channel_row icon="call" title="Phone" href={"tel:" <> @phone}>
          {@phone}
        </.channel_row>
      </div>

      <div class="mt-6 flex items-center gap-3 border-t border-slate-100 pt-6">
        <span class="inline-flex h-9 w-9 shrink-0 items-center justify-center rounded-lg bg-[#d4a843]/12 text-[#d4a843]">
          <span class="material-symbols-outlined text-lg">schedule</span>
        </span>
        <div>
          <p class="text-xs font-semibold uppercase tracking-wider text-[#8896ab]">Hours</p>
          <p class="text-sm font-medium text-[#0c1526]">Monday–Friday, 9am–6pm GMT</p>
        </div>
      </div>
    </div>
    """
  end

  attr :icon, :string, required: true
  attr :title, :string, required: true
  attr :href, :string, required: true
  slot :inner_block, required: true

  defp channel_row(assigns) do
    ~H"""
    <a
      href={@href}
      class="group flex items-center gap-4 rounded-2xl border border-slate-200 bg-white p-4 transition-all duration-200 hover:-translate-y-0.5 hover:border-[#d4a843]/50 hover:bg-[#fffdf7] hover:shadow-md"
    >
      <span class="inline-flex h-11 w-11 shrink-0 items-center justify-center rounded-xl bg-[#0c1526] text-[#d4a843] transition-transform duration-200 group-hover:scale-105">
        <span class="material-symbols-outlined text-xl">{@icon}</span>
      </span>
      <div class="min-w-0 flex-1">
        <p class="text-xs font-semibold uppercase tracking-wider text-[#8896ab]">{@title}</p>
        <p class="text-sm font-medium text-[#0c1526] break-words group-hover:text-[#c49a3a] transition-colors">
          {render_slot(@inner_block)}
        </p>
      </div>
      <span class="material-symbols-outlined text-lg text-slate-300 transition-all duration-200 group-hover:text-[#d4a843] group-hover:translate-x-0.5">
        arrow_forward
      </span>
    </a>
    """
  end

  defp label_class,
    do: "block text-xs font-semibold uppercase tracking-wider text-[#5f6b7a] mb-1.5"

  defp input_class,
    do:
      "w-full rounded-xl border border-slate-200 bg-slate-50/60 px-4 py-3 text-sm text-[#0c1526] placeholder:text-slate-400 transition-all duration-200 focus:border-[#d4a843] focus:bg-white focus:ring-4 focus:ring-[#d4a843]/15 focus:outline-none"
end
