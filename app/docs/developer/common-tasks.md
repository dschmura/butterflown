---
title: Common Tasks
description: Start here when you know what you want to do or what went wrong. Each common task has a one-line answer and a link to the section that covers it
keywords: how do i common tasks faq start here push refused pre-push failed red ci next workspace model job email members accessibility axe specs test-plan parallel-rspec recurring job mail not arriving troubleshooting
---

# Common Tasks

Each line gives the short answer and links to the section that covers it.
If your question isn't here, the [docs index](/docs) lists every page.

## I want to…

- **Add a model that belongs to a workspace.** Generate it with a
  `workspace` reference, load it through `@workspace` in the controller and
  authorize it with a policy.
  [Adding a workspace-scoped feature](/docs/developer/extending#adding-a-workspace-scoped-feature)
- **Write a job that works on one workspace.** Pass the workspace's id, set
  `Current.workspace` inside `perform`, and read it back with
  `Current.workspace!`.
  [Outside the request cycle](/docs/developer/extending#6-outside-the-request-cycle-jobs-rake-tasks-machine-clients)
- **Email every member of a workspace.** Use a notifier, not a mailer of
  your own. A notifier respects each member's notification preferences and
  the digest, and its mailer skips suspended users.
  [Notifier subclasses](/docs/developer/notifications#notifier-subclasses)
- **Check accessibility before I push.** The axe audit runs after every
  system spec, in both themes. The hook won't run the system spec for a page
  whose view you changed, so run that spec yourself, or write one if none
  visits the page.
  [Check accessibility on the page you changed](/docs/developer/before-you-push#check-accessibility-on-the-page-you-changed)
- **Run only the specs my branch can break.** Run `bin/test-plan --run`.
  This is what the pre-push hook runs.
  [Change lanes](/docs/developer/testing#change-lanes)
- **Run the whole suite.** Run `bin/parallel-rspec`.
  [Three ways to run the suite](/docs/developer/testing#three-ways-to-run-the-suite)
- **Get my change to users.** Merge your pull request into `next`. A release
  carries it to staging, then to production.
  [How your code reaches users](/docs/developer/how-code-ships#follow-your-pr)
- **Add a recurring job.**
  [Adding a recurring job](/docs/developer/background-jobs#adding-a-recurring-job)
- **Add a docs page of my own to a fork.**
  [Adding your own docs page](/docs/developer/forking#adding-your-own-docs-page)
- **Take the template's updates into my fork.**
  [Pull upstream updates](/docs/developer/forking#pull-upstream-updates)
- **Back up the production database.**
  [Back up the database](/docs/developer/deployment#back-up-the-database)

## Something went wrong

- **`git push` was refused.** Lefthook's summary marks the failed check with
  🥊. Rerun it with `bundle exec lefthook run pre-push --job <name>`, fix the
  cause and push again.
  [When a push is refused](/docs/developer/before-you-push#when-a-push-is-refused)
- **Tests on `next` went red after my merge.** If it's a flaky test, re-run
  the failed jobs. If it's a real failure, merge a fix. A release waits until
  CI passes on `next`.
  [When a release starts](/docs/developer/releasing#when-a-release-starts)
- **An invitation or sign-in email didn't arrive.**
  [Why didn't my invitation arrive?](/docs/developer/troubleshooting#why-didnt-my-invitation-arrive)
- **Production sends no mail.**
  [Configure outbound mail](/docs/developer/deployment#4-configure-outbound-mail)
- **A Stimulus controller does nothing.**
  [Stimulus controller silently fails to register](/docs/developer/troubleshooting#stimulus-controller-silently-fails-to-register)
- **`db/schema.rb` has changes my branch didn't make.**
  [Schema changes you didn't make](/docs/developer/troubleshooting#dbschemarb-carries-changes-your-branch-didnt-make)
- **"Another process is holding the test database."**
  [Another process is holding the test database](/docs/developer/testing#another-process-is-holding-the-test-database)
