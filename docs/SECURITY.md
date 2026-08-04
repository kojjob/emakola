# Emakola Security Policy

Version: 1.1
Last Updated: 2026-08-04
Classification: Internal

---

## Overview

Emakola is a multi-tenant ecommerce SaaS platform handling merchant financial data, customer PII, and payment transactions across West Africa (Ghana, Nigeria). This document defines the security controls, policies, and procedures that protect our platform, merchants, and their customers.

**Core principle**: Defense in depth. No single control is sufficient; we layer security at every level.

---

## 1. Authentication & Authorization

### 1.1 Merchant Authentication

- **Method**: Email + password via Ash Authentication
- **Password hashing**: bcrypt with cost factor 12 (via `Bcrypt` library)
- **Password policy**:
  - Minimum 8 characters
  - Must contain at least one uppercase, one lowercase, and one digit
  - Checked against common password lists (top 10,000)
  - No maximum length (bcrypt truncates at 72 bytes; we enforce this as the practical max)
- **Multi-factor authentication**: TOTP-based MFA available for merchant accounts (recommended for store owners)
- **Session management**:
  - Phoenix sessions with secure, HTTP-only, SameSite=Lax cookies
  - Session timeout: 24 hours idle, 7 days absolute
  - Session invalidation on password change
  - Single active session per device (configurable)

### 1.2 Customer Authentication

- **Methods**:
  - Email + password (standard registration)
  - Phone number + OTP (SMS-based, common in West Africa)
  - Guest checkout (no account required, order tracked by email/phone)
- **OTP policy**:
  - 6-digit numeric code
  - Expires after 5 minutes
  - Maximum 3 verification attempts per code
  - Rate limited: 3 OTP requests per phone number per 15 minutes

### 1.3 Rate Limiting

| Endpoint Category | Limit | Window | Action on Exceed |
|---|---|---|---|
| Login attempts | 5 | 15 minutes | Lock account, require CAPTCHA |
| OTP requests | 3 | 15 minutes | Temporary block |
| API requests (authenticated) | 100 | 1 minute | 429 Too Many Requests |
| API requests (unauthenticated) | 30 | 1 minute | 429 Too Many Requests |
| Checkout/payment | 10 | 1 minute | 429 + alert |
| Password reset | 3 | 1 hour | Silent drop |
| Account creation | 5 | 1 hour | 429 + CAPTCHA |

Implementation: `Hammer` library with ETS-backed storage, upgradeable to Redis for multi-node deployments.

### 1.4 CSRF Protection

- Phoenix built-in CSRF tokens on all state-changing requests
- LiveView CSRF tokens validated on mount and form submission
- API endpoints use token-based auth (no cookies) and are exempt from CSRF

### 1.5 Authorization

- **Ash authorization policies** enforce resource-level access control
- Every Ash action has explicit `authorize :always` or policy definitions
- No implicit allow; default deny on all resources
- Merchant roles: `owner`, `manager`, `staff` with granular permissions
- Customer authorization scoped to their own data only

---

## 2. Data Protection

### 2.1 Encryption at Rest

- **PostgreSQL**: Deployed on Fly.io with encrypted volumes (AES-256)
- **Backups**: Encrypted using Fly.io managed backup encryption
- **Application-level encryption rollout**: TOTP seeds, outbound-webhook signing
  secrets, and FCM device tokens have versioned AES-256-GCM shadow columns.
  New writes update both the legacy and encrypted columns, reads prefer the
  authenticated ciphertext, and the expand migration backfills existing rows.
  Authenticated stale shadows caused by an old node are temporarily resolved
  through the compatibility column and repaired by a post-rollout reconcile.
  Device-token equality migration is prepared with a separate keyed-HMAC blind
  index. The legacy plaintext columns are intentionally retained until the
  rolling-deploy contract release; see `docs/ENCRYPTION_AT_REST.md` for the
  exact coverage, residual fields, verification, and rotation runbook.
 - **Key management**: Encryption and blind-index keyrings use independent
   32-byte keys from production runtime secrets. Envelopes include a key id so
   old and new encryption keys can overlap during rotation.

### 2.2 Encryption in Transit

- **TLS 1.3** enforced on all external connections
- `force_ssl: true` in Phoenix endpoint configuration
- HSTS header with `max-age=63072000` (2 years), `includeSubDomains`
- Database connections use SSL with certificate verification
- Internal service communication over Fly.io private network (WireGuard encrypted)

### 2.3 PII Handling

- **Logging**: Notification and authentication sender paths use
  `Emakola.Privacy`; new log statements must not serialise request/provider
  payloads or message bodies.
  - Phone numbers: `+233****4567` (show final 4 digits)
  - Email addresses: `k***@example.com`
- **Never log** raw message bodies, provider responses, credentials, tokens, or
  authentication codes.
- **Log storage**: Structured JSON logs, retained for 90 days, then purged
- **Database**: Persisted PII and credentials are inventoried in
  [`SENSITIVE_DATA_INVENTORY.md`](SENSITIVE_DATA_INVENTORY.md)
- **Access**: PII access restricted to authorized personnel with audit trail

### 2.4 Password Security

- Passwords hashed with bcrypt (cost factor 12)
- Passwords never logged, never stored in plaintext, never transmitted in query strings
- Password reset tokens: single-use, expire in 1 hour, cryptographically random (128-bit)
- Old password required for password change (except reset flow)

### 2.5 Sensitive Data Handling

- **Payment card data**: Never touches our servers. All card data handled by Paystack/Flutterwave via their hosted payment pages or tokenized client-side SDKs
- **Payment tokens**: We store only gateway transaction references (e.g., Paystack `reference` strings)
- **Mobile money PINs**: Never collected by our platform; handled entirely by USSD/provider
- **API/provider keys**: Runtime provider credentials are injected by the
  production secret manager and are not persisted in application tables.
- **Merchant bank details**: Application-level encryption is not yet complete
  for every payout and supplier field. The remaining columns are enumerated in
  `docs/ENCRYPTION_AT_REST.md`; encrypted database volumes remain the current
  at-rest control for those residuals.

---

## 3. Multi-Tenant Security

### 3.1 Tenant Isolation

- **Ash multitenancy** with PostgreSQL schemas (one schema per store)
- Every database query is scoped to the current tenant automatically by Ash
- No shared tables for tenant-specific data
- Shared tables (e.g., platform admin data) are in the `public` schema with explicit access controls

### 3.2 Tenant Context Verification

- Tenant context (`store_id` / schema) set at the beginning of every request via a Phoenix plug
- Tenant determined from subdomain (`{store}.emakola.com`) or custom domain
- LiveView sockets include tenant context, validated on mount
- Background jobs (Oban) carry tenant context in job args, set before execution

### 3.3 Cross-Tenant Protection

- No API endpoint allows querying across tenants (except platform admin with explicit authorization)
- Ash policies enforce tenant boundaries at the resource level
- Integration tests verify: Store A data is never visible to Store B
- Foreign key constraints prevent referencing resources across tenant schemas

### 3.4 Admin Access

- Platform admin actions require separate admin authentication
- Store management actions require verified store ownership
- All admin actions are audit-logged with actor, action, target, and timestamp
- Principle of least privilege: staff accounts get minimal necessary permissions

---

## 4. Payment Security

### 4.1 PCI DSS Compliance

- **Compliance scope**: SAQ-A (we never handle card data directly)
- Card data is collected and processed entirely by Paystack/Flutterwave
- Our servers never receive, process, store, or transmit cardholder data
- Payment pages embedded via provider SDKs or redirect to hosted payment pages

### 4.2 Webhook Security

- **Signature verification**: Every incoming webhook from Paystack/Flutterwave is verified using HMAC-SHA512 with our secret key
- Webhooks that fail signature verification are rejected with 401 and logged as security events
- Webhook endpoints are rate-limited and only accept POST requests
- IP allowlisting for payment provider webhook sources (where provider publishes IP ranges)

### 4.3 Payment Integrity

- **Idempotency keys**: Every payment initiation includes a unique idempotency key to prevent duplicate charges
- **Server-side amount verification**: Order total is always calculated server-side from current product prices; the client-submitted amount is never trusted
- **Currency verification**: Payment currency must match the store's configured currency
- **Status reconciliation**: Cron job (Oban) reconciles pending payments with gateway status every 15 minutes
- **Refund authorization**: Refunds require merchant approval and are processed through the gateway API (never manual)

### 4.4 Mobile Money

- Mobile money transactions are asynchronous; we poll for completion or receive webhooks
- Phone number format validated before submission (Ghana: `+233`, Nigeria: `+234`)
- Transaction status cached to prevent repeated gateway calls
- Timeout handling: transactions pending >30 minutes are flagged for manual review

---

## 5. Infrastructure Security

### 5.1 Hosting

- **Platform**: Fly.io with private networking
- **Regions**: Primary in `lhr` (London) or `jnb` (Johannesburg) for West Africa latency
- **Network**: All internal communication over Fly.io private WireGuard mesh
- **Database**: Fly Postgres, no public IP, accessible only via private network
- **Load balancing**: Fly.io Anycast with automatic TLS termination

### 5.2 Secrets Management

- All secrets stored in Fly.io encrypted secrets store
- Secrets injected as environment variables at runtime
- Secret rotation procedure documented and tested quarterly
- Secrets never committed to source control (`.gitignore` enforced, pre-commit hook checks)
- Runtime config (`runtime.exs`) reads from environment variables only

### 5.3 Dependency Security

- `mix audit` run on every CI build to check for known vulnerabilities in Hex packages
- Dependabot / Renovate configured for automated dependency update PRs
- Dependencies pinned to exact versions in `mix.lock`
- New dependencies require security review before adoption

### 5.4 Static Analysis

- **Sobelow**: Run on every CI build for Elixir-specific security analysis
  - Detects: SQL injection, XSS, directory traversal, unsafe deserialization, hardcoded secrets
  - Configuration: strict mode, no false-positive suppressions without documented justification
- **Credo**: Static analysis for code quality and consistency

### 5.5 Container Security

- Minimal Docker images based on official Elixir release images
- No SSH access to production containers
- Read-only filesystem where possible
- Non-root user for application process

---

## 6. OWASP Top 10 Mitigations

### A01:2021 — Broken Access Control

| Threat | Mitigation |
|---|---|
| Unauthorized tenant access | Ash multitenancy with schema isolation; tenant context verified on every request |
| Privilege escalation | Ash authorization policies with explicit deny-by-default |
| IDOR (Insecure Direct Object Reference) | All resource access goes through Ash actions with policy checks; no raw ID lookups |
| Missing function-level access control | Every Ash action requires `authorize :always` or explicit policy |

### A02:2021 — Cryptographic Failures

| Threat | Mitigation |
|---|---|
| Weak password hashing | bcrypt with cost factor 12 |
| Data in transit | TLS 1.3 enforced, HSTS enabled |
| Sensitive data at rest | Versioned AES-256-GCM rollout for TOTP/webhook/device secrets; encrypted volumes plus a tracked contract plan for residual fields |
| Exposed secrets | Fly.io secrets store, never in code |

### A03:2021 — Injection

| Threat | Mitigation |
|---|---|
| SQL injection | Ecto parameterized queries (never raw SQL interpolation) |
| NoSQL injection | Not applicable (PostgreSQL only) |
| Command injection | No `System.cmd` with user input; Elixir does not shell-expand by default |
| Input validation | Ash changesets with type casting and validation; Ecto types enforce schema |

### A04:2021 — Insecure Design

| Threat | Mitigation |
|---|---|
| Missing rate limiting | Hammer rate limiter on auth, API, payment, and registration endpoints |
| Business logic flaws | Domain-driven design with explicit Ash actions; no implicit state changes |
| Insufficient testing | TDD with 90%+ coverage; dedicated security test suite |

### A05:2021 — Security Misconfiguration

| Threat | Mitigation |
|---|---|
| Debug mode in production | `config/runtime.exs` disables debug; `MIX_ENV=prod` enforced |
| Default credentials | No default accounts; admin setup requires explicit initialization |
| Missing security headers | Comprehensive security headers (see Section 8) |
| CORS misconfiguration | Explicit origin allowlist; no wildcard `*` in production |
| Verbose error messages | Phoenix error views return generic messages in production; detailed errors only in dev |

### A06:2021 — Vulnerable and Outdated Components

| Threat | Mitigation |
|---|---|
| Known vulnerabilities | `mix audit` in CI; Dependabot for automated updates |
| Outdated dependencies | Monthly dependency review; automated update PRs |
| Unmaintained packages | Periodic review of dependency health and alternatives |

### A07:2021 — Identification and Authentication Failures

| Threat | Mitigation |
|---|---|
| Credential stuffing | Rate limiting (5 attempts/15 min), account lockout |
| Weak passwords | Password policy enforcement (min 8 chars, complexity) |
| Session fixation | Phoenix generates new session on login |
| Missing MFA | TOTP MFA available for merchant accounts |

### A08:2021 — Software and Data Integrity Failures

| Threat | Mitigation |
|---|---|
| Unsigned webhooks | HMAC-SHA512 signature verification on all payment webhooks |
| Tampered dependencies | `mix.lock` integrity; CI verifies lock file consistency |
| CI/CD pipeline attacks | Branch protection rules; required reviews; signed commits encouraged |

### A09:2021 — Security Logging and Monitoring Failures

| Threat | Mitigation |
|---|---|
| Insufficient logging | Structured JSON logging with `Logger` and metadata |
| Missing audit trail | All admin actions, payment events, and auth events logged with actor + timestamp |
| No alerting | Monitoring alerts on failed auth spikes, payment anomalies, error rate increases |
| Log injection | Logger metadata sanitized; no user input in log format strings |

### A10:2021 — Server-Side Request Forgery (SSRF)

| Threat | Mitigation |
|---|---|
| SSRF via webhook URLs | Merchant webhook URLs validated against allowlist of schemes (https only) and blocked private IP ranges |
| Internal service access | No user-controlled URLs used for internal requests |
| DNS rebinding | URL resolution validated at request time |

---

## 7. Incident Response

### 7.1 Incident Classification

| Severity | Description | Response Time | Example |
|---|---|---|---|
| P1 — Critical | Active data breach, payment compromise | 15 minutes | Unauthorized access to customer PII |
| P2 — High | Vulnerability with exploit potential | 1 hour | SQL injection discovered, auth bypass |
| P3 — Medium | Security weakness, no active exploit | 24 hours | Missing rate limiting on endpoint |
| P4 — Low | Best practice deviation | 1 week | Outdated dependency with low-risk CVE |

### 7.2 Response Procedures

1. **Detection**: Automated monitoring alerts, manual report, or third-party disclosure
2. **Triage**: Classify severity, assign incident commander
3. **Containment**:
   - P1: Immediately isolate affected systems (kill sessions, rotate secrets, block IPs)
   - P2: Apply hotfix or disable affected feature
4. **Investigation**: Determine scope, root cause, and affected data/users
5. **Remediation**: Fix vulnerability, deploy patch, verify fix
6. **Communication**:
   - Affected merchants notified within 24 hours (P1) or 72 hours (P2)
   - Ghana Data Protection Commission notified within 72 hours for data breaches (per DPA 2012)
   - Nigeria Data Protection Commission notified per NDPA 2023 requirements
7. **Post-Incident Review**: Conducted within 5 business days; findings documented and tracked

### 7.3 Notification Requirements

- **Ghana Data Protection Act (2012)**: Data breaches involving personal data must be reported to the Data Protection Commission
- **Nigeria NDPA (2023)**: Breaches reported to the Nigeria Data Protection Commission within 72 hours
- **Affected users**: Notified without undue delay when breach poses risk to their rights
- **Merchants**: Notified of any breach affecting their store or customer data

### 7.4 Post-Incident Review

- Root cause analysis document
- Timeline of events
- What worked, what did not
- Action items with owners and deadlines
- Update to security controls if needed
- Shared with team (anonymized if needed for external sharing)

---

## 8. Security Headers

Applied via a Phoenix plug on all responses:

```elixir
defmodule EmakolaWeb.Plugs.SecurityHeaders do
  @moduledoc "Sets security headers on all responses."

  import Plug.Conn

  def init(opts), do: opts

  def call(conn, _opts) do
    conn
    |> put_resp_header("content-security-policy",
      "default-src 'self'; " <>
      "script-src 'self' 'nonce-#{get_csp_nonce(conn)}' https://js.paystack.co; " <>
      "style-src 'self' 'unsafe-inline'; " <>
      "img-src 'self' data: https:; " <>
      "font-src 'self'; " <>
      "connect-src 'self' https://api.paystack.co wss:; " <>
      "frame-src https://checkout.paystack.com; " <>
      "object-src 'none'; " <>
      "base-uri 'self'"
    )
    |> put_resp_header("x-frame-options", "DENY")
    |> put_resp_header("x-content-type-options", "nosniff")
    |> put_resp_header("x-xss-protection", "0")
    |> put_resp_header("referrer-policy", "strict-origin-when-cross-origin")
    |> put_resp_header("strict-transport-security",
      "max-age=63072000; includeSubDomains; preload"
    )
    |> put_resp_header("permissions-policy",
      "camera=(), microphone=(), geolocation=(), payment=(self)"
    )
    |> put_resp_header("x-permitted-cross-domain-policies", "none")
  end

  defp get_csp_nonce(conn) do
    conn.assigns[:csp_nonce] || ""
  end
end
```

---

## 9. Security Checklist for Development

Before merging any PR:

- [ ] No secrets or credentials in code (checked by Sobelow + pre-commit hook)
- [ ] All new Ash actions have authorization policies
- [ ] User input is validated through Ash changesets or Ecto types
- [ ] No raw SQL interpolation (Ecto parameterized queries only)
- [ ] PII is masked in any new log statements
- [ ] New endpoints have appropriate rate limiting
- [ ] Payment-related changes have integration tests with mocked gateways
- [ ] Multi-tenant isolation verified (test that tenant A cannot access tenant B data)
- [ ] Security headers not weakened or removed
- [ ] `mix audit` and `mix sobelow` pass cleanly

---

## 10. Security Review Schedule

| Activity | Frequency | Owner |
|---|---|---|
| Dependency audit (`mix audit`) | Every CI build | Automated |
| Static analysis (Sobelow) | Every CI build | Automated |
| Penetration testing | Annually | External firm |
| Security policy review | Quarterly | Engineering lead |
| Secret rotation | Quarterly | DevOps |
| Access review | Quarterly | Engineering lead |
| Incident response drill | Bi-annually | Full team |

---

## Contact

- **Security issues**: security@emakola.com
- **Data protection inquiries**: dpo@emakola.com
- **Responsible disclosure**: See `/.well-known/security.txt` on our domain
