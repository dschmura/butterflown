---
title: Before You Push
description: What to run before git push, how to check accessibility on the page you changed, and what to do when the pre-push hook refuses a push
keywords: before push pre-push lefthook hook refused failed check rerun job test-plan parallel-rspec accessibility axe system spec rubocop brakeman erb markdown docker
---

# Before You Push

`git push` runs Lefthook's pre-push checks first, one at a time, in the order
of the table below. The first check that fails stops the push. `bin/setup`
installs the hooks; in a clone made before it did, run
`bundle exec lefthook install` once. A pre-commit hook also fixes Ruby style
in the files you stage. This page covers what to run before you
push, and what to do when a push is refused.

## Run the specs your change can break

```bash
bin/test-plan --run
```

This runs the specs the hook runs. It picks them from the files your branch
changes, so it's fast, but it isn't the whole suite. CI runs the whole suite
on your pull request. Run `bin/parallel-rspec` yourself when your change
reaches past what its file names say: a shared helper, a concern, a base
class or configuration. [Change lanes](/docs/developer/testing#change-lanes)
explains how the specs are picked.

## Check accessibility on the page you changed

The axe audit runs after every system spec, in light and dark themes, and
fails the spec on any WCAG 2.2 AAA violation. A page is audited only when a
system spec visits it.

The hook runs a system spec only when your branch changes that spec's file. A
change to a view or a stylesheet doesn't select any system spec, so the hook
won't audit the page you changed. Run the system spec that visits the page
yourself:

```bash
bundle exec rspec spec/system/project_tools_spec.rb
```

If no system spec visits the page, write one. The hook then runs it, and the
audit with it. [Auditing locally](/docs/developer/accessibility#auditing-locally)
lists the helpers for checking a page in both themes.

## When a push is refused

Lefthook's summary marks the check that failed with 🥊 and its name, for
example `🥊 rubocop`. The check's own output is printed above the summary.
The checks after it show as skipped.

1. Find the check's name in the table below.
2. Rerun that check by itself, with
   `bundle exec lefthook run pre-push --job <name>` or with its command.
3. Fix the cause, commit, and push again.

Don't turn the hooks off with `LEFTHOOK=0` or `--no-verify`. CI runs the
same checks on your pull request, so the failure only moves there.

| Check | What failed | Run it by itself |
|-------|-------------|------------------|
| `protected_branch` | You pushed to `next` or `main` directly. The message prints the commands that move your commits to a branch and open a pull request. A push that creates the branch passes, and so does `git -c branch-rules.off=next push …` for a branch with no ruleset yet, which is how `bin/fork` pushes a Fork-button fork's `next` | Follow the printed commands |
| `tailwind_build` | The stylesheet didn't build | `bin/rails tailwindcss:build` |
| `brakeman` | The security scan found a problem | `bundle exec brakeman --no-pager -q` |
| `bundler_audit` | A gem in `Gemfile.lock` has a known vulnerability. Runs only when `Gemfile.lock` or `hotcell/Gemfile.lock` changed, after updating the advisory database, so it needs the network | `bin/bundler-audit check --update` |
| `rubocop` | Ruby style. `bundle exec rubocop --autocorrect` fixes the safe offenses | `bundle exec rubocop -f simple` |
| `erb_lint` | An ERB template. Runs only when an `.erb` file changed | `bundle exec rake erb:check` |
| `markdown_lint` | A Markdown file. `bundle exec rake markdown:lint` fixes what it can | `bundle exec rake markdown:check` |
| `jactionlint` | A GitHub workflow. Runs only when `.github/` or `mise.toml` changed | `jactionlint` |
| `rspec` | A spec failed, or the axe WCAG 2.2 AAA audit failed on a system spec it ran. The full suite runs in CI | `bin/test-plan --run` |
| `hotcell_build` | The Hot Cell image didn't build. Runs only when `hotcell/` changed | `docker build --pull hotcell` |
| `docker_build` | The production image didn't build. Runs only when a build input changed (`Dockerfile`, `.dockerignore`, `Gemfile`, `Gemfile.lock`, `.tool-versions`, `bin/docker-entrypoint`), and needs Docker running | `bin/docker-build-check` |
