import Config

# White-label branding configuration
# Override these values to customize the app for different brands
config :emakola, :branding,
  app_name: "Makola",
  tagline: "Commerce for West Africa",
  company_name: "Makola Inc.",
  support_email: "support@makola.io",
  marketing_url: "https://emakola.com",
  logo_path: "/images/logo.svg",
  favicon_path: "/images/favicon.ico",
  primary_color: "#0c1526",
  accent_color: "#d4a843",
  # Social links
  twitter_url: nil,
  github_url: nil,
  discord_url: nil,
  # Feature flags (branding-level)
  show_powered_by: true,
  custom_domain_support: false
