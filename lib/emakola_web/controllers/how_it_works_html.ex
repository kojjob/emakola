defmodule EmakolaWeb.HowItWorksHTML do
  @moduledoc """
  Photo-led explanation of Makola's connected commerce network.

  The page keeps the worked GH₵85 sale easy to audit while progressively
  revealing the people, goods, messages, and money involved.
  """

  use EmakolaWeb, :html

  import EmakolaWeb.LandingComponents, only: [landing_footer: 1, landing_nav: 1]

  @sale_steps [
    %{
      icon: "hero-cloud-arrow-up",
      title: "A supplier publishes once",
      label: "SUPPLY",
      copy:
        "Kumasi Textiles lists an Adinkra tote at GH₵38 wholesale, with a suggested GH₵60 shop price and a dispatch quote for every region."
    },
    %{
      icon: "hero-building-storefront",
      title: "A shop stocks it in one click",
      label: "STOCK",
      copy:
        "Adwoa sees her exact GH₵22 product margin before she adds the tote to her boutique. No bulk order, warehouse, or upfront stock."
    },
    %{
      icon: "hero-device-phone-mobile",
      title: "A customer pays like normal",
      label: "PAY",
      copy:
        "The shopper sees every charge before confirming GH₵85 with MTN MoMo, Telecel Cash, or a card. One checkout and one receipt."
    },
    %{
      icon: "hero-truck",
      title: "The supplier ships it",
      label: "SHIP",
      copy:
        "Kumasi Textiles receives the order and destination by SMS or WhatsApp, then dispatches directly to the customer."
    },
    %{
      icon: "hero-arrows-right-left",
      title: "The money splits itself",
      label: "SPLIT",
      copy:
        "Supplier cost, dispatch, shop earnings, delivery, and Makola's fee are recorded and routed to the right accounts automatically."
    }
  ]

  @stakeholders [
    %{
      role: "The shopper",
      subtitle: "Anyone in Ghana with a phone",
      icon: "hero-shopping-bag",
      image: "/images/landing/story-storefront.jpg",
      alt: "Shopper walking through an Accra market",
      tone: "bg-[#dbeafe] text-[#1d4ed8]",
      bullets: [
        "Pays with familiar mobile money or card",
        "Sees every fee before confirming",
        "Gets SMS and WhatsApp order updates"
      ]
    },
    %{
      role: "The shop owner",
      subtitle: "The social seller building a real brand",
      icon: "hero-building-storefront",
      image: "/images/landing/story-momo.jpg",
      alt: "Ghanaian shop owner smiling after a successful sale",
      tone: "bg-[#dcfce7] text-[#15803d]",
      bullets: [
        "Launches a branded shop without buying stock",
        "Keeps the product margin on every sale",
        "Sees orders and earnings in one dashboard"
      ]
    },
    %{
      role: "The supplier",
      subtitle: "The maker or wholesaler with real goods",
      icon: "hero-cube",
      image: "/images/landing/store-tailor.jpg",
      alt: "Ghanaian tailor working with fabric in his shop",
      tone: "bg-[#fef3c7] text-[#b45309]",
      bullets: [
        "Publishes once and reaches many shops",
        "Controls wholesale prices and dispatch quotes",
        "Receives fulfillment details instantly"
      ]
    },
    %{
      role: "The market",
      subtitle: "The trust layer connecting every trade",
      icon: "hero-squares-plus",
      image: "/images/dashboard-preview.png",
      alt: "Makola merchant dashboard showing commerce operations",
      tone: "bg-[#ede9fe] text-[#6d28d9]",
      bullets: [
        "Records every pesewa of every settlement",
        "Automates payouts, alerts, and receipts",
        "Gets stronger as suppliers and shops join"
      ]
    }
  ]

  def show(assigns) do
    ~H"""
    <div
      id="how-it-works-page"
      data-scroll-reveal
      class={["min-h-screen overflow-hidden bg-[#f8f6ef] font-body text-[#10231e] antialiased"]}
    >
      <.landing_nav />
      <main class={["pt-16"]}>
        <.hero />
        <.market_idea />
        <.market_flow />
        <.sale_journey />
        <.money_split />
        <.stakeholders />
        <.trust_machinery />
        <.closing_cta />
      </main>
      <.landing_footer />
    </div>
    """
  end

  defp hero(assigns) do
    ~H"""
    <section class={["relative isolate overflow-hidden bg-[#081d18] text-white"]}>
      <div
        aria-hidden="true"
        class={["absolute inset-0 -z-10 opacity-90"]}
        style="background: radial-gradient(55rem 32rem at 12% 12%, rgba(16,185,129,0.22), transparent 60%), radial-gradient(44rem 30rem at 92% 78%, rgba(212,168,67,0.18), transparent 62%);"
      >
      </div>
      <div
        aria-hidden="true"
        class={["absolute -right-20 top-20 -z-10 h-80 w-80 rounded-full border border-white/10"]}
      >
      </div>
      <div
        aria-hidden="true"
        class={["absolute -right-4 top-36 -z-10 h-52 w-52 rounded-full border border-[#d4a843]/20"]}
      >
      </div>

      <div class={[
        "mx-auto grid min-h-[720px] max-w-7xl items-center gap-14 px-4 py-20 sm:px-6 lg:grid-cols-[1.02fr_0.98fr] lg:px-8 lg:py-24"
      ]}>
        <div class={["max-w-2xl"]}>
          <div class={[
            "market-hero-rise inline-flex items-center gap-2 rounded-full border border-emerald-300/20 bg-emerald-300/10 px-3 py-1.5 text-xs font-semibold uppercase tracking-[0.18em] text-emerald-200"
          ]}>
            <span class={["h-1.5 w-1.5 rounded-full bg-emerald-300"]}></span>
            Ghana's connected commerce network
          </div>
          <h1
            class={[
              "market-hero-rise mt-7 font-headline text-5xl font-extrabold leading-[0.98] tracking-[-0.04em] sm:text-6xl lg:text-7xl"
            ]}
            style="animation-delay: 90ms"
          >
            One market.<br />
            <span class={["text-[#e4bd63]"]}>Every stall connected.</span>
          </h1>
          <p
            class={["market-hero-rise mt-7 max-w-xl text-lg leading-8 text-slate-300 lg:text-xl"]}
            style="animation-delay: 180ms"
          >
            Open a real online shop, stock trusted products without buying inventory,
            and let every pesewa find the right person automatically.
          </p>
          <div
            class={["market-hero-rise mt-9 flex flex-col gap-3 sm:flex-row"]}
            style="animation-delay: 270ms"
          >
            <a
              href="/auth/register"
              class={[
                "group inline-flex items-center justify-center gap-2 rounded-xl bg-[#d4a843] px-6 py-3.5 text-sm font-bold text-[#081d18] shadow-lg shadow-black/20 transition duration-300 hover:-translate-y-0.5 hover:bg-[#e4bd63] focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-[#e4bd63] focus-visible:ring-offset-2 focus-visible:ring-offset-[#081d18]"
              ]}
            >
              Start your shop — free
              <.icon
                name="hero-arrow-right"
                class={["h-4 w-4 transition-transform duration-300 group-hover:translate-x-1"]}
              />
            </a>
            <a
              href="/how-it-works/tour"
              class={[
                "inline-flex items-center justify-center gap-2 rounded-xl border border-white/15 bg-white/5 px-6 py-3.5 text-sm font-semibold text-white backdrop-blur transition duration-300 hover:border-white/30 hover:bg-white/10"
              ]}
            >
              <.icon name="hero-play" class={["h-4 w-4 text-emerald-300"]} /> Watch one sale unfold
            </a>
          </div>
          <div
            class={[
              "market-hero-rise mt-10 flex flex-wrap gap-x-6 gap-y-3 text-xs font-medium text-slate-400"
            ]}
            style="animation-delay: 360ms"
          >
            <span class={["inline-flex items-center gap-2"]}>
              <.icon name="hero-map-pin" class={["h-4 w-4 text-emerald-300"]} /> Built in Ghana
            </span>
            <span class={["inline-flex items-center gap-2"]}>
              <.icon name="hero-device-phone-mobile" class={["h-4 w-4 text-emerald-300"]} />
              MoMo first
            </span>
            <span class={["inline-flex items-center gap-2"]}>
              <.icon name="hero-check-badge" class={["h-4 w-4 text-emerald-300"]} />
              Every pesewa traceable
            </span>
          </div>
        </div>

        <div
          class={["market-hero-rise relative mx-auto w-full max-w-xl lg:ml-auto"]}
          style="animation-delay: 180ms"
        >
          <div class={[
            "relative overflow-hidden rounded-[2rem] border border-white/10 bg-white/5 p-2 shadow-2xl shadow-black/40"
          ]}>
            <img
              src="/images/landing/hero-market-woman.jpg"
              alt="Ghanaian market trader taking a call while carrying goods"
              width="1600"
              height="901"
              fetchpriority="high"
              class={["h-[470px] w-full rounded-[1.55rem] object-cover object-center sm:h-[540px]"]}
            />
            <div
              aria-hidden="true"
              class={[
                "absolute inset-2 rounded-[1.55rem] bg-gradient-to-t from-[#071713] via-transparent to-transparent"
              ]}
            >
            </div>
            <div class={[
              "absolute inset-x-7 bottom-7 rounded-2xl border border-white/10 bg-[#071713]/85 p-5 backdrop-blur-md"
            ]}>
              <div class={["flex items-center justify-between gap-4"]}>
                <div>
                  <p class={["text-xs font-semibold uppercase tracking-[0.16em] text-emerald-300"]}>
                    One connected sale
                  </p>
                  <p class={["mt-1 text-lg font-bold text-white"]}>From product to payout</p>
                </div>
                <span class={[
                  "inline-flex h-11 w-11 items-center justify-center rounded-xl bg-[#d4a843] text-[#081d18] shadow-lg"
                ]}>
                  <.icon name="hero-bolt" class={["h-5 w-5"]} />
                </span>
              </div>
              <div class={["mt-5 grid grid-cols-3 divide-x divide-white/10"]}>
                <div class={["pr-3"]}>
                  <p class={["text-2xl font-extrabold text-white"]}>1</p>
                  <p class={["text-[11px] text-slate-400"]}>payment</p>
                </div>
                <div class={["px-3"]}>
                  <p class={["text-2xl font-extrabold text-white"]}>3</p>
                  <p class={["text-[11px] text-slate-400"]}>payouts</p>
                </div>
                <div class={["pl-3"]}>
                  <p class={["text-2xl font-extrabold text-white"]}>0</p>
                  <p class={["text-[11px] text-slate-400"]}>chasing</p>
                </div>
              </div>
            </div>
          </div>

          <div class={[
            "market-float absolute -left-4 top-16 hidden items-center gap-3 rounded-2xl border border-white/10 bg-white p-3 pr-5 text-[#10231e] shadow-xl sm:flex"
          ]}>
            <span class={[
              "inline-flex h-10 w-10 items-center justify-center rounded-xl bg-emerald-100 text-emerald-700"
            ]}>
              <.icon name="hero-building-storefront" class={["h-5 w-5"]} />
            </span>
            <div>
              <p class={["text-[10px] font-semibold uppercase tracking-wider text-slate-400"]}>
                Shop stocked
              </p>
              <p class={["text-sm font-bold"]}>No inventory bought</p>
            </div>
          </div>

          <div class={[
            "market-float market-float-delay absolute -right-4 top-44 hidden items-center gap-3 rounded-2xl border border-white/10 bg-white p-3 pr-5 text-[#10231e] shadow-xl sm:flex"
          ]}>
            <span class={[
              "inline-flex h-10 w-10 items-center justify-center rounded-xl bg-amber-100 text-amber-700"
            ]}>
              <.icon name="hero-banknotes" class={["h-5 w-5"]} />
            </span>
            <div>
              <p class={["text-[10px] font-semibold uppercase tracking-wider text-slate-400"]}>
                Settlement
              </p>
              <p class={["text-sm font-bold"]}>Every share recorded</p>
            </div>
          </div>
        </div>
      </div>
    </section>
    """
  end

  defp market_idea(assigns) do
    ~H"""
    <section class={["bg-[#f8f6ef] px-4 py-20 sm:px-6 lg:py-28"]}>
      <div class={["mx-auto grid max-w-6xl items-stretch gap-8 lg:grid-cols-[0.9fr_1.1fr]"]}>
        <div data-reveal="left" class={["relative min-h-[420px] overflow-hidden rounded-[2rem]"]}>
          <img
            src="/images/landing/cta-market.jpg"
            alt="Traders and customers moving through a busy West African market"
            loading="lazy"
            width="1600"
            height="600"
            class={["absolute inset-0 h-full w-full object-cover"]}
          />
          <div
            aria-hidden="true"
            class={[
              "absolute inset-0 bg-gradient-to-t from-[#081d18] via-[#081d18]/45 to-transparent"
            ]}
          >
          </div>
          <div class={["absolute inset-x-7 bottom-7 text-white"]}>
            <p class={["text-xs font-semibold uppercase tracking-[0.2em] text-[#e4bd63]"]}>
              The original network
            </p>
            <p class={["mt-3 max-w-sm font-headline text-3xl font-bold leading-tight"]}>
              Real markets already run on relationships, supply, and margin.
            </p>
          </div>
        </div>

        <div
          data-reveal="right"
          class={[
            "flex flex-col justify-center rounded-[2rem] border border-[#dfe5dc] bg-white p-8 shadow-sm sm:p-12 lg:p-14"
          ]}
        >
          <p class={["text-xs font-semibold uppercase tracking-[0.2em] text-emerald-700"]}>
            The idea in one minute
          </p>
          <h2 class={[
            "mt-4 font-headline text-3xl font-bold leading-tight text-[#10231e] sm:text-4xl"
          ]}>
            Makola puts the whole trading system online.
          </h2>
          <p class={["mt-6 text-base leading-7 text-[#586961]"]}>
            A trader rarely makes everything she sells. She knows suppliers, understands her
            margin, and brings the right goods to her customers. Makola keeps that human
            model, then removes the manual work around it.
          </p>
          <p class={["mt-4 text-base leading-7 text-[#586961]"]}>
            Suppliers publish once. Shops stock with one click. Customers pay with the money
            they already use. The platform records and routes each person's share.
          </p>
          <div class={["mt-8 grid gap-3 sm:grid-cols-3"]}>
            <.idea_stat icon="hero-link" value="Connected" label="catalogs" />
            <.idea_stat icon="hero-receipt-percent" value="Itemized" label="checkout" />
            <.idea_stat icon="hero-arrows-right-left" value="Automatic" label="settlement" />
          </div>
        </div>
      </div>
    </section>
    """
  end

  attr :icon, :string, required: true
  attr :value, :string, required: true
  attr :label, :string, required: true

  defp idea_stat(assigns) do
    ~H"""
    <div class={["rounded-2xl bg-[#f1f6f2] p-4"]}>
      <.icon name={@icon} class={["h-5 w-5 text-emerald-700"]} />
      <p class={["mt-3 text-sm font-bold text-[#10231e]"]}>{@value}</p>
      <p class={["text-xs text-[#718078]"]}>{@label}</p>
    </div>
    """
  end

  defp market_flow(assigns) do
    ~H"""
    <section id="market-flow" class={["bg-white px-4 py-20 sm:px-6 lg:py-28"]}>
      <div class={["mx-auto max-w-6xl"]}>
        <div data-reveal class={["mx-auto max-w-2xl text-center"]}>
          <p class={["text-xs font-semibold uppercase tracking-[0.2em] text-emerald-700"]}>
            The network
          </p>
          <h2 class={["mt-4 font-headline text-3xl font-bold text-[#10231e] sm:text-4xl"]}>
            Goods move forward. Money moves back.
          </h2>
          <p class={["mt-4 text-base leading-7 text-[#64736c]"]}>
            One clear chain joins people who may never meet, without making any of them
            trust a spreadsheet or chase a transfer.
          </p>
        </div>

        <div
          data-reveal="scale"
          class={[
            "mt-14 rounded-[2rem] border border-[#dfe5dc] bg-[#f8faf8] p-6 shadow-sm sm:p-9 lg:p-12"
          ]}
        >
          <div class={["grid items-center gap-4 lg:grid-cols-[1fr_0.28fr_1fr_0.28fr_1fr_0.28fr_1fr]"]}>
            <.flow_node
              icon="hero-cube"
              eyebrow="01 · Supplier"
              title="Publishes"
              detail="Product, price and dispatch"
              tone="bg-amber-100 text-amber-700"
            />
            <.flow_connector delay="market-flow-delay-1" />
            <.flow_node
              icon="hero-building-storefront"
              eyebrow="02 · Shop"
              title="Stocks"
              detail="Brand, margin and customers"
              tone="bg-emerald-100 text-emerald-700"
            />
            <.flow_connector delay="market-flow-delay-2" />
            <.flow_node
              icon="hero-shopping-bag"
              eyebrow="03 · Shopper"
              title="Buys"
              detail="One transparent checkout"
              tone="bg-blue-100 text-blue-700"
            />
            <.flow_connector delay="market-flow-delay-3" />
            <.flow_node
              icon="hero-arrows-right-left"
              eyebrow="04 · Makola"
              title="Settles"
              detail="Every share to its owner"
              tone="bg-violet-100 text-violet-700"
            />
          </div>

          <div class={[
            "mt-8 flex items-center justify-center gap-2 rounded-2xl bg-[#081d18] px-5 py-4 text-center text-sm font-medium text-white"
          ]}>
            <.icon name="hero-shield-check" class={["h-5 w-5 shrink-0 text-emerald-300"]} />
            One order ID links the product, fulfillment, notifications, and every payout.
          </div>
        </div>
      </div>
    </section>
    """
  end

  attr :icon, :string, required: true
  attr :eyebrow, :string, required: true
  attr :title, :string, required: true
  attr :detail, :string, required: true
  attr :tone, :string, required: true

  defp flow_node(assigns) do
    ~H"""
    <div class={[
      "group rounded-2xl border border-[#e2e8e3] bg-white p-5 text-center transition duration-300 hover:-translate-y-1 hover:shadow-lg"
    ]}>
      <span class={["mx-auto inline-flex h-12 w-12 items-center justify-center rounded-2xl", @tone]}>
        <.icon name={@icon} class={["h-6 w-6"]} />
      </span>
      <p class={["mt-4 text-[10px] font-bold uppercase tracking-[0.16em] text-[#809087]"]}>
        {@eyebrow}
      </p>
      <h3 class={["mt-1 text-lg font-bold text-[#10231e]"]}>{@title}</h3>
      <p class={["mt-1 text-xs leading-5 text-[#6c7a73]"]}>{@detail}</p>
    </div>
    """
  end

  attr :delay, :string, required: true

  defp flow_connector(assigns) do
    ~H"""
    <div aria-hidden="true" class={["flex items-center justify-center py-1 lg:py-0"]}>
      <div class={["market-flow-line hidden lg:block", @delay]}>
        <span class={["market-flow-dot"]}></span>
      </div>
      <.icon name="hero-arrow-down" class={["h-5 w-5 text-[#a8b2ac] lg:hidden"]} />
    </div>
    """
  end

  defp sale_journey(assigns) do
    assigns = assign(assigns, :sale_steps, @sale_steps)

    ~H"""
    <section id="sale-journey" class={["bg-[#f8f6ef] px-4 py-20 sm:px-6 lg:py-28"]}>
      <div class={["mx-auto max-w-6xl"]}>
        <div data-reveal class={["max-w-2xl"]}>
          <p class={["text-xs font-semibold uppercase tracking-[0.2em] text-emerald-700"]}>
            A sale, step by step
          </p>
          <h2 class={["mt-4 font-headline text-3xl font-bold text-[#10231e] sm:text-4xl"]}>
            From a supplier's shelf to a shopper's door.
          </h2>
          <p class={["mt-4 text-base leading-7 text-[#64736c]"]}>
            Follow one Adinkra tote through the network. Every participant sees only the
            work and information they need.
          </p>
        </div>

        <div class={["mt-14 grid gap-8 lg:grid-cols-[0.82fr_1.18fr] lg:gap-14"]}>
          <div data-reveal="left" class={["lg:sticky lg:top-24 lg:self-start"]}>
            <div class={["overflow-hidden rounded-[2rem] bg-[#10231e] text-white shadow-xl"]}>
              <div class={["relative h-72 overflow-hidden"]}>
                <img
                  src="/images/landing/feature-dropship.jpg"
                  alt="A delivery worker moving a large stack of parcels"
                  loading="lazy"
                  width="600"
                  height="360"
                  class={["h-full w-full object-cover transition duration-700 hover:scale-105"]}
                />
                <div
                  aria-hidden="true"
                  class={[
                    "absolute inset-0 bg-gradient-to-t from-[#10231e] via-[#10231e]/10 to-transparent"
                  ]}
                >
                </div>
                <span class={[
                  "absolute left-5 top-5 inline-flex items-center gap-2 rounded-full bg-white/90 px-3 py-1.5 text-xs font-bold text-[#10231e] shadow"
                ]}>
                  <span class={["h-2 w-2 rounded-full bg-emerald-500"]}></span> Worked example
                </span>
              </div>
              <div class={["p-6 sm:p-8"]}>
                <div class={["flex items-start justify-between gap-4"]}>
                  <div>
                    <p class={["text-xs font-semibold uppercase tracking-[0.16em] text-emerald-300"]}>
                      Adinkra print tote
                    </p>
                    <h3 class={["mt-2 font-headline text-2xl font-bold"]}>Order total</h3>
                  </div>
                  <p class={["font-headline text-3xl font-extrabold text-[#e4bd63]"]}>GH₵85</p>
                </div>
                <dl class={["mt-6 space-y-3 border-t border-white/10 pt-5 text-sm"]}>
                  <div class={["flex items-center justify-between"]}>
                    <dt class={["text-slate-400"]}>Product</dt>
                    <dd class={["font-semibold"]}>GH₵60</dd>
                  </div>
                  <div class={["flex items-center justify-between"]}>
                    <dt class={["text-slate-400"]}>Shop delivery</dt>
                    <dd class={["font-semibold"]}>GH₵15</dd>
                  </div>
                  <div class={["flex items-center justify-between"]}>
                    <dt class={["text-slate-400"]}>Supplier dispatch</dt>
                    <dd class={["font-semibold"]}>GH₵10</dd>
                  </div>
                </dl>
                <div class={["mt-6 flex items-center gap-3 rounded-xl bg-white/5 p-4"]}>
                  <span class={[
                    "inline-flex h-9 w-9 items-center justify-center rounded-lg bg-[#d4a843] text-[#10231e]"
                  ]}>
                    <.icon name="hero-device-phone-mobile" class={["h-5 w-5"]} />
                  </span>
                  <div>
                    <p class={["text-xs text-slate-400"]}>Customer experience</p>
                    <p class={["text-sm font-semibold"]}>One MoMo approval · one receipt</p>
                  </div>
                </div>
              </div>
            </div>
          </div>

          <div class={[
            "relative space-y-4 before:absolute before:bottom-8 before:left-[1.55rem] before:top-8 before:w-px before:bg-[#cfd8d1] sm:before:left-[1.8rem]"
          ]}>
            <%= for {step, index} <- Enum.with_index(@sale_steps) do %>
              <article
                data-sale-step
                data-reveal="right"
                style={"transition-delay: #{index * 70}ms"}
                class={[
                  "group relative flex gap-5 rounded-2xl border border-[#dfe5dc] bg-white p-5 shadow-sm transition-all duration-300 hover:-translate-y-1 hover:border-emerald-200 hover:shadow-lg sm:gap-6 sm:p-6"
                ]}
              >
                <span class={[
                  "relative z-10 inline-flex h-12 w-12 shrink-0 items-center justify-center rounded-2xl bg-[#10231e] text-[#e4bd63] shadow-md transition duration-300 group-hover:bg-emerald-700 group-hover:text-white sm:h-14 sm:w-14"
                ]}>
                  <.icon name={step.icon} class={["h-6 w-6"]} />
                </span>
                <div class={["min-w-0 pt-0.5"]}>
                  <div class={["flex flex-wrap items-center gap-2"]}>
                    <span class={[
                      "text-[10px] font-bold uppercase tracking-[0.18em] text-emerald-700"
                    ]}>
                      {(index + 1) |> Integer.to_string() |> String.pad_leading(2, "0")} · {step.label}
                    </span>
                  </div>
                  <h3 class={["mt-2 text-lg font-bold text-[#10231e]"]}>{step.title}</h3>
                  <p class={["mt-2 text-sm leading-6 text-[#64736c]"]}>{step.copy}</p>
                </div>
              </article>
            <% end %>
          </div>
        </div>
      </div>
    </section>
    """
  end

  defp money_split(assigns) do
    ~H"""
    <section
      id="money-split"
      class={["relative isolate overflow-hidden bg-[#081d18] px-4 py-20 text-white sm:px-6 lg:py-28"]}
    >
      <div
        aria-hidden="true"
        class={["absolute inset-0 -z-10"]}
        style="background: radial-gradient(46rem 30rem at 10% 50%, rgba(16,185,129,0.16), transparent 65%), radial-gradient(38rem 28rem at 92% 10%, rgba(212,168,67,0.12), transparent 65%);"
      >
      </div>
      <div class={["mx-auto max-w-6xl"]}>
        <div data-reveal class={["max-w-2xl"]}>
          <p class={["text-xs font-semibold uppercase tracking-[0.2em] text-emerald-300"]}>
            Automatic settlement
          </p>
          <h2 class={["mt-4 font-headline text-3xl font-bold sm:text-4xl"]}>
            Where every pesewa of GH₵85 goes.
          </h2>
          <p class={["mt-4 text-base leading-7 text-slate-300"]}>
            The shopper approves one payment. Makola preserves the order economics and
            records three exact shares—no invoice, spreadsheet, or Friday promise.
          </p>
        </div>

        <div class={["mt-14 grid items-center gap-10 lg:grid-cols-[0.9fr_1.1fr] lg:gap-16"]}>
          <div
            data-reveal="scale"
            class={["rounded-[2rem] border border-white/10 bg-white/5 p-7 backdrop-blur sm:p-10"]}
          >
            <div class={["mx-auto flex max-w-sm flex-col items-center"]}>
              <div
                class={[
                  "settlement-ring relative grid h-64 w-64 place-items-center rounded-full p-6 shadow-2xl shadow-black/30 sm:h-72 sm:w-72"
                ]}
                style="background: conic-gradient(#34d399 0 56.47%, #e4bd63 56.47% 99.48%, #a78bfa 99.48% 100%);"
                role="img"
                aria-label="GH₵85 split into GH₵48 for the supplier, GH₵36.56 for the shop, and GH₵0.44 for Makola"
              >
                <div class={[
                  "grid h-full w-full place-items-center rounded-full bg-[#0c2620] text-center ring-1 ring-white/10"
                ]}>
                  <div>
                    <p class={["text-xs font-semibold uppercase tracking-[0.16em] text-slate-400"]}>
                      Customer pays
                    </p>
                    <p class={["mt-1 font-headline text-5xl font-extrabold"]}>GH₵85</p>
                    <p class={["mt-1 text-xs text-emerald-300"]}>reconciles exactly</p>
                  </div>
                </div>
              </div>
              <div class={["mt-8 grid w-full grid-cols-3 gap-2 text-center"]}>
                <div>
                  <span class={["mx-auto block h-2 w-2 rounded-full bg-emerald-400"]}></span>
                  <p class={["mt-2 text-xs text-slate-400"]}>Supplier</p>
                  <p class={["text-sm font-bold"]}>56.47%</p>
                </div>
                <div>
                  <span class={["mx-auto block h-2 w-2 rounded-full bg-[#e4bd63]"]}></span>
                  <p class={["mt-2 text-xs text-slate-400"]}>Shop</p>
                  <p class={["text-sm font-bold"]}>43.01%</p>
                </div>
                <div>
                  <span class={["mx-auto block h-2 w-2 rounded-full bg-violet-400"]}></span>
                  <p class={["mt-2 text-xs text-slate-400"]}>Makola</p>
                  <p class={["text-sm font-bold"]}>0.52%</p>
                </div>
              </div>
            </div>
          </div>

          <div data-reveal="right" class={["space-y-4"]}>
            <.payout_card
              icon="hero-cube"
              name="Kumasi Textiles"
              role="Supplier"
              amount="GH₵48"
              detail="GH₵38 wholesale + GH₵10 dispatch"
              width="56.47%"
              tone="bg-emerald-400"
              icon_tone="bg-emerald-400/15 text-emerald-300"
            />
            <.payout_card
              icon="hero-building-storefront"
              name="Adwoa's Boutique"
              role="Shop"
              amount="GH₵36.56"
              detail="GH₵22 margin + GH₵15 delivery − GH₵0.44 fee"
              width="43.01%"
              tone="bg-[#e4bd63]"
              icon_tone="bg-[#e4bd63]/15 text-[#e4bd63]"
            />
            <.payout_card
              icon="hero-squares-plus"
              name="Makola"
              role="Platform"
              amount="GH₵0.44"
              detail="2% of the shop's GH₵22 product margin"
              width="3%"
              tone="bg-violet-400"
              icon_tone="bg-violet-400/15 text-violet-300"
            />
            <div class={[
              "flex items-start gap-3 rounded-2xl border border-emerald-300/20 bg-emerald-300/10 p-5"
            ]}>
              <.icon name="hero-check-badge" class={["mt-0.5 h-5 w-5 shrink-0 text-emerald-300"]} />
              <p class={["text-sm leading-6 text-slate-300"]}>
                <strong class={["text-white"]}>GH₵48 + GH₵36.56 + GH₵0.44 = GH₵85.</strong>
                The ledger balances to the pesewa before settlement is complete.
              </p>
            </div>
          </div>
        </div>
      </div>
    </section>
    """
  end

  attr :icon, :string, required: true
  attr :name, :string, required: true
  attr :role, :string, required: true
  attr :amount, :string, required: true
  attr :detail, :string, required: true
  attr :width, :string, required: true
  attr :tone, :string, required: true
  attr :icon_tone, :string, required: true

  defp payout_card(assigns) do
    ~H"""
    <div class={[
      "rounded-2xl border border-white/10 bg-white/5 p-5 transition duration-300 hover:border-white/20 hover:bg-white/[0.07] sm:p-6"
    ]}>
      <div class={["flex items-center gap-4"]}>
        <span class={[
          "inline-flex h-12 w-12 shrink-0 items-center justify-center rounded-2xl",
          @icon_tone
        ]}>
          <.icon name={@icon} class={["h-6 w-6"]} />
        </span>
        <div class={["min-w-0 flex-1"]}>
          <div class={["flex items-start justify-between gap-3"]}>
            <div>
              <p class={["font-bold text-white"]}>{@name}</p>
              <p class={["text-xs text-slate-400"]}>{@role}</p>
            </div>
            <p class={["font-headline text-2xl font-extrabold text-white"]}>{@amount}</p>
          </div>
          <p class={["mt-3 text-xs leading-5 text-slate-400"]}>{@detail}</p>
          <div class={["mt-3 h-1.5 overflow-hidden rounded-full bg-white/10"]}>
            <div class={["h-full rounded-full", @tone]} style={"width: #{@width}"}></div>
          </div>
        </div>
      </div>
    </div>
    """
  end

  defp stakeholders(assigns) do
    assigns = assign(assigns, :stakeholders, @stakeholders)

    ~H"""
    <section id="stakeholders" class={["bg-white px-4 py-20 sm:px-6 lg:py-28"]}>
      <div class={["mx-auto max-w-6xl"]}>
        <div data-reveal class={["mx-auto max-w-2xl text-center"]}>
          <p class={["text-xs font-semibold uppercase tracking-[0.2em] text-emerald-700"]}>
            Four people, four wins
          </p>
          <h2 class={["mt-4 font-headline text-3xl font-bold text-[#10231e] sm:text-4xl"]}>
            The market only works when everyone benefits.
          </h2>
          <p class={["mt-4 text-base leading-7 text-[#64736c]"]}>
            Makola makes each person's value visible and keeps their responsibilities clear.
          </p>
        </div>

        <div data-reveal class={["stagger-grid mt-14 grid gap-5 sm:grid-cols-2"]}>
          <.stakeholder_card :for={stakeholder <- @stakeholders} stakeholder={stakeholder} />
        </div>
      </div>
    </section>
    """
  end

  attr :stakeholder, :map, required: true

  defp stakeholder_card(assigns) do
    ~H"""
    <article class={[
      "group overflow-hidden rounded-[1.75rem] border border-[#e2e8e3] bg-[#f8faf8] transition duration-300 hover:-translate-y-1.5 hover:shadow-xl"
    ]}>
      <div class={["relative h-48 overflow-hidden"]}>
        <img
          src={@stakeholder.image}
          alt={@stakeholder.alt}
          loading="lazy"
          width="800"
          height="533"
          class={["h-full w-full object-cover transition duration-700 group-hover:scale-105"]}
        />
        <div
          aria-hidden="true"
          class={[
            "absolute inset-0 bg-gradient-to-t from-[#10231e]/75 via-transparent to-transparent"
          ]}
        >
        </div>
        <span class={[
          "absolute bottom-4 left-4 inline-flex h-11 w-11 items-center justify-center rounded-xl shadow-lg",
          @stakeholder.tone
        ]}>
          <.icon name={@stakeholder.icon} class={["h-5 w-5"]} />
        </span>
      </div>
      <div class={["p-6 sm:p-7"]}>
        <h3 class={["font-headline text-2xl font-bold text-[#10231e]"]}>{@stakeholder.role}</h3>
        <p class={["mt-1 text-sm font-medium text-emerald-700"]}>{@stakeholder.subtitle}</p>
        <ul class={["mt-5 space-y-3"]}>
          <li
            :for={bullet <- @stakeholder.bullets}
            class={["flex items-start gap-3 text-sm leading-6 text-[#607068]"]}
          >
            <.icon name="hero-check-circle" class={["mt-1 h-4 w-4 shrink-0 text-emerald-600"]} />
            {bullet}
          </li>
        </ul>
      </div>
    </article>
    """
  end

  defp trust_machinery(assigns) do
    ~H"""
    <section id="trust-machinery" class={["bg-[#f8f6ef] px-4 py-20 sm:px-6 lg:py-28"]}>
      <div class={["mx-auto max-w-6xl"]}>
        <div class={["grid items-start gap-10 lg:grid-cols-[0.85fr_1.15fr] lg:gap-16"]}>
          <div data-reveal="left" class={["lg:sticky lg:top-28"]}>
            <p class={["text-xs font-semibold uppercase tracking-[0.2em] text-emerald-700"]}>
              The defensible layer
            </p>
            <h2 class={[
              "mt-4 font-headline text-3xl font-bold leading-tight text-[#10231e] sm:text-4xl"
            ]}>
              A website builder is easy to copy. Trust machinery is not.
            </h2>
            <p class={["mt-6 text-base leading-7 text-[#64736c]"]}>
              The difficult part is dividing one payment correctly between people who may
              never have met, then keeping fulfillment, refunds, and every later adjustment
              explainable.
            </p>
            <div class={["mt-8 rounded-2xl border-l-4 border-[#d4a843] bg-white p-6 shadow-sm"]}>
              <p class={["font-headline text-xl font-bold leading-8 text-[#10231e]"]}>
                “Makola handles the money so you can handle the selling.”
              </p>
            </div>
          </div>

          <div class={["grid gap-4"]}>
            <.trust_card
              index="01"
              icon="hero-eye"
              title="Transparent before payment"
              copy="Product, delivery, and supplier dispatch charges appear as separate lines before the shopper confirms."
            />
            <.trust_card
              index="02"
              icon="hero-lock-closed"
              title="Protected at settlement"
              copy="Payout readiness and order economics are checked before funds are assigned to recipients."
            />
            <.trust_card
              index="03"
              icon="hero-document-check"
              title="Auditable after the sale"
              copy="Every split, reversal, recovery, fulfillment event, and notification remains tied to the order."
            />
          </div>
        </div>
      </div>
    </section>
    """
  end

  attr :index, :string, required: true
  attr :icon, :string, required: true
  attr :title, :string, required: true
  attr :copy, :string, required: true

  defp trust_card(assigns) do
    ~H"""
    <article
      data-reveal="right"
      class={[
        "group relative overflow-hidden rounded-3xl border border-[#dfe5dc] bg-white p-7 shadow-sm transition duration-300 hover:-translate-y-1 hover:border-emerald-200 hover:shadow-lg sm:p-8"
      ]}
    >
      <span
        aria-hidden="true"
        class={[
          "absolute -right-2 -top-5 font-headline text-8xl font-extrabold text-[#edf1ed] transition-colors duration-300 group-hover:text-emerald-50"
        ]}
      >
        {@index}
      </span>
      <span class={[
        "relative inline-flex h-12 w-12 items-center justify-center rounded-2xl bg-[#10231e] text-[#e4bd63]"
      ]}>
        <.icon name={@icon} class={["h-6 w-6"]} />
      </span>
      <h3 class={["relative mt-5 text-lg font-bold text-[#10231e]"]}>{@title}</h3>
      <p class={["relative mt-2 max-w-xl text-sm leading-6 text-[#64736c]"]}>{@copy}</p>
    </article>
    """
  end

  defp closing_cta(assigns) do
    ~H"""
    <section id="how-it-works-cta" class={["bg-white px-4 py-20 sm:px-6 lg:py-24"]}>
      <div
        data-reveal="scale"
        class={[
          "relative mx-auto max-w-6xl overflow-hidden rounded-[2rem] bg-[#10231e] px-6 py-16 text-center text-white shadow-2xl sm:px-10 lg:py-20"
        ]}
      >
        <div
          aria-hidden="true"
          class={["absolute inset-0 opacity-25"]}
          style="background-image: linear-gradient(90deg, rgba(8,29,24,0.78), rgba(8,29,24,0.9)), url('/images/landing/cta-market.jpg'); background-size: cover; background-position: center;"
        >
        </div>
        <div class={["relative mx-auto max-w-3xl"]}>
          <span class={[
            "inline-flex h-14 w-14 items-center justify-center rounded-2xl bg-[#d4a843] text-[#10231e] shadow-lg"
          ]}>
            <.icon name="hero-sparkles" class={["h-7 w-7"]} />
          </span>
          <h2 class={["mt-6 font-headline text-3xl font-bold leading-tight sm:text-4xl lg:text-5xl"]}>
            Your next product does not have to sit in your room first.
          </h2>
          <p class={["mx-auto mt-5 max-w-2xl text-base leading-7 text-slate-300 sm:text-lg"]}>
            Open your shop, connect to the market, and earn from the first product you
            can confidently sell.
          </p>
          <div class={["mt-8 flex flex-col items-center justify-center gap-3 sm:flex-row"]}>
            <a
              href="/auth/register"
              class={[
                "group inline-flex items-center justify-center gap-2 rounded-xl bg-[#d4a843] px-7 py-3.5 text-sm font-bold text-[#10231e] transition duration-300 hover:-translate-y-0.5 hover:bg-[#e4bd63]"
              ]}
            >
              Start selling — free
              <.icon
                name="hero-arrow-right"
                class={["h-4 w-4 transition-transform duration-300 group-hover:translate-x-1"]}
              />
            </a>
            <a
              href="/pricing"
              class={[
                "inline-flex items-center justify-center rounded-xl border border-white/15 bg-white/5 px-7 py-3.5 text-sm font-semibold text-white transition duration-300 hover:border-white/30 hover:bg-white/10"
              ]}
            >
              See pricing
            </a>
          </div>
          <p class={["mt-5 text-xs text-slate-400"]}>No credit card needed to start.</p>
        </div>
      </div>
    </section>
    """
  end

  @doc """
  The scroll film: a full-viewport scrubbed flight through one Makola sale.

  All behaviour lives in /tour/tour.js + /tour/scrub-engine.js (self-contained
  vanilla JS) — the template is only the mount point, so the film needs no
  LiveView process and no app.js coupling.
  """
  defp tour_scenes do
    [
      {"It starts with a maker.",
       "She lists her goods on Makola one time. That is all she does."},
      {"You stock it in one tap.",
       "No buying stock first. You see your profit before you add it."},
      {"They pay like always.", "One MoMo payment. One receipt. Money people already use."},
      {"It goes straight to them.",
       "The maker gets the order on her phone and sends it to your customer's door."},
      {"The money shares itself.",
       "Everyone's part reaches them by itself. No chasing. No promises."},
      {"Every stall connected.", "Open your shop today. It is free to start."}
    ]
  end

  def tour(assigns) do
    ~H"""
    <!DOCTYPE html>
    <html lang="en">
      <head>
        <meta charset="utf-8" />
        <meta name="viewport" content="width=device-width, initial-scale=1, viewport-fit=cover" />
        <title>{@page_title}</title>
        <meta name="description" content={@meta_description} />
        <link rel="canonical" href={@canonical_url} />
        <meta property="og:type" content="website" />
        <meta property="og:title" content={@page_title} />
        <meta property="og:description" content={@meta_description} />
        <meta property="og:image" content={@og_image} />
        <meta property="og:url" content={@canonical_url} />
        <meta name="theme-color" content="#7b7051" />
        <link rel="icon" href="/favicon.ico" sizes="any" />
        <link rel="icon" href="/favicon.svg" type="image/svg+xml" />
        <link rel="preload" as="image" href="/tour/workshop-m.webp" media="(max-width: 860px)" />
        <link rel="preload" as="image" href="/tour/workshop.webp" media="(min-width: 861px)" />
      </head>
      <body style="margin:0;background:#7b7051">
        <main id="tour-world" style="min-height:100vh">
          <%!-- Semantic fallback: agents and no-JS browsers get the full story;
                tour.js clears this before mounting the film. --%>
          <article style="max-width:640px;margin:0 auto;padding:48px 24px;color:#FAF3E3;font-family:system-ui,sans-serif">
            <h1>How Makola works — one sale, start to finish</h1>
            <p>
              Scroll through one connected sale on Makola, Ghana's connected commerce
              network. Six scenes follow a single tote bag from a maker's hands to
              money in everyone's pocket.
            </p>
            <section :for={{title, body} <- tour_scenes()}>
              <h2>{title}</h2>
              <p>{body}</p>
            </section>
            <p>
              <a href="/auth/register" style="color:#F5B301">Start your shop — free</a>
              · <a href="/stores" style="color:#F5B301">Browse stores</a>
              · <a href="/how-it-works" style="color:#F5B301">Read the full explainer</a>
            </p>
          </article>
        </main>
        <script src="/tour/scrub-engine.js">
        </script>
        <script src="/tour/tour.js">
        </script>
      </body>
    </html>
    """
  end
end
