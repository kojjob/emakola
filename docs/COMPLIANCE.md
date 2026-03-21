# Emakola — Regulatory Compliance

## Ghana Data Protection Act (2012, Act 843)

### Requirements
- **Registration**: Register with Ghana Data Protection Commission as a data controller
- **Consent**: Obtain explicit consent before collecting personal data
- **Purpose Limitation**: Only collect data necessary for the stated purpose
- **Data Subject Rights**: Access, rectification, erasure, objection
- **Cross-Border Transfer**: Requires adequate protection in destination country
- **Breach Notification**: Notify Commission within 72 hours of a breach
- **Data Retention**: Define and enforce retention periods

### Our Implementation
| Requirement | How We Comply |
|-------------|---------------|
| Consent | Checkbox at signup + checkout. Records timestamp of consent |
| Purpose limitation | Privacy policy lists all data uses. No selling/sharing PII |
| Access rights | Account page shows all stored data. Export to CSV on request |
| Erasure | "Delete my account" feature. Cascading delete with 30-day grace |
| Breach notification | Incident response plan with 72-hour notification workflow |
| Retention | Orders: 7 years (tax). Inactive accounts: delete after 2 years |

## Nigeria Data Protection Act (NDPA 2023)

### Additional Requirements (Phase 3)
- **Nigeria Data Protection Commission (NDPC)** registration
- **Data Protection Impact Assessment** for high-risk processing
- **Lawful basis** documentation for each processing activity
- **Consent** must be freely given, specific, informed, unambiguous
- **Cross-border transfers** require adequacy decision or safeguards
- **Record of processing activities** maintained

## Payment Regulations

### Bank of Ghana (BoG)
- Mobile money operators are regulated by BoG
- We process payments through licensed payment service providers (Paystack, Hubtel)
- We do NOT hold customer funds — gateway handles settlement
- Transaction records maintained for 7 years per BoG requirements

### Central Bank of Nigeria (CBN) — Phase 3
- Payment processing through CBN-licensed providers (Paystack, Flutterwave)
- KYC requirements for merchant verification
- Transaction monitoring for anti-money laundering

### Merchant KYC
| Tier | Requirements | Limits |
|------|-------------|--------|
| Basic | Email, phone verification | GH₵ 5,000/month |
| Standard | + Government ID, business name | GH₵ 50,000/month |
| Verified | + Business registration, bank account | Unlimited |

## Tax Compliance

### Ghana
- **VAT**: 15% (standard rate as of 2024)
- **NHIL**: 2.5% (National Health Insurance Levy)
- **GETFund**: 2.5% (Ghana Education Trust Fund Levy)
- **COVID Levy**: 1% (Health Recovery Levy)
- **Flat Rate VAT**: 4% for retailers (simplified scheme)
- **Implementation**: Merchants configure their own tax settings. Platform provides Ghana tax presets.

### Nigeria (Phase 3)
- **VAT**: 7.5%
- **Implementation**: Similar merchant-configured tax settings with Nigerian presets

## Consumer Protection

### Ghana Consumer Protection Agency (Act 2017)
- Right to return defective goods within 7 days
- Transparent pricing (all fees visible before purchase)
- Clear refund policy displayed on storefront
- Accurate product descriptions (merchants responsible)
- Dispute resolution mechanism

### Platform Implementation
- Mandatory refund policy display on checkout
- Dispute resolution flow (customer → merchant → Emakola mediation)
- Merchant content moderation (prohibited products list)
- Price transparency (shipping + tax shown before payment)

## Prohibited Products
Merchants may NOT sell:
- Counterfeit goods
- Weapons or ammunition
- Controlled substances
- Stolen property
- Products violating intellectual property rights
- Age-restricted products without verification
- Products sanctioned by Ghana FDA / NAFDAC (Nigeria)

## Privacy Policy Requirements
Our privacy policy must include:
1. Identity of data controller (Emakola Inc.)
2. Contact details (DPO email, physical address)
3. What personal data we collect and why
4. Legal basis for each processing activity
5. Who we share data with (payment processors, logistics, SMS providers)
6. Data retention periods
7. Data subject rights and how to exercise them
8. Cookie usage and consent
9. Security measures in place
10. How to file a complaint with the Data Protection Commission

## Terms of Service Requirements
### Merchant Agreement
- Service description and pricing
- Payment terms and fee structure
- Merchant obligations (accurate listings, timely fulfillment)
- Platform obligations (uptime SLA, data protection)
- Intellectual property rights
- Liability limitations
- Termination conditions
- Dispute resolution (arbitration in Accra)

### Customer Terms
- Account creation and responsibilities
- Purchase terms and conditions
- Return and refund policy framework
- Privacy and data handling
- Platform role (marketplace facilitator, not seller)
