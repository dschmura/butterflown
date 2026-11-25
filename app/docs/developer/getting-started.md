---
title: Getting Started
description: Setup instructions and development workflow for ModelRails
keywords: setup install mise ruby bundle rspec tests oauth credentials development favicon icons branding ci lefthook git hooks accessibility
---

# Getting Started

Starting a product? Follow the [quickstart](quickstart) first. This page is the reference for working in the code.

## Prerequisites

- [mise](https://mise.jdx.dev/) for runtime version management (see `.tool-versions`)
- Chrome or Chromium, for the system tests: Cuprite finds an installed browser and doesn't download one

## The stack

The app runs on Rails 8.1 or newer and the pieces Rails ships. [Architecture](/docs/developer/architecture#the-stack) lists them, and explains why Rails comes from a pinned commit and how that pin is kept current.

## Setup

```bash
mise install        # Install Ruby from .tool-versions
bin/setup           # Install deps, prepare database, start server
```

Or step by step:

```bash
bundle install
rails db:prepare
rails db:seed       # Seeds default roles (and, under the :shared preset, the bootstrap owner's operatorship)
bin/dev             # Start development server
```

**Confirm it worked.** Once the server is up, open <http://localhost:3000> — you should see the public home page. That's a working install: nothing below (OAuth, a master key, `.env`) is required to get this far. `.env` is optional and only needed for production-style runs or Kamal — copy `.env.example` to `.env` if you reach for those (`bin/dev` does not need it).

### Ruby version as single source of truth

`.tool-versions` is the canonical pin for Ruby. It feeds three downstream consumers automatically:

| Consumer | Mechanism |
|---|---|
| **Local mise / asdf** | Reads `.tool-versions` directly when you `mise install` |
| **Bundler** | `Gemfile`'s `ruby file: ".tool-versions"` directive — Bundler refuses to install gems if the running Ruby doesn't match. `Gemfile.lock` captures it in the `RUBY VERSION` block. |
| **Production Docker image** | `Dockerfile`'s `ARG RUBY_VERSION` defaults to the same value; `config/deploy.yml` `builder.args.RUBY_VERSION` passes it to `kamal build` |

Bump Ruby in `.tool-versions`, run `bundle install`, and the lockfile + production builds all pick it up. If you ever break this invariant — e.g., editing `Dockerfile` `ARG` without `.tool-versions` — the integration spec at `spec/code_smells/template_invariants_spec.rb` fails with a specific actionable error.

### Dev Container (optional, VS Code)

This template ships a Dev Container configuration so you can develop in an isolated environment that matches production runtime closely. Open the project in VS Code and accept the "Reopen in Container" prompt, or run **Dev Containers: Rebuild Container** from the command palette.

The container is built on the `ruby:<version>-slim` image for the Ruby in `.tool-versions` — the **same base image as the production `Dockerfile`** (Option C: shared base, separate files). That means libvips, glibc, SQLite, and OpenSSL versions all match prod. Bugs that depend on those library versions surface in dev rather than only in production.

Capabilities baked in:

- **`docker-outside-of-docker`** feature → `kamal deploy` works *from inside* the devcontainer (your machine's Docker daemon is exposed)
- **Named bundle cache volume** → gems survive container rebuilds; no 5-min reinstall on each rebuild
- **SSH agent forwarding** → `kamal deploy` SSHes to target hosts using your existing keys
- **Port forwarding** → `:3000` (Rails) labeled in VS Code's Ports panel; the dev mail inbox (Letter Opener Web) is at `/letter_opener` on that same URL

When the container first boots, `.devcontainer/setup.sh` invokes `bin/setup` (the canonical Rails setup script) plus installs system packages mirroring the production Dockerfile. It ends with explicit next-steps guidance — copy `.env.example`, run `bin/dev`, visit `localhost:3000`.

Native development (no devcontainer) continues to work the same way as before — `mise install`, `bin/setup`, `bin/dev`. The devcontainer is an addition, not a replacement.

## Running Tests

Run the whole suite with `bin/parallel-rspec`, and the specs your branch can break with `bin/test-plan --run`. [Testing](testing#three-ways-to-run-the-suite) covers every way to run the suite, the spec conventions, and what to do when two runs collide.

## Development Tools

These affordances only render in `Rails.env.development?` and are invisible in production.

### Preview sent emails (letter_opener)

The `letter_opener_web` engine is mounted at `/letter_opener` in development (`config/routes.rb`) and set as the mail delivery method. Every email sent in dev is captured and previewed in the browser instead of going out over SMTP.

Two ways to open the inbox:

- Visit `http://localhost:3000/letter_opener` directly
- On the `sessions/check_email.html.erb` page (reached after requesting a magic link), the "Check your email" heading is itself a clickable link to the inbox, opens in a new tab. Saves a URL round-trip while iterating on auth flows.

A dev-only CSP override at `config/initializers/letter_opener_web.rb` disables the app's content-security policy on the gem's controllers so its email preview iframe and inline scripts render. Safe because the engine is mounted only in development.

### Accessibility simulation drop-up

A dev-only widget in the footer cycles through visual-impairment filters applied to the whole page. Useful for spotting color-dependency issues, low-contrast problems, or layouts that fall apart without color.

**Modes:** Normal · Blur · Grayscale · Deuteranopia · Low contrast · Cataract

**Keyboard shortcuts** (active when the dropdown is open):

- `Cmd/Ctrl+Shift+A` — open or close the dropdown
- `0`–`5` — jump directly to a mode
- `Esc` or `Tab` — close the menu

State persists across reloads via `localStorage`. The filter is applied to `<body>` (so modals, toasts, and all Turbo-replaced content receive it). Deuteranopia uses an SVG color matrix (`<feColorMatrix>`); the others use CSS filters. A live region announces mode changes for screen-reader users.

**Source:** `app/views/shared/_a11y_sim.html.erb`, `app/javascript/controllers/a11y_sim_controller.js`.

### Cookie settings dispatch (how the footer button works)

Biscuit's gem normally renders a floating "Manage cookies" button in the bottom-left corner. The app hides that button via CSS and replaces it with an in-footer button that triggers the gem's reopen action through DOM click dispatch. See `app/javascript/controllers/footer_controller.js` and the Footer Structure section of `ui-patterns.md` for the full pattern.

## CI and Git Hooks

`git push` runs the pre-push checks first: [Before You Push](/docs/developer/before-you-push) lists each one, in order, with how to rerun it. GitHub then runs its own checks on the pull request, and more on a schedule: [Checks on GitHub](/docs/developer/checks-on-github).

### Development Workflow

Every change reaches `next` by a pull request from its own branch: [Quickstart step 3](quickstart#3-work-by-pull-request) shows the commands, and [How your code reaches users](how-code-ships) follows a PR from there to production.

## OAuth Setup (optional)

Email/password and magic-link sign-in work without this — set up OAuth only if you want Google/GitHub sign-in. Add credentials for Google and GitHub OAuth (per-environment; the template ships no credential files, and the first run generates the blob and key):

```bash
bin/rails credentials:edit --environment development
```

```yaml
oauth:
  google:
    client_id: your_id
    client_secret: your_secret
  github:
    client_id: your_id
    client_secret: your_secret
```
