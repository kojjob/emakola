# Emakola Setup Guide — External Services & Secret Keys

This guide walks you through setting up every external service Emakola needs,
in plain English. Follow it top-to-bottom before your first deploy.

---

## What You Need (Quick Overview)

| Service | What It Does | Required? |
|---------|-------------|-----------|
| **PostgreSQL** | Your database | Yes |
| **Resend** | Sends emails (order confirmations, receipts) | Yes |
| **Paystack** | Accepts payments (cards, mobile money) | Yes |
| **AWS S3** | Stores product images and media | Yes |
| **Fly.io** | Hosts and runs your app | Yes |
| **Hubtel** | Alternative payment gateway (mobile money) | Optional |
| **SMS Gateway** | Sends SMS order notifications | Optional |
| **WhatsApp Business** | Sends WhatsApp order updates | Optional |

---

## Step 1: Database (PostgreSQL)

Fly.io gives you a managed PostgreSQL database.

**How to set up:**

1. Create your Fly app (if you haven't):
   ```bash
   fly apps create emakola
   ```

2. Create a database:
   ```bash
   fly postgres create --name emakola-db
   ```

3. Attach it to your app:
   ```bash
   fly postgres attach emakola-db --app emakola
   ```

4. This automatically sets `DATABASE_URL` as a secret on your app. You're done.

**What it looks like:**
```
DATABASE_URL=postgres://emakola:some-auto-generated-password@emakola-db.internal:5432/emakola
```

You never need to type this yourself — Fly handles it.

---

## Step 2: Secret Key Base (Phoenix Security)

This is a random string Phoenix uses to encrypt cookies and sessions.
Without it, nobody can log in.

**How to set up:**

1. Generate the key:
   ```bash
   mix phx.gen.secret
   ```
   This prints a long random string like `dF5Jz8kL2mN...` (64+ characters).

2. Save it to Fly:
   ```bash
   fly secrets set SECRET_KEY_BASE=paste-the-long-string-here
   ```

**Important:** Never share this key. Never commit it to git. If it leaks,
generate a new one immediately (all existing user sessions will be logged out).

---

## Step 3: Token Signing Secret

Used to sign authentication tokens (login sessions, API tokens).

**How to set up:**

1. Generate another random key:
   ```bash
   mix phx.gen.secret
   ```

2. Save it:
   ```bash
   fly secrets set TOKEN_SIGNING_SECRET=paste-another-long-string-here
   ```

Use a **different** key than SECRET_KEY_BASE.

---

## Step 4: Resend (Email)

Resend sends transactional emails — order confirmations, password resets,
merchant notifications.

**How to set up:**

1. Go to [resend.com](https://resend.com) and create a free account.

2. Verify your domain:
   - Go to **Domains** > **Add Domain**
   - Enter your domain (e.g., `emakola.com`)
   - Resend gives you DNS records to add (MX, TXT, CNAME)
   - Add these records in your domain registrar (Namecheap, Cloudflare, etc.)
   - Wait for verification (usually 5-30 minutes)

3. Get your API key:
   - Go to **API Keys** > **Create API Key**
   - Name it "Emakola Production"
   - Copy the key (starts with `re_`)

4. Save it:
   ```bash
   fly secrets set RESEND_API_KEY=re_your_api_key_here
   ```

**Cost:** Free tier gives you 3,000 emails/month. Paid plans start at $20/month
for 50,000 emails.

---

## Step 5: Paystack (Payments)

Paystack processes payments — credit cards, debit cards, MTN MoMo,
Telecel Cash, and other mobile money providers in Ghana.

**How to set up:**

1. Go to [paystack.com](https://paystack.com) and create a business account.

2. Complete business verification:
   - Upload business registration documents
   - Add bank account for settlements
   - Paystack reviews this (takes 1-3 business days)

3. While waiting, use **test mode** to build and test:
   - Go to **Settings** > **API Keys & Webhooks**
   - You'll see both **Test** and **Live** keys

4. Get your keys:
   - **Secret Key** (starts with `sk_test_` or `sk_live_`) — this is private, never expose it
   - **Public Key** (starts with `pk_test_` or `pk_live_`) — this goes in your frontend

5. Set up webhooks:
   - In Paystack dashboard, go to **Settings** > **API Keys & Webhooks**
   - Set webhook URL to: `https://your-domain.com/webhooks/paystack`
   - Paystack will send payment confirmations to this URL

6. Save your keys:
   ```bash
   # Use test keys first, switch to live after testing
   fly secrets set PAYSTACK_SECRET_KEY=sk_live_your_secret_key
   fly secrets set PAYSTACK_PUBLIC_KEY=pk_live_your_public_key
   ```

**Cost:** Paystack charges 1.5% + GHS 0.01 per local transaction (Ghana).
No monthly fees.

**Testing:** Use test card number `4084 0840 8408 4081`, any future expiry,
and any 3-digit CVV.

---

## Step 6: AWS S3 (Image Storage)

S3 stores all product images, media uploads, and files. Without it,
merchant product photos won't persist between deploys.

**How to set up:**

1. Go to [aws.amazon.com](https://aws.amazon.com) and create an account
   (or use DigitalOcean Spaces — it's S3-compatible and simpler).

2. Create an S3 bucket:
   - Go to **S3** > **Create Bucket**
   - Bucket name: `emakola-uploads` (or your preferred name)
   - Region: `eu-west-1` (Ireland) or the region closest to your users
   - **Uncheck** "Block all public access" (product images need to be public)
   - Click **Create**

3. Set the bucket policy (allows public read access for images):
   - Click your bucket > **Permissions** > **Bucket Policy**
   - Paste this policy (replace `emakola-uploads` with your bucket name):
   ```json
   {
     "Version": "2012-10-17",
     "Statement": [
       {
         "Sid": "PublicReadGetObject",
         "Effect": "Allow",
         "Principal": "*",
         "Action": "s3:GetObject",
         "Resource": "arn:aws:s3:::emakola-uploads/*"
       }
     ]
   }
   ```

4. Create an IAM user for your app:
   - Go to **IAM** > **Users** > **Create User**
   - Name: `emakola-app`
   - Attach policy: **AmazonS3FullAccess** (or create a custom policy for just your bucket)
   - Go to **Security Credentials** > **Create Access Key**
   - Choose "Application running outside AWS"
   - Copy the **Access Key ID** and **Secret Access Key**

5. Save everything:
   ```bash
   fly secrets set AWS_ACCESS_KEY_ID=AKIA...your-access-key
   fly secrets set AWS_SECRET_ACCESS_KEY=your-secret-key
   fly secrets set AWS_S3_BUCKET=emakola-uploads
   fly secrets set AWS_S3_REGION=eu-west-1
   ```

**Cost:** S3 costs about $0.023/GB/month for storage + $0.09/GB for data transfer.
For a small store with 1,000 product images, expect less than $1/month.

**Alternative — DigitalOcean Spaces:**
Simpler to set up, S3-compatible, $5/month for 250GB.
Use the same env vars but configure ExAws to point to DO Spaces endpoint.

---

## Step 7: Fly.io (Hosting)

**How to set up:**

1. Install the Fly CLI:
   ```bash
   curl -L https://fly.io/install.sh | sh
   ```

2. Log in:
   ```bash
   fly auth login
   ```

3. Set your app's hostname:
   ```bash
   fly secrets set PHX_HOST=your-domain.com
   ```

4. Deploy:
   ```bash
   fly deploy
   ```

Fly automatically runs database migrations on each deploy (configured in `fly.toml`).

**Cost:** ~$5-15/month for a small app (1 shared CPU, 256MB RAM).
Scale up as traffic grows.

---

## Step 8: Hubtel (Optional — Alternative Payments)

Hubtel is another mobile money gateway popular in Ghana. You only need this
if you want to offer Hubtel as a payment option alongside Paystack.

**How to set up:**

1. Go to [hubtel.com](https://hubtel.com) and create a merchant account.

2. Get API credentials:
   - Go to your developer dashboard
   - Copy **Client ID** and **Client Secret**

3. Get webhook IP allowlist:
   - Contact Hubtel support and ask for the list of IP addresses
     their webhook servers use
   - This is important — Emakola blocks webhook requests from unknown IPs

4. Save everything:
   ```bash
   fly secrets set HUBTEL_CLIENT_ID=your-client-id
   fly secrets set HUBTEL_CLIENT_SECRET=your-client-secret
   fly secrets set HUBTEL_WEBHOOK_ALLOWLIST="203.0.113.5,203.0.113.10"
   ```
   (Replace the IPs with the actual ones Hubtel gives you)

**If you skip Hubtel:** No problem. Paystack handles all the same payment
methods. Hubtel is just an alternative.

---

## Step 9: SMS Notifications (Optional)

Sends SMS order confirmations and shipping updates to customers.

**How to set up (using any SMS gateway like Arkesel, Mnotify, or Twilio):**

1. Sign up with your preferred SMS provider.

2. Get your API key from their dashboard.

3. Save it:
   ```bash
   fly secrets set SMS_API_KEY=your-sms-api-key
   fly secrets set SMS_SENDER_ID=Emakola
   ```

   The sender ID is what customers see as the "from" name on the SMS
   (e.g., "Emakola" instead of a random phone number).

**If you skip SMS:** Order confirmations will only go via email and WhatsApp
(if configured). Customers won't get text messages.

---

## Step 10: WhatsApp Business (Optional)

Sends order updates via WhatsApp — very popular in Ghana since most
customers prefer WhatsApp over email.

**How to set up:**

1. Go to [developers.facebook.com](https://developers.facebook.com)
   and create a Meta developer account.

2. Create a new app:
   - Choose **Business** type
   - Add the **WhatsApp** product

3. Set up a WhatsApp Business phone number:
   - Go to **WhatsApp** > **Getting Started**
   - Add a phone number (or use the test number provided)
   - Meta verifies your business (takes 1-5 days)

4. Generate a permanent access token:
   - Go to **System Users** > **Generate Token**
   - Select your WhatsApp app
   - Copy the token

5. Get your Phone Number ID:
   - Go to **WhatsApp** > **Getting Started**
   - Your Phone Number ID is displayed under your registered number

6. Create message templates:
   - Go to **WhatsApp** > **Message Templates**
   - Create templates for: order confirmation, shipping update, delivery notification
   - Meta reviews each template (takes 1-24 hours)

7. Save everything:
   ```bash
   fly secrets set WHATSAPP_API_TOKEN=your-permanent-token
   fly secrets set WHATSAPP_PHONE_NUMBER_ID=123456789012345
   ```

**Cost:** WhatsApp Business API charges per conversation:
- Business-initiated: ~$0.05 per conversation (Ghana)
- User-initiated: ~$0.02 per conversation
- First 1,000 conversations/month are free

**If you skip WhatsApp:** Customers can still use the "Ask on WhatsApp" link
on product pages (it opens their WhatsApp app). They just won't get
automated order updates via WhatsApp.

---

## Quick Deploy Checklist

Copy this and check off each item before deploying:

```
REQUIRED (app won't work without these):
[ ] DATABASE_URL          — auto-set by fly postgres attach
[ ] SECRET_KEY_BASE       — mix phx.gen.secret
[ ] TOKEN_SIGNING_SECRET  — mix phx.gen.secret (different from above)
[ ] RESEND_API_KEY        — from resend.com dashboard
[ ] PAYSTACK_SECRET_KEY   — from paystack.com dashboard
[ ] PAYSTACK_PUBLIC_KEY   — from paystack.com dashboard
[ ] AWS_S3_BUCKET         — your S3 bucket name
[ ] AWS_S3_REGION         — your S3 region (e.g., eu-west-1)
[ ] AWS_ACCESS_KEY_ID     — from AWS IAM
[ ] AWS_SECRET_ACCESS_KEY — from AWS IAM
[ ] PHX_HOST              — your domain (e.g., emakola.com)

AUTO-SET BY FLY (already in fly.toml):
[x] PHX_SERVER=true
[x] ECTO_IPV6=true
[x] POOL_SIZE=10

OPTIONAL (add when ready):
[ ] HUBTEL_CLIENT_ID
[ ] HUBTEL_CLIENT_SECRET
[ ] HUBTEL_WEBHOOK_ALLOWLIST
[ ] SMS_API_KEY
[ ] SMS_SENDER_ID
[ ] WHATSAPP_API_TOKEN
[ ] WHATSAPP_PHONE_NUMBER_ID
```

---

## How to Set Secrets on Fly.io

Set one at a time:
```bash
fly secrets set PAYSTACK_SECRET_KEY=sk_live_abc123
```

Set multiple at once:
```bash
fly secrets set \
  PAYSTACK_SECRET_KEY=sk_live_abc123 \
  PAYSTACK_PUBLIC_KEY=pk_live_xyz789 \
  RESEND_API_KEY=re_abc123
```

View which secrets are set (values are hidden):
```bash
fly secrets list
```

Remove a secret:
```bash
fly secrets unset OLD_SECRET_NAME
```

**Never put secrets in your code, .env files committed to git, or fly.toml.**
Always use `fly secrets set`.

---

## Troubleshooting

**"environment variable X is missing" on deploy:**
You forgot to set a required secret. Run `fly secrets list` to check,
then `fly secrets set X=value` to fix it.

**Emails not sending:**
Check your Resend domain verification. Go to resend.com > Domains and
make sure it shows "Verified".

**Payments failing:**
Make sure you're using **live** keys, not test keys. Test keys start with
`sk_test_` — live keys start with `sk_live_`.

**Product images not uploading:**
Check your S3 bucket permissions. The bucket policy must allow public read.
Also verify AWS_ACCESS_KEY_ID and AWS_SECRET_ACCESS_KEY are set correctly.

**WhatsApp messages not sending:**
Your message templates might not be approved yet. Check the Meta developer
dashboard for template status.

**SMS not sending:**
Verify your SMS API key is valid and your account has credit/balance.

---

## Local Development

For local development, you don't need any of these services.
The app uses safe defaults:

- **Database:** Local PostgreSQL (`emakola_dev`)
- **Storage:** Local filesystem (saves to `priv/static/uploads/`)
- **Email:** Logged to console (no real emails sent)
- **Payments:** Mock gateway that always succeeds
- **SMS/WhatsApp:** Mocked in tests, disabled in dev

Just run:
```bash
mix setup    # creates DB, runs migrations, seeds test data
mix phx.server  # starts the app at localhost:4000
```

Test merchant accounts (from seed data):
- `kwame@kentekingdom.com` / `Password123!`
- `adjoa@accrafresh.com` / `Password123!`
