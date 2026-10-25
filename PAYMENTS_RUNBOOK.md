# TopGrade CRM Payments Operations Runbook
**Dual Payment Architecture: Hosted Stripe Card Checkout & Bank-Verified Zelle Reconciliation**

---

## 1. Overview & Core Security Principles

TopGrade CRM operates a dual-channel payment architecture designed to maximize parent convenience while strictly protecting institutional funds and student data:

1. **Stripe Card Payments (`STRIPE_CARD`)**:
   - Hosted Checkout: Parents are redirected to Stripe's secure, hosted payment page (`checkout.stripe.com`).
   - Zero Sensitive Data: Card numbers, expiration dates, and CVVs are **never touched, collected, processed, or logged** by TopGrade CRM servers.
   - Authoritative Fulfillment: Signed HMAC webhooks (`/api/payments/stripe-webhook`) are the source of truth for payment fulfillment.
   - Idempotent Crediting: Token credits are tracked with unique idempotency locks so double-delivery of webhooks or simultaneous success page calls never credit hours more than once.

2. **Bank-Verified Zelle (`ZELLE`)**:
   - Zero Merchant API: Zelle transfers cannot be reversed and provide no API.
   - Invariant: Parent claims, screenshots, or typed notes **never** credit class hours.
   - Source of Truth: Only an authorized administrator verifying transaction credits on official bank statements (via CSV import or verified mobile app entry) can credit student ledger hours.
   - Non-Refundable: Zelle orders can never be refunded through the software platform.

3. **Master Toggles in Institute Settings**:
   - Admins can independently toggle `card_enabled` and `zelle_enabled` on or off in **Settings > Institute**.
   - If both methods are toggled off, parents see: *"Online payment is not available yet. Please contact the institute administration."*

---

## 2. Setting Up Your Stripe Account

### Step 2.1: Create Your Stripe Account
1. Visit [https://stripe.com](https://stripe.com) and click **Start now**.
2. Sign up with your official institution email (e.g., `billing@topgradeacademy.com`).
3. Complete Stripe's business identity verification:
   - Entity type (LLC, Non-profit, Corporation, Sole Proprietorship).
   - Employer Identification Number (EIN) or Tax ID.
   - Business bank account routing and account numbers for automatic daily payouts.

### Step 2.2: Locating Your API Keys
In the [Stripe Dashboard](https://dashboard.stripe.com):
1. Locate the **Developers** menu > **API keys**.
2. In **Test Mode** (toggle at top right):
   - **Publishable Key**: `pk_test_...` (Safe for client if needed, but TopGrade creates hosted sessions server-side).
   - **Secret Key**: `sk_test_...` (Server environment only).
3. In **Live Mode**:
   - **Secret Key**: `sk_live_...` (Production host only; NEVER commit to git or paste in chat).

### Step 2.3: Configuring the Webhook Endpoint
1. Go to **Developers** > **Webhooks** > click **Add an endpoint**.
2. Endpoint URL: `https://your-domain.com/api/payments/stripe-webhook`
   *(For local testing with the Stripe CLI: `stripe listen --forward-to localhost:5000/api/payments/stripe-webhook`)*
3. Select the specific events to listen for:
   - `checkout.session.completed`
   - `checkout.session.expired`
   - `checkout.session.async_payment_succeeded`
   - `checkout.session.async_payment_failed`
   - `charge.refunded`
   - `charge.dispute.created`
4. Click **Add endpoint**.
5. Reveal the **Signing secret** (starts with `whsec_...`).
6. Configure this value as `STRIPE_WEBHOOK_SECRET` in your backend server environment.

---

## 3. Environment Variables Configuration

Configure the following environment variables on your server host:

```env
# Stripe Payment Configuration
STRIPE_SECRET_KEY=sk_test_...       # Or sk_live_... for production
STRIPE_WEBHOOK_SECRET=whsec_...     # Webhook HMAC signing secret
STRIPE_CURRENCY=usd                 # Default currency (USD)

# Public Application URLs
FRONTEND_URL=https://app.topgradeacademy.com
BACKEND_URL=https://api.topgradeacademy.com

# Email Simulator (Set to false ONLY in production with valid SMTP credentials)
SIMULATE_EMAILS=false
```

> [!CAUTION]
> **CRITICAL SECURITY RULE:** Live Stripe secret keys (`sk_live_...`) and webhook secrets (`whsec_...`) must **ONLY** be entered into the hosting provider's secure dashboard (e.g. Render, Railway, AWS ECS). NEVER commit them to git, never place them in `.env.example`, and never paste them into chat or ticketing systems.

---

## 4. Going from Test Mode to Live Production

To transition payments from staging/testing to live parents:

1. **Activate Your Account**: Complete all verification tasks in Stripe Dashboard > Settings > Public Details & Bank Accounts.
2. **Configure Live Webhook**:
   - Switch Stripe Dashboard toggle to **Live**.
   - Create the live webhook endpoint pointing to your production domain: `https://app.topgradeacademy.com/api/payments/stripe-webhook`.
   - Select the 6 required events (names only: `checkout.session.completed`, `checkout.session.expired`, `checkout.session.async_payment_succeeded`, `checkout.session.async_payment_failed`, `charge.refunded`, `charge.dispute.created`).
   - Copy the live `whsec_...` secret.
3. **Set Production Environment Variables**:
   - On your production host environment settings, set `STRIPE_SECRET_KEY=sk_live_...` and `STRIPE_WEBHOOK_SECRET=whsec_...`.
   - Redeploy the backend container.
4. **Verify System Status in CRM**:
   - Sign in to the TopGrade CRM Admin Portal > **Fees & Payments**.
   - Inspect the **Payment Infrastructure System Check** row:
     - Stripe Status must display: `Stripe LIVE Mode` (Emerald badge).
     - Webhook Status must display: `Webhook Signed HMAC` (Emerald badge).
     - Card Payments toggle must display: `ON`.
5. **Run Single Real Transaction Verification**:
   - Perform a $1.00 live card purchase for a test student.
   - Verify that hours credit immediately and a PDF receipt generates.
   - Issue a refund for the $1.00 test from the CRM order screen.

---

## 5. Webhook Secret Key Rotation

If your webhook secret is ever exposed or needs scheduled rotation:

1. In the **Stripe Dashboard** > **Developers** > **Webhooks** > select your endpoint.
2. Under **Signing secret**, click **Roll secret**.
3. Stripe provides a **grace period** (e.g. 24 hours) where both the old and new secrets are valid.
4. Copy the new `whsec_...` secret immediately into your hosting environment variables.
5. Restart your backend service.
6. Verify in **Fees > System Check** that the webhook status remains green.

---

## 6. Daily Reconciliation Procedure (Admin SOP)

Perform this 5-minute routine every business morning:

1. **Review Daily Summary**:
   - Open **Fees & Payments** > **Daily Settlement Summary** tab.
   - Compare yesterday's totals:
     - Card payments: verify gross and net totals match the Stripe Payout balance in your Stripe Dashboard.
     - Zelle payments: verify total matched orders match the bank deposits credited to your checking account.
   - Click **Export CSV** or **Export Excel** to archive the daily ledger for accounting.

2. **Reconcile Pending Zelle Orders**:
   - Open the **Zelle Bank Reconciliation** tab.
   - If using CSV statements: download the daily statement from your bank portal (Chase, BoA, etc.), click **Bank File Import (CSV)**, upload the file, and review suggestions.
   - Click **Confirm Match** on verified entries to credit student hours.
   - If verifying via mobile bank app: open **Pending Orders** > click **Enter Bank Details & Confirm** > record the bank transaction ID.

3. **Inspect Stale Pending Orders**:
   - Any Zelle order older than 2 days is flagged in amber.
   - Contact parents who have not sent their transfer.
   - Orders expire automatically after 7 days (`pending_order_expiry_days`).

---

## 7. Handling Failed or Expired Payments

### Failed Card Payments
- When a parent's card is declined (insufficient funds, expired card, 3D Secure failure):
  - Stripe's hosted page provides instant feedback and invites the parent to try another card.
  - The order remains `PENDING_PAYMENT` until completed or expired.
  - If `checkout.session.async_payment_failed` triggers, the order is updated to `FAILED`, and an automated failure notification is dispatched to the parent.
- Action: Advise the parent to check their card limits with their issuing bank or use another card.

### Expired Sessions
- Stripe hosted checkout sessions expire after 24 hours.
- When `checkout.session.expired` triggers, TopGrade CRM automatically transitions the order to `EXPIRED`.
- Action: The parent can click **Buy Hours** in the portal to generate a fresh order at current catalog pricing.

---

## 8. Refunds & Disputes Standard Operating Procedure

### Processing Card Refunds
> [!IMPORTANT]
> Zelle payments can **never** be refunded through the software platform (Zelle has no reversal API). Only Stripe card payments can be refunded via the system.

1. Open **Fees & Payments** > **All Orders** tab.
2. Locate the paid Card order and click **Refund** (red button).
3. Select **Full Refund** or **Partial Refund** (specify amount in USD).
4. Enter a **Mandatory Refund Reason** (e.g. "Family moved out of district", "Schedule cancellation").
5. Click **Confirm Stripe Refund**:
   - The system calls Stripe's Refund API (`stripe.refunds.create`).
   - A negative `ADJUSTMENT` row is immediately recorded in the student's hours ledger, deducting the matching hours.
   - **Negative Balance Handling**: If the student has already attended classes using those hours, their balance will become negative (e.g. `-4.0 hours`). The system flags this account with an `OWED_HOURS_ALERT`.
   - An automated refund receipt email is sent to the parent.

### Handling Card Disputes / Chargebacks
1. **Automated Protection**:
   - When a parent files a chargeback with their credit card company, Stripe sends a `charge.dispute.created` webhook.
   - TopGrade CRM instantly marks the order `DISPUTED`, sets `dispute_status = 'OPEN'`, and sends an urgent email alert to the center administrator.
   - **Family Purchase Freeze**: All subsequent purchase attempts by that parent or family are **strictly blocked** across the entire CRM until the administrator clears the dispute.
2. **Administrative Resolution**:
   - Contact the parent to understand why the dispute was initiated (often family member unrecognized merchant name).
   - In Stripe Dashboard > **Disputes**, submit evidence (course enrollment agreement, attendance records, signed session logs).
   - Once resolved, open **Fees & Payments** > **Refunds & Disputes** tab > click **Resolve / Unfreeze**.
   - Select:
     - `CLEARED`: Unfreezes the family account to resume tutoring purchases.
     - `WON`: Bank resolved the dispute in TopGrade's favor; unfreezes account.
     - `LOST`: Bank granted chargeback to parent; dispute closed.

---

## 9. What to Tell Parents (Communication Guidelines)

| Parent Question | Standard Response |
| :--- | :--- |
| *"Can I pay with a credit or debit card?"* | *"Yes! Sign in to your parent portal at app.topgradeacademy.com, navigate to Fees, and click Buy Hours. Select 'Credit / Debit Card' to pay securely via Stripe. Your student's class hours will be credited instantly upon completion."* |
| *"Is it safe to pay with my card on your website?"* | *"TopGrade does not store or touch your card details. You are redirected to Stripe's bank-grade encrypted checkout page. Stripe is a certified PCI Level 1 Service Provider, the highest security certification in the payments industry."* |
| *"How do I pay with Zelle?"* | *"Select 'Zelle Bank Transfer' when buying hours. You will receive a unique reference code (e.g., TG-ABC123) and our official Zelle details. In your bank's app, send the payment to our institute Zelle email/phone and write your reference code in the memo. An administrator will verify the bank deposit and activate your hours."* |
| *"Why didn't my Zelle hours show up immediately?"* | *"For banking security, Zelle payments are verified directly against our official bank statements. Our administrative team reconciles bank deposits every morning. If you need urgent credit for a class starting today, reply to your order email with your bank confirmation number."* |
| *"Why can't I buy more hours online right now?"* | *(If family account is frozen due to dispute)*: *"Our accounting team is reviewing an open inquiry with your card provider regarding a recent transaction. Please contact our administrative office at (555) 019-2834 so we can resolve this together."* |
