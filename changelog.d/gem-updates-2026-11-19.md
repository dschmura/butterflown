### Security

- Thruster 0.1.28 is built on Go 1.27.4 and x/net 0.62.0, which clears the five Go CVEs the image scan ignored for its binary; `.trivyignore` drops them.

### Changed

- Gems update within their constraints, including Puma 8.1, OmniAuth 2.4, Tailwind 4.3.4 and ViewComponent 4.24.
- i18n-tasks 1.2 reports keys reached only through a dynamic key, such as `t("a11y_sim.modes.#{mode}")`, as unused. `config/i18n-tasks.yml` sets `search.strict: false` to count them as used again.
