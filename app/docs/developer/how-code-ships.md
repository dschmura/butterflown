---
title: How your code reaches users
description: Follow one pull request from your branch through next, a release and staging to production, with the commands for each step and when to move on
keywords: release flow walkthrough pull request next staging production ship merge-back release lead hand checks onboarding new developer commands
---

# How your code reaches users

**Merging your PR doesn't put it in front of users.** It waits on the next
branch until a release includes it. There's no fixed schedule: the release
lead decides when each release ships. Before that, an automatic deploy puts
the release on staging, a practice copy of the app, where you and your team
follow each PR's hand checks. A problem there comes back as a fix PR.

This page shows a team setup: approvals on, and the `AUTO_RELEASE`,
`DEPLOY_STAGING` and `DEPLOY_PRODUCTION` switches on. A new fork starts with all
four off: no approvals, no staging, and releases and deploys run by hand.
[What changes when a switch is off](#when-a-switch-is-off).

<div class="mb-8 w-fit max-w-full rounded-lg border border-danger-border bg-danger-surface px-4 py-2 text-danger"><strong class="text-danger">Users hitting a bug right now?</strong> See <a class="font-bold text-danger!" href="#urgent-fix">Urgent fix</a> below.</div>

## Follow your PR

Each step says when to move on. Open its Commands drawer for what to run.

<div class="@container">
<div class="grid rounded-xl border border-border px-5 py-1" role="group" aria-label="How to read the markers"><div class="grid items-center gap-x-5 gap-y-2 py-3 @xl:grid-cols-[11rem_minmax(0,1fr)]"><div class="grid leading-snug"><strong>Who does it</strong><span class="text-sm">the marker's shape</span></div><div class="flex flex-wrap items-center gap-x-6 gap-y-2">
<span class="inline-flex items-center gap-2"><span class="grid size-7 place-items-center border-2 border-current bg-surface rounded-full text-text-heading relative shrink-0" aria-hidden="true"><svg class="size-4" viewBox="0 0 16 16" fill="none" stroke="currentColor" stroke-width="1.7" aria-hidden="true"><circle cx="8" cy="5" r="3"/><path d="M2.5 14.5c.6-3 2.8-4.5 5.5-4.5s4.9 1.5 5.5 4.5" stroke-linecap="round"/></svg></span>You</span>
<span class="inline-flex items-center gap-2"><span class="grid size-7 place-items-center border-2 border-current bg-surface rounded-md text-text-heading relative shrink-0" aria-hidden="true"><svg class="size-4" viewBox="0 0 16 16" fill="none" stroke="currentColor" stroke-width="1.7" aria-hidden="true"><rect x="2.5" y="4.5" width="11" height="9" rx="2.5"/><circle cx="6" cy="9" r="1.3" fill="currentColor"/><circle cx="10" cy="9" r="1.3" fill="currentColor"/><path d="M8 4.5V2" stroke-linecap="round"/></svg></span>Bot</span>
<span class="inline-flex items-center gap-2"><span class="grid size-7 place-items-center border-2 border-current bg-surface rounded-full text-text-heading relative shrink-0" aria-hidden="true"><svg class="size-4" viewBox="0 0 16 16" fill="none" stroke="currentColor" stroke-width="1.7" aria-hidden="true"><circle cx="5.5" cy="5.5" r="2.4"/><circle cx="11" cy="5.5" r="2.4"/><path d="M1 14c.4-2.4 2.2-3.6 4.5-3.6S9.6 11.6 10 14M8.6 10.6c.7-.2 1.5-.3 2.4-.3 2.3 0 4.1 1.2 4.5 3.7" stroke-linecap="round"/></svg></span>Team</span>
<span class="inline-flex items-center gap-2"><span class="grid size-7 place-items-center border-2 border-current bg-surface rounded-full text-text-heading outline-2 outline-offset-2 outline-text-heading relative shrink-0" aria-hidden="true"><svg class="size-4" viewBox="0 0 16 16" fill="none" stroke="currentColor" stroke-width="1.7" aria-hidden="true"><path d="M4 15V1.8" stroke-linecap="round"/><path d="M4.6 2.2h8.6l-2.3 3.4 2.3 3.4H4.6z" fill="currentColor" stroke-linejoin="round"/></svg></span>Release lead</span>
</div></div>
<div class="grid items-center gap-x-5 gap-y-2 border-t border-border py-3 @xl:grid-cols-[11rem_minmax(0,1fr)]"><div class="grid leading-snug"><strong>Where it lives</strong><span class="text-sm">the color, not a status</span></div><div class="flex flex-wrap items-center gap-x-6 gap-y-2">
<span class="inline-flex items-center gap-2 font-semibold text-text-body"><span class="size-3.5 rounded-sm border-2 border-border-strong bg-surface-sunken" aria-hidden="true"></span>Your laptop</span>
<span class="inline-flex items-center gap-2 font-semibold text-accent"><span class="size-3.5 rounded-sm border-2 border-accent bg-accent/10" aria-hidden="true"></span>GitHub</span>
<span class="inline-flex items-center gap-2 font-semibold text-warning"><span class="size-3.5 rounded-sm border-2 border-warning-border bg-warning-surface" aria-hidden="true"></span>release_flow</span>
<span class="inline-flex items-center gap-2 font-semibold text-info"><span class="size-3.5 rounded-sm border-2 border-info-border bg-info-surface" aria-hidden="true"></span>Kamal deploys</span>
<span class="inline-flex items-center gap-2 font-semibold text-success"><span class="size-3.5 rounded-sm border-2 border-success-border bg-success-surface" aria-hidden="true"></span>The app on a server</span>
</div></div></div>
<div class="mt-8">
<div class="hidden grid-cols-[15rem_minmax(0,1fr)] items-end pb-5 @xl:grid"><div class="lane-head relative h-16" aria-hidden="true">
<span class="absolute bottom-0 left-[30px] -translate-x-1/2 whitespace-nowrap text-center leading-tight"><span class="block font-mono font-semibold text-text-heading">your<br>branch</span><span class="block text-[13px]">&#160;</span></span>
<span class="absolute bottom-0 left-[90px] -translate-x-1/2 whitespace-nowrap text-center leading-tight"><span class="block font-mono font-semibold text-text-heading">next</span><span class="block text-[13px]">&#160;</span></span>
<span class="absolute bottom-0 left-[150px] -translate-x-1/2 whitespace-nowrap text-center leading-tight"><span class="block font-mono font-semibold text-text-heading">release</span><span class="block text-[13px]">→ staging</span></span>
<span class="absolute bottom-0 left-[210px] -translate-x-1/2 whitespace-nowrap text-center leading-tight"><span class="block font-mono font-semibold text-text-heading">main</span><span class="block text-[13px]">→ users</span></span>
</div>
<div class="ml-3 text-sm"><strong>Which branch.</strong> Each marker sits on the branch where its step happens. <span class="whitespace-nowrap"><span class="mr-1.5 inline-block w-6 border-t-4 border-text-heading align-middle"></span>your change</span> <span class="ml-3 whitespace-nowrap"><span class="mr-1.5 inline-block w-6 border-t-2 border-dashed border-text-body align-middle"></span>the merge-back</span></div></div>
<ol class="walkthrough m-0! list-none! p-0!">
<li class="m-0! grid grid-cols-[3.5rem_minmax(0,1fr)] @xl:grid-cols-[15rem_minmax(0,1fr)]"><div class="relative col-start-1 row-start-1">
<svg class="absolute inset-0 hidden h-full w-full overflow-visible @xl:block" fill="none" stroke="currentColor" aria-hidden="true"><g class="text-border-strong" stroke-width="1.5"><line x1="90" y1="0" x2="90" y2="100%"/><line x1="210" y1="0" x2="210" y2="100%"/></g><g class="text-border-strong" stroke-width="2" stroke-dasharray="1 6" stroke-linecap="round"><line x1="150" y1="0" x2="150" y2="100%"/></g><g class="text-text-heading" stroke-width="4" stroke-linecap="round"></g></svg>
<span class="absolute inset-y-0 left-[26px] w-[3px] bg-border-strong @xl:hidden" aria-hidden="true"></span></div><div class="col-start-2 row-start-1 ml-3 mb-1 mt-10 text-xs font-bold uppercase tracking-widest text-text-body">Your PR <span class="ml-2 font-mono font-medium normal-case tracking-normal">on your branch</span></div></li>
<li id="step-1" class="m-0! grid grid-cols-[3.5rem_minmax(0,1fr)] @xl:grid-cols-[15rem_minmax(0,1fr)]"><div class="lane-cell relative col-start-1 row-start-1 min-h-10 self-stretch">
<svg class="absolute inset-0 hidden h-full w-full overflow-visible @xl:block" fill="none" stroke="currentColor" aria-hidden="true"><g class="text-border-strong" stroke-width="1.5"><line x1="90" y1="0" x2="90" y2="100%"/><line x1="210" y1="0" x2="210" y2="100%"/><path d="M90,2 C90,26 30,12 30,30"/></g><g class="text-border-strong" stroke-width="2" stroke-dasharray="1 6" stroke-linecap="round"><line x1="150" y1="0" x2="150" y2="100%"/></g><g class="text-text-heading" stroke-width="4" stroke-linecap="round"><line x1="30" y1="39" x2="30" y2="100%"/></g></svg>
<span class="absolute inset-y-0 left-[26px] w-[3px] bg-border-strong @xl:hidden" aria-hidden="true"></span>
<span class="grid size-11 place-items-center border-2 border-border-strong bg-surface-sunken rounded-full text-text-body absolute top-[17px] z-10 left-1.5 @xl:left-[8px]" aria-hidden="true"><svg class="size-5" viewBox="0 0 16 16" fill="none" stroke="currentColor" stroke-width="1.7" aria-hidden="true"><circle cx="8" cy="5" r="3"/><path d="M2.5 14.5c.6-3 2.8-4.5 5.5-4.5s4.9 1.5 5.5 4.5" stroke-linecap="round"/></svg><span class="absolute -bottom-1.5 -right-2 grid h-5 min-w-5 place-items-center rounded-full border border-current bg-surface px-1 font-mono text-xs font-bold">1</span></span></div>
<div class="col-start-2 row-start-1 my-2 ml-3 grid min-w-0 gap-1 rounded-xl border bg-surface p-4 shadow-sm border-border-strong">
<div class="flex flex-wrap items-center gap-x-2.5 gap-y-1 text-xs"><span class="font-medium">You</span><span class="font-semibold text-text-body">Your laptop</span><span class="font-mono">on your branch</span></div>
<h3 class="mt-0! mb-0! text-lg! font-bold"><span class="sr-only">Step 1: </span>Work on your branch</h3>
<div>Checks run on your laptop each time you commit and push. If one fails, that commit or push stops until you fix what it names.</div>
<div class="font-mono text-xs">Lefthook · installed by bin/setup</div>
<div class="mt-1 border-l-4 pl-3 border-border-strong"><span class="block text-xs font-bold uppercase tracking-wide text-text-body">Move on when</span>Your change works in the app, and the push went through. Go to step 2.</div>
<details class="mt-2 border-t border-border"><summary class="focus-ring cursor-pointer py-3 text-sm font-semibold text-text-body">Commands</summary>
<div class="grid gap-3 pb-2 text-sm">
<div class="grid justify-items-start gap-1"><code>git fetch &amp;&amp; git switch -c fix-login origin/next</code><span>Start your branch from the latest next.</span></div>
<div class="grid justify-items-start gap-1"><code>bin/dev</code><span>Run the app and click through your change.</span></div>
<div class="grid justify-items-start gap-1"><code>bin/test-plan --run</code><span>The specs your change can break: what the push checks run.</span></div>
<div class="grid justify-items-start gap-1"><code>bin/parallel-rspec</code><span>The whole suite, the way CI runs it.</span></div>
<div class="grid justify-items-start gap-1"><code>git push -u origin fix-login</code><span>Lefthook's checks run first. If one fails, fix what it names and push again.</span></div>
</div></details>
</div></li>
<li id="step-2" class="m-0! grid grid-cols-[3.5rem_minmax(0,1fr)] @xl:grid-cols-[15rem_minmax(0,1fr)]"><div class="lane-cell relative col-start-1 row-start-1 min-h-10 self-stretch">
<svg class="absolute inset-0 hidden h-full w-full overflow-visible @xl:block" fill="none" stroke="currentColor" aria-hidden="true"><g class="text-border-strong" stroke-width="1.5"><line x1="90" y1="0" x2="90" y2="100%"/><line x1="210" y1="0" x2="210" y2="100%"/></g><g class="text-border-strong" stroke-width="2" stroke-dasharray="1 6" stroke-linecap="round"><line x1="150" y1="0" x2="150" y2="100%"/></g><g class="text-text-heading" stroke-width="4" stroke-linecap="round"><line x1="30" y1="0" x2="30" y2="100%"/></g></svg>
<span class="absolute inset-y-0 left-[26px] w-[3px] bg-border-strong @xl:hidden" aria-hidden="true"></span>
<span class="grid size-11 place-items-center border-2 border-accent bg-accent/10 rounded-full text-accent absolute top-[17px] z-10 left-1.5 @xl:left-[8px]" aria-hidden="true"><svg class="size-5" viewBox="0 0 16 16" fill="none" stroke="currentColor" stroke-width="1.7" aria-hidden="true"><circle cx="8" cy="5" r="3"/><path d="M2.5 14.5c.6-3 2.8-4.5 5.5-4.5s4.9 1.5 5.5 4.5" stroke-linecap="round"/></svg><span class="absolute -bottom-1.5 -right-2 grid h-5 min-w-5 place-items-center rounded-full border border-current bg-surface px-1 font-mono text-xs font-bold">2</span></span></div>
<div class="col-start-2 row-start-1 my-2 ml-3 grid min-w-0 gap-1 rounded-xl border bg-surface p-4 shadow-sm border-accent/40">
<div class="flex flex-wrap items-center gap-x-2.5 gap-y-1 text-xs"><span class="font-medium">You</span><span class="font-semibold text-accent">GitHub</span><span class="font-mono">on your branch</span></div>
<h3 class="mt-0! mb-0! text-lg! font-bold"><span class="sr-only">Step 2: </span>Open a PR into next</h3>
<div><code>next</code> is the default branch, so GitHub selects it automatically. Add a one-line changelog file to <code>changelog.d/</code>, and write your <strong>hand checks</strong> in the PR: steps a teammate can repeat on staging to see your change work.</div>
<div class="mt-1 border-l-4 pl-3 border-accent/40"><span class="block text-xs font-bold uppercase tracking-wide text-accent">Move on when</span>The PR has its changelog file, and numbered hand checks under “What the specs can't show”. Step 3 starts by itself.</div>
<details class="mt-2 border-t border-border"><summary class="focus-ring cursor-pointer py-3 text-sm font-semibold text-text-body">Commands</summary>
<div class="grid gap-3 pb-2 text-sm">
<div class="grid justify-items-start gap-1"><pre class="mb-0! w-full p-3!"><code>- The help page gives the support address.</code></pre><span>Your changelog file, such as <code>changelog.d/fix-login.md</code>: one line written for someone using the app. With no heading, it goes under “Changed”.</span></div>
<div class="grid justify-items-start gap-1"><code>gh pr create --base next --title "Say what changed"</code><span>Opens the PR into next. Add <code>--web</code> to fill in the template's sections in your browser.</span></div>
</div></details>
</div></li>
<li id="step-3" class="m-0! grid grid-cols-[3.5rem_minmax(0,1fr)] @xl:grid-cols-[15rem_minmax(0,1fr)]"><div class="lane-cell relative col-start-1 row-start-1 min-h-10 self-stretch">
<svg class="absolute inset-0 hidden h-full w-full overflow-visible @xl:block" fill="none" stroke="currentColor" aria-hidden="true"><g class="text-border-strong" stroke-width="1.5"><line x1="90" y1="0" x2="90" y2="100%"/><line x1="210" y1="0" x2="210" y2="100%"/></g><g class="text-border-strong" stroke-width="2" stroke-dasharray="1 6" stroke-linecap="round"><line x1="150" y1="0" x2="150" y2="100%"/></g><g class="text-text-heading" stroke-width="4" stroke-linecap="round"><line x1="30" y1="0" x2="30" y2="100%"/></g></svg>
<span class="absolute inset-y-0 left-[26px] w-[3px] bg-border-strong @xl:hidden" aria-hidden="true"></span>
<span class="grid size-11 place-items-center border-2 border-accent bg-accent/10 rounded-[10px] text-accent absolute top-[17px] z-10 left-1.5 @xl:left-[8px]" aria-hidden="true"><svg class="size-5" viewBox="0 0 16 16" fill="none" stroke="currentColor" stroke-width="1.7" aria-hidden="true"><rect x="2.5" y="4.5" width="11" height="9" rx="2.5"/><circle cx="6" cy="9" r="1.3" fill="currentColor"/><circle cx="10" cy="9" r="1.3" fill="currentColor"/><path d="M8 4.5V2" stroke-linecap="round"/></svg><span class="absolute -bottom-1.5 -right-2 grid h-5 min-w-5 place-items-center rounded-full border border-current bg-surface px-1 font-mono text-xs font-bold">3</span></span></div>
<div class="col-start-2 row-start-1 my-2 ml-3 grid min-w-0 gap-1 rounded-xl border bg-surface p-4 shadow-sm border-accent/40">
<div class="flex flex-wrap items-center gap-x-2.5 gap-y-1 text-xs"><span class="font-medium">Bot</span><span class="font-semibold text-accent">GitHub</span><span class="font-mono">on your branch</span></div>
<h3 class="mt-0! mb-0! text-lg! font-bold"><span class="sr-only">Step 3: </span>GitHub Actions tests your PR</h3>
<div>Also called CI. The PR can't merge until the tests pass.</div>
<div class="font-mono text-xs">ci.yml</div>
<div class="mt-1 border-l-4 pl-3 border-accent/40"><span class="block text-xs font-bold uppercase tracking-wide text-accent">Move on when</span><code>static</code> and <code>test</code> are both green. Go to step 4.</div>
<details class="mt-2 border-t border-border"><summary class="focus-ring cursor-pointer py-3 text-sm font-semibold text-text-body">Commands</summary>
<div class="grid gap-3 pb-2 text-sm">
<div class="grid justify-items-start gap-1"><code>gh pr checks --watch</code><span>Watch the checks from your terminal.</span></div>
<div>A red check is yours to fix: open it, fix the cause on your branch and push. The checks run again.</div>
<div class="grid justify-items-start gap-1"><code>gh run rerun &lt;run-id&gt; --failed</code><span>Reruns only the failed jobs, for a failure your change didn't cause, like a network timeout.</span></div>
</div></details>
</div></li>
<li id="step-4" class="m-0! grid grid-cols-[3.5rem_minmax(0,1fr)] @xl:grid-cols-[15rem_minmax(0,1fr)]"><div class="lane-cell relative col-start-1 row-start-1 min-h-10 self-stretch">
<svg class="absolute inset-0 hidden h-full w-full overflow-visible @xl:block" fill="none" stroke="currentColor" aria-hidden="true"><g class="text-border-strong" stroke-width="1.5"><line x1="90" y1="0" x2="90" y2="100%"/><line x1="210" y1="0" x2="210" y2="100%"/></g><g class="text-border-strong" stroke-width="2" stroke-dasharray="1 6" stroke-linecap="round"><line x1="150" y1="0" x2="150" y2="100%"/></g><g class="text-text-heading" stroke-width="4" stroke-linecap="round"><path d="M30,0 L30,6 C30,26 90,16 90,39"/><line x1="90" y1="39" x2="90" y2="100%"/></g></svg>
<span class="absolute inset-y-0 left-[26px] w-[3px] bg-border-strong @xl:hidden" aria-hidden="true"></span>
<span class="grid size-11 place-items-center border-2 border-accent bg-accent/10 rounded-full text-accent absolute top-[17px] z-10 left-1.5 @xl:left-[68px]" aria-hidden="true"><svg class="size-5" viewBox="0 0 16 16" fill="none" stroke="currentColor" stroke-width="1.7" aria-hidden="true"><circle cx="5.5" cy="5.5" r="2.4"/><circle cx="11" cy="5.5" r="2.4"/><path d="M1 14c.4-2.4 2.2-3.6 4.5-3.6S9.6 11.6 10 14M8.6 10.6c.7-.2 1.5-.3 2.4-.3 2.3 0 4.1 1.2 4.5 3.7" stroke-linecap="round"/></svg><span class="absolute -bottom-1.5 -right-2 grid h-5 min-w-5 place-items-center rounded-full border border-current bg-surface px-1 font-mono text-xs font-bold">4</span></span></div>
<div class="col-start-2 row-start-1 my-2 ml-3 grid min-w-0 gap-1 rounded-xl border bg-surface p-4 shadow-sm border-accent/40">
<div class="flex flex-wrap items-center gap-x-2.5 gap-y-1 text-xs"><span class="font-medium">Team</span><span class="font-semibold text-accent">GitHub</span><span class="font-mono">merged into next</span></div>
<h3 class="mt-0! mb-0! text-lg! font-bold"><span class="sr-only">Step 4: </span>Approved, then merged</h3>
<div>A teammate approves the code, unless your repo is set up for solo work. Your branch must be up to date with next, so if next has new commits, GitHub's <strong>Update branch</strong> button merges next into yours first. That's where the “Merge branch 'next' into …” commits in your history come from. With tests passing, it merges into next.</div>
<div class="mt-1 border-l-4 pl-3 border-accent/40"><span class="block text-xs font-bold uppercase tracking-wide text-accent">Move on when</span>GitHub shows the PR as Merged. There's nothing for you to do until step 5 or step 9.</div>
<details class="mt-2 border-t border-border"><summary class="focus-ring cursor-pointer py-3 text-sm font-semibold text-text-body">Commands</summary>
<div class="grid gap-3 pb-2 text-sm">
<div class="grid justify-items-start gap-1"><code>gh pr edit --add-reviewer &lt;teammate&gt;</code><span>Ask a teammate to review.</span></div>
<div class="grid justify-items-start gap-1"><code>gh pr update-branch</code><span>The Update branch button, from your terminal.</span></div>
<div class="grid justify-items-start gap-1"><code>gh pr merge --auto --merge</code><span>Merges by itself once it's approved and green.</span></div>
</div></details>
</div></li>
<li class="m-0! grid grid-cols-[3.5rem_minmax(0,1fr)] items-center @xl:grid-cols-[15rem_minmax(0,1fr)]"><div class="relative col-start-1 row-start-1 self-stretch">
<svg class="absolute inset-0 hidden h-full w-full overflow-visible @xl:block" fill="none" stroke="currentColor" aria-hidden="true"><g class="text-border-strong" stroke-width="1.5"><line x1="210" y1="0" x2="210" y2="100%"/></g><g class="text-border-strong" stroke-width="2" stroke-dasharray="1 6" stroke-linecap="round"><line x1="150" y1="0" x2="150" y2="100%"/></g><g class="text-text-heading" stroke-width="4" stroke-linecap="round"><line x1="90" y1="0" x2="90" y2="100%"/></g></svg>
<span class="absolute inset-y-0 left-[26px] w-[3px] bg-border-strong @xl:hidden" aria-hidden="true"></span>
<span class="absolute top-1/2 z-10 -mt-4 grid size-8 place-items-center rounded-full border-2 border-current bg-success-surface text-success left-[10px] @xl:left-[74px]" aria-hidden="true"><svg class="size-4" viewBox="0 0 18 18" fill="none" stroke="currentColor" stroke-width="2.8" stroke-linecap="round" stroke-linejoin="round"><path d="M3.5 9.5l3.6 3.6 7.4-8"/></svg></span></div><div class="col-start-2 row-start-1 my-3 ml-3 rounded-xl border-2 border-success-border bg-success-surface px-4 py-3"><span class="mr-2 text-lg font-bold text-success">Your PR is merged.</span><span>It isn't live yet, and there's nothing for you to do now. It comes back to you only if it breaks the tests on next (step 5) or when its release reaches staging (step 9). The release lead ships it to users (step 10).</span></div></li>
<li class="m-0! grid grid-cols-[3.5rem_minmax(0,1fr)] @xl:grid-cols-[15rem_minmax(0,1fr)]"><div class="relative col-start-1 row-start-1">
<svg class="absolute inset-0 hidden h-full w-full overflow-visible @xl:block" fill="none" stroke="currentColor" aria-hidden="true"><g class="text-border-strong" stroke-width="1.5"><line x1="210" y1="0" x2="210" y2="100%"/></g><g class="text-border-strong" stroke-width="2" stroke-dasharray="1 6" stroke-linecap="round"><line x1="150" y1="0" x2="150" y2="100%"/></g><g class="text-text-heading" stroke-width="4" stroke-linecap="round"><line x1="90" y1="0" x2="90" y2="100%"/></g></svg>
<span class="absolute inset-y-0 left-[26px] w-[3px] bg-border-strong @xl:hidden" aria-hidden="true"></span></div><div class="col-start-2 row-start-1 ml-3 mb-1 mt-10 text-xs font-bold uppercase tracking-widest text-text-body">The release <span class="ml-2 font-mono font-medium normal-case tracking-normal">on next, then the release branch</span></div></li>
<li id="step-5" class="m-0! grid grid-cols-[3.5rem_minmax(0,1fr)] @xl:grid-cols-[15rem_minmax(0,1fr)]"><div class="lane-cell relative col-start-1 row-start-1 min-h-10 self-stretch">
<svg class="absolute inset-0 hidden h-full w-full overflow-visible @xl:block" fill="none" stroke="currentColor" aria-hidden="true"><g class="text-border-strong" stroke-width="1.5"><line x1="210" y1="0" x2="210" y2="100%"/></g><g class="text-border-strong" stroke-width="2" stroke-dasharray="1 6" stroke-linecap="round"><line x1="150" y1="0" x2="150" y2="100%"/></g><g class="text-text-heading" stroke-width="4" stroke-linecap="round"><line x1="90" y1="0" x2="90" y2="100%"/></g></svg>
<span class="absolute inset-y-0 left-[26px] w-[3px] bg-border-strong @xl:hidden" aria-hidden="true"></span>
<span class="grid size-11 place-items-center border-2 border-accent bg-accent/10 rounded-[10px] text-accent absolute top-[17px] z-10 left-1.5 @xl:left-[68px]" aria-hidden="true"><svg class="size-5" viewBox="0 0 16 16" fill="none" stroke="currentColor" stroke-width="1.7" aria-hidden="true"><rect x="2.5" y="4.5" width="11" height="9" rx="2.5"/><circle cx="6" cy="9" r="1.3" fill="currentColor"/><circle cx="10" cy="9" r="1.3" fill="currentColor"/><path d="M8 4.5V2" stroke-linecap="round"/></svg><span class="absolute -bottom-1.5 -right-2 grid h-5 min-w-5 place-items-center rounded-full border border-current bg-surface px-1 font-mono text-xs font-bold">5</span></span></div>
<div class="col-start-2 row-start-1 my-2 ml-3 grid min-w-0 gap-1 rounded-xl border bg-surface p-4 shadow-sm border-accent/40">
<div class="flex flex-wrap items-center gap-x-2.5 gap-y-1 text-xs"><span class="font-medium">Bot</span><span class="font-semibold text-accent">GitHub</span><span class="font-mono">on next</span></div>
<h3 class="mt-0! mb-0! text-lg! font-bold"><span class="sr-only">Step 5: </span>Tests run again on next</h3>
<div>After every merge, the whole suite runs on next. Code on next isn't deployed anywhere.</div>
<div class="mt-2 rounded-lg border border-dashed border-border-strong bg-surface-sunken px-3 py-2 text-sm"><span class="mr-2 text-xs font-bold uppercase tracking-wide text-text-heading">⏸ The release may stop here</span>If tests on next fail, the release branch (step 7) can't be made. <strong>If your PR broke the tests, you fix them</strong> with a PR into next. If you can't, the release lead takes over. When the tests pass, the release continues automatically.</div>
<div class="mt-2 rounded-lg border border-warning-border bg-warning-surface px-3 py-2 text-sm"><span class="mr-2 text-xs font-bold uppercase tracking-wide text-warning">Changelog</span>Once step 6's changelog PR has merged, <code>CHANGELOG.md</code> on next has a <code>## v2026.11.18</code> heading. From then on, a fix's changelog line goes under that heading, not in <code>changelog.d/</code>. A file in <code>changelog.d/</code> would make the fix wait for the release after this one.</div>
<div class="mt-1 border-l-4 pl-3 border-accent/40"><span class="block text-xs font-bold uppercase tracking-wide text-accent">Move on when</span>The newest run on next is green. Steps 6 and 7 run automatically.</div>
<details class="mt-2 border-t border-border"><summary class="focus-ring cursor-pointer py-3 text-sm font-semibold text-text-body">Commands</summary>
<div class="grid gap-3 pb-2 text-sm">
<div class="grid justify-items-start gap-1"><code>gh run list --branch next --workflow ci.yml --limit 3</code><span>The latest test runs on next.</span></div>
<div class="grid justify-items-start gap-1"><code>gh run watch</code><span>Follow a run while it goes.</span></div>
<div class="grid justify-items-start gap-1"><code>git switch -c fix-next origin/next</code><span>If your PR broke the tests: fix them on a branch from next, then open a PR into next as in steps 1–4.</span></div>
</div></details>
</div></li>
<li id="step-6" class="m-0! grid grid-cols-[3.5rem_minmax(0,1fr)] @xl:grid-cols-[15rem_minmax(0,1fr)]"><div class="lane-cell relative col-start-1 row-start-1 min-h-10 self-stretch">
<svg class="absolute inset-0 hidden h-full w-full overflow-visible @xl:block" fill="none" stroke="currentColor" aria-hidden="true"><g class="text-border-strong" stroke-width="1.5"><line x1="210" y1="0" x2="210" y2="100%"/></g><g class="text-border-strong" stroke-width="2" stroke-dasharray="1 6" stroke-linecap="round"><line x1="150" y1="0" x2="150" y2="100%"/></g><g class="text-text-heading" stroke-width="4" stroke-linecap="round"><line x1="90" y1="0" x2="90" y2="100%"/></g></svg>
<span class="absolute inset-y-0 left-[26px] w-[3px] bg-border-strong @xl:hidden" aria-hidden="true"></span>
<span class="grid size-11 place-items-center border-2 border-warning-border bg-warning-surface rounded-[10px] text-warning absolute top-[17px] z-10 left-1.5 @xl:left-[68px]" aria-hidden="true"><svg class="size-5" viewBox="0 0 16 16" fill="none" stroke="currentColor" stroke-width="1.7" aria-hidden="true"><rect x="2.5" y="4.5" width="11" height="9" rx="2.5"/><circle cx="6" cy="9" r="1.3" fill="currentColor"/><circle cx="10" cy="9" r="1.3" fill="currentColor"/><path d="M8 4.5V2" stroke-linecap="round"/></svg><span class="absolute -bottom-1.5 -right-2 grid h-5 min-w-5 place-items-center rounded-full border border-current bg-surface px-1 font-mono text-xs font-bold">6</span></span></div>
<div class="col-start-2 row-start-1 my-2 ml-3 grid min-w-0 gap-1 rounded-xl border bg-surface p-4 shadow-sm border-warning-border">
<div class="flex flex-wrap items-center gap-x-2.5 gap-y-1 text-xs"><span class="font-medium">Bot</span><span class="font-semibold text-warning">release_flow</span><span class="font-mono">on next</span></div>
<h3 class="mt-0! mb-0! text-lg! font-bold"><span class="sr-only">Step 6: </span>The release is named with the date</h3>
<div>Like <code>2026.11.18</code>. Everyone's changelog lines are gathered into one list. This starts when merged work is waiting and no other release is in progress.</div>
<div class="font-mono text-xs">bin/release prepare</div>
<div class="mt-2 rounded-lg border border-dashed border-border-strong bg-surface-sunken px-3 py-2 text-sm"><span class="mr-2 text-xs font-bold uppercase tracking-wide text-text-heading">⏸ Your change can wait here</span>While another release is still in progress, yours waits for the next one. <strong>Nothing for you to do.</strong></div>
<div class="mt-1 border-l-4 pl-3 border-warning-border"><span class="block text-xs font-bold uppercase tracking-wide text-warning">Move on when</span>The changelog PR has merged into next. Go to step 7.</div>
<details class="mt-2 border-t border-border"><summary class="focus-ring cursor-pointer py-3 text-sm font-semibold text-text-body">Commands</summary>
<div class="grid gap-3 pb-2 text-sm">
<div>With <code>AUTO_RELEASE</code> on, this runs after every merge into next as <code>bin/release prepare --if-needed</code>.</div>
<div class="grid justify-items-start gap-1"><code>bin/release prepare</code><span>By hand, for the release lead. It opens a changelog PR into next that merges itself.</span></div>
<div class="grid justify-items-start gap-1"><code>bin/release prepare --dry-run</code><span>Shows what it would do, without doing it.</span></div>
<div>It refuses when no changelog files are waiting, or while another release is in progress, and says which.</div>
</div></details>
</div></li>
<li id="step-7" class="m-0! grid grid-cols-[3.5rem_minmax(0,1fr)] @xl:grid-cols-[15rem_minmax(0,1fr)]"><div class="lane-cell relative col-start-1 row-start-1 min-h-10 self-stretch">
<svg class="absolute inset-0 hidden h-full w-full overflow-visible @xl:block" fill="none" stroke="currentColor" aria-hidden="true"><g class="text-border-strong" stroke-width="1.5"><line x1="210" y1="0" x2="210" y2="100%"/><line x1="90" y1="0" x2="90" y2="100%"/></g><g class="text-border-strong" stroke-width="2" stroke-dasharray="1 6" stroke-linecap="round"><line x1="150" y1="0" x2="150" y2="100%"/></g><g class="text-text-heading" stroke-width="4" stroke-linecap="round"><line x1="90" y1="0" x2="90" y2="6"/><path d="M90,6 C90,28 150,16 150,39"/><line x1="150" y1="39" x2="150" y2="100%"/></g></svg>
<span class="absolute inset-y-0 left-[26px] w-[3px] bg-border-strong @xl:hidden" aria-hidden="true"></span>
<span class="grid size-11 place-items-center border-2 border-warning-border bg-warning-surface rounded-[10px] text-warning absolute top-[17px] z-10 left-1.5 @xl:left-[128px]" aria-hidden="true"><svg class="size-5" viewBox="0 0 16 16" fill="none" stroke="currentColor" stroke-width="1.7" aria-hidden="true"><rect x="2.5" y="4.5" width="11" height="9" rx="2.5"/><circle cx="6" cy="9" r="1.3" fill="currentColor"/><circle cx="10" cy="9" r="1.3" fill="currentColor"/><path d="M8 4.5V2" stroke-linecap="round"/></svg><span class="absolute -bottom-1.5 -right-2 grid h-5 min-w-5 place-items-center rounded-full border border-current bg-surface px-1 font-mono text-xs font-bold">7</span></span></div>
<div class="col-start-2 row-start-1 my-2 ml-3 grid min-w-0 gap-1 rounded-xl border bg-surface p-4 shadow-sm border-warning-border">
<div class="flex flex-wrap items-center gap-x-2.5 gap-y-1 text-xs"><span class="font-medium">Bot</span><span class="font-semibold text-warning">release_flow</span><span class="font-mono">copies next to release/2026.11.18</span></div>
<h3 class="mt-0! mb-0! text-lg! font-bold"><span class="sr-only">Step 7: </span>A release branch is made</h3>
<div><code>release/2026.11.18</code>, plus a <strong>release PR</strong> into main listing “What ships”. When that PR appears, staging is getting the release.</div>
<div class="font-mono text-xs">bin/release cut</div>
<div class="mt-1 border-l-4 pl-3 border-warning-border"><span class="block text-xs font-bold uppercase tracking-wide text-warning">Move on when</span><code>release/2026.11.18</code> exists and the release PR is open. Step 8 starts by itself.</div>
<details class="mt-2 border-t border-border"><summary class="focus-ring cursor-pointer py-3 text-sm font-semibold text-text-body">Commands</summary>
<div class="grid gap-3 pb-2 text-sm">
<div>With <code>AUTO_RELEASE</code> on, this runs when the tests pass on next, as <code>bin/release cut --if-needed</code>.</div>
<div class="grid justify-items-start gap-1"><code>bin/release cut</code><span>By hand, for the release lead. Add <code>--dry-run</code> to see the plan first.</span></div>
<div class="grid justify-items-start gap-1"><code>gh pr list --base main</code><span>Find the release PR.</span></div>
<div>When <code>cut</code> refuses, it says why: the tests on next aren't green, another <code>release/*</code> branch is open, the last merge-back hasn't merged, or some changelog lines arrived late and need moving (it lists them).</div>
</div></details>
</div></li>
<li id="step-8" class="m-0! grid grid-cols-[3.5rem_minmax(0,1fr)] @xl:grid-cols-[15rem_minmax(0,1fr)]"><div class="lane-cell relative col-start-1 row-start-1 min-h-10 self-stretch">
<svg class="absolute inset-0 hidden h-full w-full overflow-visible @xl:block" fill="none" stroke="currentColor" aria-hidden="true"><g class="text-border-strong" stroke-width="1.5"><line x1="90" y1="0" x2="90" y2="100%"/><line x1="210" y1="0" x2="210" y2="100%"/></g><g class="text-border-strong" stroke-width="2" stroke-dasharray="1 6" stroke-linecap="round"><line x1="150" y1="0" x2="150" y2="100%"/></g><g class="text-text-heading" stroke-width="4" stroke-linecap="round"><line x1="150" y1="0" x2="150" y2="100%"/></g></svg>
<span class="absolute inset-y-0 left-[26px] w-[3px] bg-border-strong @xl:hidden" aria-hidden="true"></span>
<span class="grid size-11 place-items-center border-2 border-info-border bg-info-surface rounded-[10px] text-info absolute top-[17px] z-10 left-1.5 @xl:left-[128px]" aria-hidden="true"><svg class="size-5" viewBox="0 0 16 16" fill="none" stroke="currentColor" stroke-width="1.7" aria-hidden="true"><rect x="2.5" y="4.5" width="11" height="9" rx="2.5"/><circle cx="6" cy="9" r="1.3" fill="currentColor"/><circle cx="10" cy="9" r="1.3" fill="currentColor"/><path d="M8 4.5V2" stroke-linecap="round"/></svg><span class="absolute -bottom-1.5 -right-2 grid h-5 min-w-5 place-items-center rounded-full border border-current bg-surface px-1 font-mono text-xs font-bold">8</span></span></div>
<div class="col-start-2 row-start-1 my-2 ml-3 grid min-w-0 gap-1 rounded-xl border bg-surface p-4 shadow-sm border-info-border">
<div class="flex flex-wrap items-center gap-x-2.5 gap-y-1 text-xs"><span class="font-medium">Bot</span><span class="font-semibold text-info">Kamal deploys</span><span class="font-mono">on release/2026.11.18 · deployed to staging</span></div>
<h3 class="mt-0! mb-0! text-lg! font-bold"><span class="sr-only">Step 8: </span>Staging gets the release</h3>
<div>The release is copied to the staging server, a practice copy of the app that the whole team shares.</div>
<div class="font-mono text-xs">deploy.yml · staging</div>
<div class="mt-1 border-l-4 pl-3 border-info-border"><span class="block text-xs font-bold uppercase tracking-wide text-info">Move on when</span>The deploy run is green. The repository's Environments page shows the commit staging is running. Go to step 9.</div>
<details class="mt-2 border-t border-border"><summary class="focus-ring cursor-pointer py-3 text-sm font-semibold text-text-body">Commands</summary>
<div class="grid gap-3 pb-2 text-sm">
<div>With <code>DEPLOY_STAGING</code> on, every push to a <code>release/*</code> branch deploys staging.</div>
<div class="grid justify-items-start gap-1"><code>gh run list --workflow deploy.yml --limit 3</code><span>The latest deploys. Follow one with <code>gh run watch</code>.</span></div>
<div class="grid justify-items-start gap-1"><code>bin/kamal logs -d staging</code><span>Follow the staging app's logs.</span></div>
<div class="grid justify-items-start gap-1"><code>bin/kamal deploy -d staging</code><span>Deploy staging by hand, when the bot step is off.</span></div>
</div></details>
</div></li>
<li id="step-9" class="m-0! grid grid-cols-[3.5rem_minmax(0,1fr)] @xl:grid-cols-[15rem_minmax(0,1fr)]"><div class="lane-cell relative col-start-1 row-start-1 min-h-10 self-stretch">
<svg class="absolute inset-0 hidden h-full w-full overflow-visible @xl:block" fill="none" stroke="currentColor" aria-hidden="true"><g class="text-border-strong" stroke-width="1.5"><line x1="90" y1="0" x2="90" y2="100%"/><line x1="210" y1="0" x2="210" y2="100%"/></g><g class="text-border-strong" stroke-width="2" stroke-dasharray="1 6" stroke-linecap="round"><line x1="150" y1="0" x2="150" y2="100%"/></g><g class="text-text-heading" stroke-width="4" stroke-linecap="round"><line x1="150" y1="0" x2="150" y2="100%"/></g></svg>
<span class="absolute inset-y-0 left-[26px] w-[3px] bg-border-strong @xl:hidden" aria-hidden="true"></span>
<span class="grid size-11 place-items-center border-2 border-success-border bg-success-surface rounded-full text-success absolute top-[17px] z-10 left-1.5 @xl:left-[128px]" aria-hidden="true"><svg class="size-5" viewBox="0 0 16 16" fill="none" stroke="currentColor" stroke-width="1.7" aria-hidden="true"><circle cx="5.5" cy="5.5" r="2.4"/><circle cx="11" cy="5.5" r="2.4"/><path d="M1 14c.4-2.4 2.2-3.6 4.5-3.6S9.6 11.6 10 14M8.6 10.6c.7-.2 1.5-.3 2.4-.3 2.3 0 4.1 1.2 4.5 3.7" stroke-linecap="round"/></svg><span class="absolute -bottom-1.5 -right-2 grid h-5 min-w-5 place-items-center rounded-full border border-current bg-surface px-1 font-mono text-xs font-bold">9</span></span></div>
<div class="col-start-2 row-start-1 my-2 ml-3 grid min-w-0 gap-1 rounded-xl border bg-surface p-4 shadow-sm border-success-border">
<div class="flex flex-wrap items-center gap-x-2.5 gap-y-1 text-xs"><span class="font-medium">Team, you included</span><span class="font-semibold text-success">The app on a server · staging</span><span class="font-mono">on release/2026.11.18</span></div>
<h3 class="mt-0! mb-0! text-lg! font-bold"><span class="sr-only">Step 9: </span>Follow the hand checks on staging</h3>
<div>Each item in the release PR's “What ships” list came from a PR. Open the staging app and repeat that PR's hand checks. Start with your own.</div>
<div class="mt-2 rounded-lg border border-solid border-border-strong bg-surface-sunken px-3 py-2 text-sm"><span class="mr-2 text-xs font-bold uppercase tracking-wide text-text-heading">↺ Found a problem?</span>Fix it, or undo the PR that caused it (a revert), with a PR into the release branch, not next. Staging is deployed again, and the checks start again at step 8.</div>
<div class="mt-1 border-l-4 pl-3 border-success-border"><span class="block text-xs font-bold uppercase tracking-wide text-success">Move on when</span>Every PR's checks pass, and the commit you checked is in the release PR's “Commit reviewed on staging” line. The release lead takes step 10.</div>
<details class="mt-2 border-t border-border"><summary class="focus-ring cursor-pointer py-3 text-sm font-semibold text-text-body">Commands</summary>
<div class="grid gap-3 pb-2 text-sm">
<div>The release PR's Commits tab lists every PR in the release. Open each one and follow its “What the specs can't show” steps on staging.</div>
<div class="grid justify-items-start gap-1"><code>bin/kamal logs -d staging</code><span>Watch for errors while you click.</span></div>
<div class="grid justify-items-start gap-1"><pre class="mb-0! w-full p-3!"><code>git switch -c fix-signup origin/release/2026.11.18
# fix, commit, push
gh pr create --base release/2026.11.18</code></pre><span>Fix a problem on the release branch. Its changelog line goes under <code>## v2026.11.18</code> in <code>CHANGELOG.md</code>, not in <code>changelog.d/</code>.</span></div>
<div class="grid justify-items-start gap-1"><pre class="mb-0! w-full p-3!"><code>git switch -c hold-back-search origin/release/2026.11.18
git revert -m 1 &lt;the PR's merge commit&gt;
git push -u origin hold-back-search
gh pr create --base release/2026.11.18</code></pre><span>Or take a PR out of this release. Also delete its line from the release's changelog section, and list it under “Held back” in the release PR.</span></div>
<div>No staging (a new fork's default)? Check the release branch however you test, such as running it with <code>bin/dev</code>, then record its head commit instead.</div>
<div class="grid justify-items-start gap-1"><code>git rev-parse origin/release/2026.11.18</code><span>The release branch's head commit. <code>bin/release ship</code> offers the same one when no staging deploy is found.</span></div>
</div></details>
</div></li>
<li class="m-0! grid grid-cols-[3.5rem_minmax(0,1fr)] @xl:grid-cols-[15rem_minmax(0,1fr)]"><div class="relative col-start-1 row-start-1">
<svg class="absolute inset-0 hidden h-full w-full overflow-visible @xl:block" fill="none" stroke="currentColor" aria-hidden="true"><g class="text-border-strong" stroke-width="1.5"><line x1="90" y1="0" x2="90" y2="100%"/><line x1="210" y1="0" x2="210" y2="100%"/></g><g class="text-border-strong" stroke-width="2" stroke-dasharray="1 6" stroke-linecap="round"><line x1="150" y1="0" x2="150" y2="100%"/></g><g class="text-text-heading" stroke-width="4" stroke-linecap="round"><line x1="150" y1="0" x2="150" y2="100%"/></g></svg>
<span class="absolute inset-y-0 left-[26px] w-[3px] bg-border-strong @xl:hidden" aria-hidden="true"></span></div><div class="col-start-2 row-start-1 ml-3 mb-1 mt-10 text-xs font-bold uppercase tracking-widest text-text-body">Production <span class="ml-2 font-mono font-medium normal-case tracking-normal">on main</span></div></li>
<li id="step-10" class="m-0! grid grid-cols-[3.5rem_minmax(0,1fr)] @xl:grid-cols-[15rem_minmax(0,1fr)]"><div class="lane-cell relative col-start-1 row-start-1 min-h-10 self-stretch">
<svg class="absolute inset-0 hidden h-full w-full overflow-visible @xl:block" fill="none" stroke="currentColor" aria-hidden="true"><g class="text-border-strong" stroke-width="1.5"><line x1="90" y1="0" x2="90" y2="100%"/><line x1="210" y1="0" x2="210" y2="100%"/></g><g class="text-border-strong" stroke-width="2" stroke-dasharray="1 6" stroke-linecap="round"><line x1="150" y1="0" x2="150" y2="100%"/></g><g class="text-text-heading" stroke-width="4" stroke-linecap="round"><line x1="150" y1="0" x2="150" y2="6"/><path d="M150,6 C150,28 210,16 210,39"/><line x1="210" y1="39" x2="210" y2="100%"/></g></svg>
<span class="absolute inset-y-0 left-[26px] w-[3px] bg-border-strong @xl:hidden" aria-hidden="true"></span>
<span class="grid size-11 place-items-center border-2 border-warning-border bg-warning-surface rounded-full text-warning outline-2 outline-offset-2 outline-text-heading absolute top-[17px] z-10 left-1.5 @xl:left-[188px]" aria-hidden="true"><svg class="size-5" viewBox="0 0 16 16" fill="none" stroke="currentColor" stroke-width="1.7" aria-hidden="true"><path d="M4 15V1.8" stroke-linecap="round"/><path d="M4.6 2.2h8.6l-2.3 3.4 2.3 3.4H4.6z" fill="currentColor" stroke-linejoin="round"/></svg><span class="absolute -bottom-1.5 -right-2 grid h-5 min-w-5 place-items-center rounded-full border border-current bg-surface px-1 font-mono text-xs font-bold">10</span></span></div>
<div class="col-start-2 row-start-1 my-2 ml-3 grid min-w-0 gap-1 rounded-xl border bg-surface p-4 shadow-sm border-warning-border">
<div class="flex flex-wrap items-center gap-x-2.5 gap-y-1 text-xs"><span class="font-medium">Release lead</span><span class="font-semibold text-warning">release_flow</span><span class="font-mono">merges release/2026.11.18 into main</span></div>
<h3 class="mt-0! mb-0! text-lg! font-bold"><span class="sr-only">Step 10: </span>Ship it</h3>
<div>When the checks are done, the release lead runs one command and answers “Ship? y/N”. This merges the release into main, tags it <code>v2026.11.18</code>, and starts step 11.</div>
<div class="font-mono text-xs">bin/release ship</div>
<div class="mt-2 rounded-lg border border-dashed border-border-strong bg-surface-sunken px-3 py-2 text-sm"><span class="mr-2 text-xs font-bold uppercase tracking-wide text-text-heading">⏸ Shipping can stop here</span>If the release changed after staging got it, shipping waits until staging has the new version and it's been checked. <strong>The release lead handles it.</strong></div>
<div class="mt-1 border-l-4 pl-3 border-warning-border"><span class="block text-xs font-bold uppercase tracking-wide text-warning">Move on when</span>GitHub shows the release <code>v2026.11.18</code>. Step 12 starts by itself, and so does step 11 when <code>DEPLOY_PRODUCTION</code> is on.</div>
<details class="mt-2 border-t border-border"><summary class="focus-ring cursor-pointer py-3 text-sm font-semibold text-text-body">Commands</summary>
<div class="grid gap-3 pb-2 text-sm">
<div class="grid justify-items-start gap-1"><code>bin/release ship</code><span>Shows the release PR and the commit staging ran, then asks “Ship abc1234? [y/N]”.</span></div>
<div class="grid justify-items-start gap-1"><code>bin/release ship --dry-run</code><span>Shows the plan without shipping.</span></div>
<div class="grid justify-items-start gap-1"><code>bin/release ship &lt;PR&gt; &lt;commit&gt;</code><span>Names the PR and the reviewed commit yourself, where nothing can answer the question, as in CI.</span></div>
<div>Stopped partway? Run the same command again. It skips what's already done. If the repo requires approvals, someone other than the author approves the release PR first.</div>
</div></details>
</div></li>
<li id="step-11" class="m-0! grid grid-cols-[3.5rem_minmax(0,1fr)] @xl:grid-cols-[15rem_minmax(0,1fr)]"><div class="lane-cell relative col-start-1 row-start-1 min-h-10 self-stretch">
<svg class="absolute inset-0 hidden h-full w-full overflow-visible @xl:block" fill="none" stroke="currentColor" aria-hidden="true"><g class="text-border-strong" stroke-width="1.5"><line x1="90" y1="0" x2="90" y2="100%"/></g><g class="text-border-strong" stroke-width="2" stroke-dasharray="1 6" stroke-linecap="round"><line x1="150" y1="0" x2="150" y2="100%"/></g><g class="text-text-heading" stroke-width="4" stroke-linecap="round"><line x1="210" y1="0" x2="210" y2="100%"/></g></svg>
<span class="absolute inset-y-0 left-[26px] w-[3px] bg-border-strong @xl:hidden" aria-hidden="true"></span>
<span class="grid size-11 place-items-center border-2 border-info-border bg-info-surface rounded-[10px] text-info absolute top-[17px] z-10 left-1.5 @xl:left-[188px]" aria-hidden="true"><svg class="size-5" viewBox="0 0 16 16" fill="none" stroke="currentColor" stroke-width="1.7" aria-hidden="true"><rect x="2.5" y="4.5" width="11" height="9" rx="2.5"/><circle cx="6" cy="9" r="1.3" fill="currentColor"/><circle cx="10" cy="9" r="1.3" fill="currentColor"/><path d="M8 4.5V2" stroke-linecap="round"/></svg><span class="absolute -bottom-1.5 -right-2 grid h-5 min-w-5 place-items-center rounded-full border border-current bg-surface px-1 font-mono text-xs font-bold">11</span></span></div>
<div class="col-start-2 row-start-1 my-2 ml-3 grid min-w-0 gap-1 rounded-xl border bg-surface p-4 shadow-sm border-info-border">
<div class="flex flex-wrap items-center gap-x-2.5 gap-y-1 text-xs"><span class="font-medium">Bot</span><span class="font-semibold text-info">Kamal deploys</span><span class="font-mono">on main · deployed to users</span></div>
<h3 class="mt-0! mb-0! text-lg! font-bold"><span class="sr-only">Step 11: </span>Users get the release</h3>
<div>The release is copied to the production server: the real app.</div>
<div class="font-mono text-xs">deploy.yml · production</div>
<div class="mt-1 border-l-4 pl-3 border-info-border"><span class="block text-xs font-bold uppercase tracking-wide text-info">Move on when</span>The deploy run is green and the app works. Your change is live.</div>
<details class="mt-2 border-t border-border"><summary class="focus-ring cursor-pointer py-3 text-sm font-semibold text-text-body">Commands</summary>
<div class="grid gap-3 pb-2 text-sm">
<div>With <code>DEPLOY_PRODUCTION</code> on, every change to main deploys production.</div>
<div class="grid justify-items-start gap-1"><code>bin/kamal deploy</code><span>With it off (a new fork's default), deploy production from your machine after step 10.</span></div>
<div class="grid justify-items-start gap-1"><code>gh run list --workflow deploy.yml --branch main --limit 1</code><span>The production deploy. Follow it with <code>gh run watch</code>.</span></div>
<div class="grid justify-items-start gap-1"><code>bin/kamal logs</code><span>Follow production's logs.</span></div>
<div class="grid justify-items-start gap-1"><code>bin/kamal rollback &lt;version&gt;</code><span>Boots an earlier version again, if this one is broken. <code>bin/kamal app containers</code> lists the versions. It doesn't undo migrations that already ran.</span></div>
</div></details>
</div></li>
<li class="m-0! grid grid-cols-[3.5rem_minmax(0,1fr)] items-center @xl:grid-cols-[15rem_minmax(0,1fr)]"><div class="relative col-start-1 row-start-1 self-stretch">
<svg class="absolute inset-0 hidden h-full w-full overflow-visible @xl:block" fill="none" stroke="currentColor" aria-hidden="true"><g class="text-border-strong" stroke-width="1.5"><line x1="90" y1="0" x2="90" y2="100%"/></g><g class="text-border-strong" stroke-width="2" stroke-dasharray="1 6" stroke-linecap="round"><line x1="150" y1="0" x2="150" y2="100%"/></g><g class="text-text-heading" stroke-width="4" stroke-linecap="round"><line x1="210" y1="0" x2="210" y2="100%"/></g></svg>
<span class="absolute inset-y-0 left-[26px] w-[3px] bg-border-strong @xl:hidden" aria-hidden="true"></span>
<span class="absolute top-1/2 z-10 -mt-4 grid size-8 place-items-center rounded-full border-2 border-current bg-success-surface text-success left-[10px] @xl:left-[194px]" aria-hidden="true"><svg class="size-4" viewBox="0 0 18 18" fill="none" stroke="currentColor" stroke-width="2.8" stroke-linecap="round" stroke-linejoin="round"><path d="M3.5 9.5l3.6 3.6 7.4-8"/></svg></span></div><div class="col-start-2 row-start-1 my-3 ml-3 rounded-xl border-2 border-success-border bg-success-surface px-4 py-3"><span class="mr-2 text-lg font-bold text-success">Your change is live.</span><span>Users have it, in the release tagged <code>v2026.11.18</code>. A problem found now goes into next like any other PR, or, if users can't wait, it's an urgent fix (below).</span></div></li>
<li id="step-12" class="m-0! grid grid-cols-[3.5rem_minmax(0,1fr)] @xl:grid-cols-[15rem_minmax(0,1fr)]"><div class="lane-cell relative col-start-1 row-start-1 min-h-10 self-stretch">
<svg class="absolute inset-0 hidden h-full w-full overflow-visible @xl:block" fill="none" stroke="currentColor" aria-hidden="true"><g class="text-border-strong" stroke-width="1.5"><line x1="90" y1="0" x2="90" y2="100%"/></g><g class="text-border-strong" stroke-width="2" stroke-dasharray="1 6" stroke-linecap="round"><line x1="150" y1="0" x2="150" y2="100%"/></g><g class="text-text-body" stroke-width="2" stroke-dasharray="5 4"><path d="M210,4 C210,28 90,14 90,39"/></g><g class="text-text-heading" stroke-width="4" stroke-linecap="round"><line x1="210" y1="0" x2="210" y2="100%"/></g></svg>
<span class="absolute inset-y-0 left-[26px] w-[3px] bg-border-strong @xl:hidden" aria-hidden="true"></span>
<span class="grid size-11 place-items-center border-2 border-warning-border bg-warning-surface rounded-[10px] text-warning absolute top-[17px] z-10 left-1.5 @xl:left-[68px]" aria-hidden="true"><svg class="size-5" viewBox="0 0 16 16" fill="none" stroke="currentColor" stroke-width="1.7" aria-hidden="true"><rect x="2.5" y="4.5" width="11" height="9" rx="2.5"/><circle cx="6" cy="9" r="1.3" fill="currentColor"/><circle cx="10" cy="9" r="1.3" fill="currentColor"/><path d="M8 4.5V2" stroke-linecap="round"/></svg><span class="absolute -bottom-1.5 -right-2 grid h-5 min-w-5 place-items-center rounded-full border border-current bg-surface px-1 font-mono text-xs font-bold">12</span></span></div>
<div class="col-start-2 row-start-1 my-2 ml-3 grid min-w-0 gap-1 rounded-xl border bg-surface p-4 shadow-sm border-warning-border">
<div class="flex flex-wrap items-center gap-x-2.5 gap-y-1 text-xs"><span class="font-medium">Bot</span><span class="font-semibold text-warning">release_flow</span><span class="font-mono">copies main into next</span></div>
<h3 class="mt-0! mb-0! text-lg! font-bold"><span class="sr-only">Step 12: </span>next is updated to match main</h3>
<div>Shipping also opens a <strong>merge-back</strong> PR (copying main into next) that merges itself, so the next release starts from what users have.</div>
<div class="font-mono text-xs">merge-back PR</div>
<div class="mt-1 border-l-4 pl-3 border-warning-border"><span class="block text-xs font-bold uppercase tracking-wide text-warning">Move on when</span>The merge-back PR has merged. The next <code>bin/release cut</code> waits for it.</div>
<details class="mt-2 border-t border-border"><summary class="focus-ring cursor-pointer py-3 text-sm font-semibold text-text-body">Commands</summary>
<div class="grid gap-3 pb-2 text-sm">
<div>Shipping opens <code>merge-back/2026.11.18</code> into next and turns on auto-merge.</div>
<div class="grid justify-items-start gap-1"><code>gh pr list --base next --head merge-back/2026.11.18</code><span>Check whether it's still waiting.</span></div>
<div class="grid justify-items-start gap-1"><code>gh pr update-branch &lt;PR&gt;</code><span>If next moved before it merged. Keep it a merge commit: a squash leaves main out of next's history.</span></div>
<div class="grid justify-items-start gap-1"><code>bin/release merge-back</code><span>Opens one by hand, after an urgent fix or if shipping stopped before this step.</span></div>
</div></details>
</div></li>
<li class="m-0! grid grid-cols-[3.5rem_minmax(0,1fr)] items-center @xl:grid-cols-[15rem_minmax(0,1fr)]"><div class="relative col-start-1 row-start-1 min-h-12 self-stretch"><svg class="absolute inset-0 hidden h-full w-full overflow-visible @xl:block" fill="none" stroke="currentColor" aria-hidden="true"><g class="text-border-strong" stroke-width="1.5"><line x1="90" y1="0" x2="90" y2="50%"/></g><g class="text-border-strong" stroke-width="2" stroke-dasharray="1 6" stroke-linecap="round"><line x1="150" y1="0" x2="150" y2="50%"/></g><g class="text-text-heading" stroke-width="4" stroke-linecap="round"><line x1="210" y1="0" x2="210" y2="50%"/></g></svg></div><div class="col-start-2 row-start-1 ml-3 mt-3 font-semibold text-text-heading">The next release starts again at step 6.</div></li>
</ol></div></div>

## When a switch is off

A new fork starts with all four off. The three variables are under the
repository's Settings → Secrets and variables → Actions → Variables.

| Switch | Off, a new fork's default | Turning it on |
| --- | --- | --- |
| Approvals, set by `bin/branch-rules` | A PR merges once its tests pass, with no review at step 4. | Rerun `bin/branch-rules` without `--solo`. |
| `AUTO_RELEASE` | The release lead runs `bin/release prepare`, then `bin/release cut` (steps 6–7). | Also needs a `RELEASE_TOKEN` secret. |
| `DEPLOY_STAGING` | There's no staging. Step 8 is skipped, and step 9 checks the release branch however you test. | Needs a staging server. |
| `DEPLOY_PRODUCTION` | After step 10, run `bin/kamal deploy` from your machine. | Users get main as soon as it changes, which is why only step 10, or an urgent fix, changes main. |

[Changing the defaults](changing-the-defaults#how-changes-ship) says how to
turn each one on.

## Ask on day one

These differ from team to team, so this page can't answer them.

- **Who is our release lead?** The person who runs step 10.
- **Where is staging?** Its web address, for step 9.
- **Which switches are on?** Run `gh variable list`, or see the table above.
- **Do PRs need an approval here?** Solo repos skip step 4's review.
- **Who opens the fix when a staging check fails?** The PR's author, or
  whoever found it? For step 9.

## Urgent fix

When users can't wait for the next release. It skips staging, so keep it
small and get the release lead's OK first.

```bash
git switch -c hotfix/sign-in-loop origin/main
# fix, commit, push
gh pr create --base main
```

1. A fix PR goes straight into main. Add a changelog file as usual; the next
   release lists it.
2. Merging it deploys production when `DEPLOY_PRODUCTION` is on; otherwise
   run `bin/kamal deploy`.
3. No merge-back PR opens this time, so the release lead runs
   `bin/release merge-back` to update next to match main.

If a release branch is open, bring the fix into it as well: a branch from
main, with a PR into `release/<name>`. [Releasing: Hotfix](releasing#hotfix)
has the details.

## Words you'll hear

| Word | Meaning |
| --- | --- |
| next | The branch where merged PRs wait for a release. Nothing on it is live. |
| main | What users are running right now. |
| Release branch | A snapshot of next, named for the day, like `release/2026.11.18`. |
| Release PR | The PR from a release branch into main. Its "What ships" section lists the changes in the release. |
| Staging | A practice copy of the app on its own server, shared by the team, for checking a release before users see it. |
| Production | The real app that users see. |
| Hand checks | The numbered steps under "What the specs can't show" in your PR: where to go on staging, what to do, and what to expect. |
| Changelog file | One line in `changelog.d/` saying what your PR changes. A release gathers them all. |
| Update branch | GitHub's button that merges next into your branch so it's up to date before it can merge. |
| Lefthook | The tool that runs checks on your laptop when you commit or push. |
| CI | The bot that runs the tests on GitHub. Here it's GitHub Actions. |
| Revert | A PR that undoes another PR's change. |
| Tag | A permanent label on the commit that shipped, like `v2026.11.18`, so the team can find it or go back to it. |
| Prepare, cut, ship | The three `bin/release` commands: name the release, make its branch, send it to users. |
| Merge-back | Copying main into next after a release or an urgent fix, so the two stay the same. |
| Release lead | The person who decides when a release ships and runs `bin/release ship` (step 10). On a solo repo, that's you. |
| Kamal | The tool that copies the app to a server and swaps in the new version. |
| release_flow | The gem behind `bin/release`. |

[Releasing](releasing) has the full rules behind each step.
