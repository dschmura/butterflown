### Fixed

- `tenancy:owner_setup_link` and the production seed's log print links on the app's own host (the mailer's, `RAILS_HOST` in production) instead of `localhost` when `APP_HOST` isn't set.
