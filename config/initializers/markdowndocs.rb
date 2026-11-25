# frozen_string_literal: true

require_relative "../../lib/markdowndocs_local_categories"

Markdowndocs.configure do |config|
  config.docs_path = Rails.root.join("app", "docs")

  # Allow hand-authored inline SVG diagrams in docs. The sanitizer still
  # strips scripts/handlers; see markdowndocs CHANGELOG 0.8.0.
  config.allow_svg = true

  # Category → slug mapping
  # Maps category names to arrays of markdown file slugs (filenames without .md)
  # NOTE: every file in app/docs/ must appear in exactly one category here, or
  # it renders only by direct URL and is invisible on the /docs index.
  # spec/docs/index_coverage_spec.rb fails CI if a doc is left orphaned.
  template_categories = {
    "Getting Started"            => %w[user/welcome developer/quickstart developer/common-tasks developer/local-development developer/changing-the-defaults developer/presets developer/codespaces developer/forking
                                       developer/presets-solo developer/presets-single-tenant developer/presets-open-saas developer/presets-none],
    "Accounts & Authentication"  => %w[user/authentication user/accounts],
    "Workspaces & Collaboration" => %w[user/workspaces user/projects user/invitations user/clientside],
    "Features"                   => %w[user/notifications user/emails],
    "Ship a change"              => %w[developer/how-code-ships developer/before-you-push developer/checks-on-github developer/testing developer/accessibility developer/releasing developer/conventions],
    "Run it in production"       => %w[developer/deployment developer/backups developer/required-production-config developer/email-delivery developer/background-jobs developer/operations developer/security developer/hot-cell],
    "Build features"             => %w[developer/extending developer/project-tools developer/onboarding developer/clientside developer/components developer/ui-patterns developer/form-drafts developer/i18n developer/machine-clients],
    "Reference"                  => %w[developer/architecture developer/application-flows developer/users-and-workspaces developer/avatars-and-logos developer/membership-lifecycle developer/passkeys developer/notifications developer/qa-flows developer/troubleshooting]
  }

  # Fork seam: a downstream fork registers its own docs pages in
  # config/markdowndocs_categories.local.yml (absent upstream) instead of
  # editing this initializer. Same-named categories append. See /docs/developer/forking.
  config.categories = MarkdowndocsLocalCategories.merge(
    template_categories,
    Rails.root.join("config/markdowndocs_categories.local.yml")
  )

  config.modes = %w[user developer]
  config.default_mode = Rails.env.development? ? "developer" : "user"
  config.search_enabled = true

  # Resolve the current user's mode preference from the database.
  # `user_preferences.docs_mode` is the canonical source of truth; cookie
  # fallback (handled by the gem) covers signed-out visitors and first-time
  # users. Returning nil lets the gem fall back to cookie → default.
  config.user_mode_resolver = ->(controller) {
    controller.send(:current_user)&.preferences&.docs_mode
  }

  # Persist the user's mode pick to the same column. The
  # `preferences || create_preferences!` pattern guarantees the saver works
  # even for users who don't have a preferences row yet (first-time
  # mode-switchers) — without this the update! call would silently no-op
  # via the `&.` safe-navigation, leaving the choice cookie-only.
  config.user_mode_saver = ->(controller, mode) {
    user = controller.send(:current_user)
    next unless user
    prefs = user.preferences || user.create_preferences!
    prefs.update!(docs_mode: mode)
  }
end
