---
title: Email Delivery
description: How the app sends mail — the mailers, the from address, SMTP setup in production, the URL host in links, and translating emails
keywords: email mailer smtp deliver_later solid queue from address MAIL_FROM RAILS_HOST credentials bin/mail-setup bin/production-setup localization translate
---

# Email Delivery

Every email is sent in the background with `deliver_later` (Solid Queue) and is fully internationalized. For the list of emails, what triggers each and how long its link lasts, see [Email Flows](/docs/user/emails).

## Mailers

| Mailer | Purpose |
|--------|---------|
| `AuthenticationMailer` | Email verification, email change, connected-account verification, sign-in collision alerts |
| `InvitationMailer` | Workspace and project invitations |
| `MagicLinkMailer` | Passwordless sign-in and registration links |
| `ReauthenticationMailer` | Confirmation codes for re-authenticating before a sensitive change |
| `NotificationMailer` | Notification emails and digests — see [Notifications](/docs/user/notifications) |

## Configuration

### From Address

`ApplicationMailer` resolves the from address in this order:

1. `MAIL_FROM` in the environment
2. `Rails.application.credentials.dig(:mailer, :from)`
3. `noreply@` the mailer's default host (`RAILS_HOST`)

### SMTP Setup

The first time you set up production, run `bin/production-setup`
([Quickstart §4](/docs/developer/quickstart#4-production-secrets-and-mail)): it
sets up mail and the encryption keys production needs to boot. To change mail
provider later, run `bin/mail-setup` on its own. Or set this by hand.

Where mail goes comes from the environment (`SMTP_ADDRESS`, `SMTP_PORT`,
`SMTP_DOMAIN`); the login lives in the per-environment credentials:

```yaml
# bin/rails credentials:edit --environment production
smtp:
  user_name: your-user
  password: your-password
```

`lib/mail_delivery.rb` builds `config.action_mailer.smtp_settings` from both,
and production refuses to boot when either is missing. Provider recipes:
[Deployment](/docs/developer/deployment#4-configure-outbound-mail).

### Default URL Host

Production reads `config.action_mailer.default_url_options` from `RAILS_HOST` (`config/environments/production.rb`); development and test use `localhost` (a Codespace, its forwarded host). Email links use this to generate absolute URLs.

## Localization

Email subjects, greetings, body text, and button labels live under each mailer's key in `config/locales/en/`: `mailers.en.yml` (authentication and re-authentication), `invitations.en.yml` and `clientside.en.yml` (invitations), `magic_links.en.yml`, and `notifications.en.yml`. To translate emails, create locale files for your target language following the same key structure.
