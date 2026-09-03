# Makola.io email templates — canvas sources

Working files behind the "Makola.io Email Templates" canvas. Same rules as
`design/brand-kit/`: every fact in `[BRACKETS]`, no fee percentage, no merchant
counts, picture first, system fonts.

- `Main.dc.html` — A, picture first (chosen). Implemented as
  `Emakola.Notifications.Emails.MarketingEmail.picture_first/1`.
- `NewsletterUpdate.dc.html` — D, newsletter and updates. Implemented as
  `MarketingEmail.update/1`; platform announcements send through it.
- `Letterhead.dc.html` — copy of the brand-kit letterhead so the written set
  sits together. Export PDF from the canvas toolbar.
- `FoundingSellerLetter.dc.html`, `CampaignPush.dc.html` — B and C, not chosen,
  kept for reference.
- `*.jpg` — downsampled copies of `priv/static/images/landing/` photos.
