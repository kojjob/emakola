defmodule EmakolaWeb.Company.ContactLive do
  use EmakolaWeb, :live_view

  import EmakolaWeb.LandingComponents, only: [landing_nav: 1, landing_footer: 1]
  import EmakolaWeb.CompanyComponents

  alias Emakola.Notifications.ContactMailer

  @impl true
  def mount(_params, _session, socket) do
    {:ok,
     assign(socket,
       page_title: "Contact — Emakola",
       meta_description:
         "Get in touch with the Emakola team — contact form, WhatsApp, email, and phone.",
       og_image: url(~p"/images/og-image.png"),
       canonical_url: url(~p"/contact"),
       mobile_menu_open: false,
       form: empty_form(),
       sent: false,
       error: nil,
       support_email: Application.get_env(:emakola, :contact_email, "support@emakola.com"),
       whatsapp: Application.get_env(:emakola, :support_whatsapp, "233200000000"),
       phone: Application.get_env(:emakola, :support_phone, "+233 20 000 0000")
     ), layout: false}
  end

  @impl true
  def handle_event("toggle_mobile_menu", _params, socket) do
    {:noreply, assign(socket, mobile_menu_open: !socket.assigns.mobile_menu_open)}
  end

  def handle_event("submit", %{"contact" => params}, socket) do
    cond do
      # Honeypot: a real user never fills this hidden field. Pretend success.
      params["company_url"] not in [nil, ""] ->
        {:noreply, assign(socket, sent: true, error: nil)}

      not valid?(params) ->
        {:noreply,
         assign(socket,
           error: "Please enter your name, a valid email, and a message.",
           form: params
         )}

      true ->
        _ =
          ContactMailer.deliver_contact_message(%{
            name: params["name"],
            email: params["email"],
            subject: blank_to(params["subject"], "(no subject)"),
            message: params["message"]
          })

        {:noreply, assign(socket, sent: true, error: nil, form: empty_form())}
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

  defp valid?(params) do
    present?(params["name"]) and present?(params["message"]) and valid_email?(params["email"])
  end

  defp present?(v), do: is_binary(v) and String.trim(v) != ""
  defp valid_email?(v), do: is_binary(v) and Regex.match?(~r/^[^\s@]+@[^\s@]+\.[^\s@]+$/, v)
  defp blank_to(v, default), do: if(present?(v), do: v, else: default)

  @impl true
  def render(assigns) do
    ~H"""
    <div class="min-h-screen bg-white font-body antialiased">
      <.landing_nav mobile_menu_open={@mobile_menu_open} />
      <main class="pt-16">
        <.page_hero
          eyebrow="Contact"
          title="Contact us"
          subtitle="Questions, feedback, or need a hand? We'd love to hear from you."
        />

        <section class="px-4 pb-16">
          <div class="max-w-5xl mx-auto grid lg:grid-cols-2 gap-10">
            <%!-- Form --%>
            <div>
              <div
                :if={@sent}
                class="p-6 rounded-2xl bg-emerald-50 border border-emerald-200 text-emerald-800"
              >
                Thanks — your message has been sent. We'll get back to you soon.
              </div>

              <form :if={!@sent} id="contact-form" phx-submit="submit" class="space-y-4">
                <p :if={@error} class="text-sm text-red-600">{@error}</p>

                <%!-- Honeypot: visually hidden, off the tab order --%>
                <div class="hidden" aria-hidden="true">
                  <label>
                    Company URL
                    <input
                      type="text"
                      name="contact[company_url]"
                      tabindex="-1"
                      autocomplete="off"
                    />
                  </label>
                </div>

                <div>
                  <label class="block text-sm font-medium text-[#0c1526] mb-1">Name</label>
                  <input
                    type="text"
                    name="contact[name]"
                    value={@form["name"]}
                    required
                    class="w-full px-3 py-2.5 text-sm rounded-lg border border-slate-300 focus:ring-2 focus:ring-[#d4a843] focus:border-[#d4a843]"
                  />
                </div>
                <div>
                  <label class="block text-sm font-medium text-[#0c1526] mb-1">Email</label>
                  <input
                    type="email"
                    name="contact[email]"
                    value={@form["email"]}
                    required
                    class="w-full px-3 py-2.5 text-sm rounded-lg border border-slate-300 focus:ring-2 focus:ring-[#d4a843] focus:border-[#d4a843]"
                  />
                </div>
                <div>
                  <label class="block text-sm font-medium text-[#0c1526] mb-1">Subject</label>
                  <input
                    type="text"
                    name="contact[subject]"
                    value={@form["subject"]}
                    class="w-full px-3 py-2.5 text-sm rounded-lg border border-slate-300 focus:ring-2 focus:ring-[#d4a843] focus:border-[#d4a843]"
                  />
                </div>
                <div>
                  <label class="block text-sm font-medium text-[#0c1526] mb-1">Message</label>
                  <textarea
                    name="contact[message]"
                    rows="5"
                    required
                    class="w-full px-3 py-2.5 text-sm rounded-lg border border-slate-300 focus:ring-2 focus:ring-[#d4a843] focus:border-[#d4a843]"
                  >{@form["message"]}</textarea>
                </div>
                <button
                  type="submit"
                  class="inline-flex items-center px-6 py-3 text-sm font-semibold text-[#0c1526] bg-[#d4a843] rounded-lg hover:bg-[#c49a3a] transition-colors"
                >
                  Send message
                </button>
              </form>
            </div>

            <%!-- Channels --%>
            <div class="space-y-6">
              <h2 class="text-xl font-headline font-semibold text-[#0c1526]">
                Other ways to reach us
              </h2>
              <.benefit_item icon="mail" title="Email">
                <a href={"mailto:" <> @support_email} class="text-[#d4a843] hover:underline">
                  {@support_email}
                </a>
              </.benefit_item>
              <.benefit_item icon="chat" title="WhatsApp">
                <a href={"https://wa.me/" <> @whatsapp} class="text-[#d4a843] hover:underline">
                  Chat with us on WhatsApp
                </a>
              </.benefit_item>
              <.benefit_item icon="call" title="Phone">
                <a href={"tel:" <> @phone} class="text-[#d4a843] hover:underline">{@phone}</a>
              </.benefit_item>
              <.benefit_item icon="schedule" title="Hours">
                Monday–Friday, 9am–6pm GMT.
              </.benefit_item>
            </div>
          </div>
        </section>
      </main>
      <.landing_footer />
    </div>
    """
  end
end
