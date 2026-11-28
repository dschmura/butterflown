---
title: Leaving
description: What happens when someone leaves a community or an admin removes them — how it is recorded, how their memories are credited, what is held and purged, the exit page, coming back, and deleting an account after a 30-day hold
keywords: leave leaving left removed removal former member name removed remove my name departure purge 90 days exit page rejoin reconnect delete account deletion 30 days hold cancel tombstone
---

# Leaving

When someone goes from a community, the memories they shared stay with it. This page covers leaving, removal by an admin, removal for cause and deleting an account.

## How a departure is recorded

The template ends a membership one way, `Membership#deactivate!(removed_by:)`, and keeps the row with a `discarded_at` ([Membership lifecycle](membership-lifecycle)). Two columns record how it ended:

| Column | Values | Set by |
| --- | --- | --- |
| `departure` | `left`, `removed`, `removed_for_cause`; null while a member | Every deactivation: `left` when the member ended it themselves, `removed` otherwise; `removed_for_cause` only through `remove_for_cause!` |
| `name_removed` | true or false | `Membership#leave!(remove_name: true)` |

Because the departure is worked out on every deactivation, the template's own leave and remove screens record it with no change. `leave!` adds only the name choice. The database refuses a departure on a row that is still a member.

Coming back (`reactivate!`) clears both, so a returning member is credited by name again.

The activity feed, which the whole community reads, records neither column. A line saying who removed their name would point back at the memories that just lost it, and how someone left is not the community's business.

## How their memories are credited

`Memory#credit` and `MemoryResource#credit` return a `Memory::Credit`, the one answer to "whose is this?":

| Situation | `name` | `former_member?` |
| --- | --- | --- |
| A member | Their name | false |
| Left or removed | Their name | true |
| Left and removed their name (not the same as anonymous) | nil | true |
| An anonymous memory, or its author's own resource on one | nil | false |

An anonymous credit never carries the former-member label, since that label would say something about who wrote it. Someone else's perspective on an anonymous memory is credited normally: the anonymity belongs to the memory's author.

## What happens to their memories

- **Shared memories stay.** `community` and `specific_people` memories keep their audience. The visibility rules never asked whether the author is still a member ([Memory visibility](memory-visibility)).
- **Private memories are held for 90 days, then purged.** `Memory.purge_left_behind(now:)` destroys "only me" memories, including ones the author had already deleted, whose author left or was removed more than 90 days ago, with their resources and tags. `LeftBehindMemoriesSweepJob` calls it daily.
- **The departing person loses sight** of everything in that community, because every grant needs them to be a member.
- **Pending tags naming them become unnamed.** Approved tags stay approved. Tags elsewhere are untouched.

## The exit page

`Memory.on_exit_page_of(user)` is a former member's own memories, of any audience, for 90 days after they left or were removed: memories they haven't already deleted, in a community that still exists. `MemoryPolicy#destroy?` lets them delete these, and nothing else.

It is the one read besides `visible_to` that the memory read guard allows.

## Coming back

Both rules read the membership as it is now, not a copy taken when the person left. Someone invited back inside the 90 days finds their private memories where they left them, and their access returns with the membership. Tags that became unnamed stay unnamed until they restore them.

## Removal for cause

`Membership#remove_for_cause!(by:, reason:)` ends the membership as `removed_for_cause`. `MembershipPolicy#remove_for_cause?` allows it for whoever may manage members, on someone else who is still a member or has already left or been removed. Marking someone who already went keeps leaving first, or asking to delete the account, from dodging it. Everything above still applies, with these additions:

- **A reason is required.** It goes in the audit log as a `membership.removed_for_cause` row only admins see, and nowhere else. The community's feed shows the person went, not why.
- **The memories with their name on are hidden from everyone, admins included,** in every audience ([Memory visibility](memory-visibility), rule 5). Anonymous ones stay where they were: if they vanished at the removal, the timing would say who wrote them. Their private memories are purged after 90 days like anyone's. The shared ones are held, not purged.
- **They can download but not delete.** Their memories are on their exit page for 90 days, but `MemoryPolicy#destroy?` refuses them. An admin (anyone who may manage members) may delete the hidden ones instead, but not an anonymous one, where the offer alone would say who wrote it. Finding them belongs to the moderation screens, since `visible_to` hides them from admins too.
- **Only one of this community's admins brings them back,** by reactivating them or through an invitation they sent. A self-join, or an invitation from anyone else (a project editor, say), is refused. Pending invitations addressed to them are revoked at removal, so an old one can't be used. Coming back clears the cause and their memories reappear.
- **An admin can't remove someone whose role they couldn't grant,** such as the owner.

## Deleting an account

Deleting an account follows the same rule in every community at once, after a 30-day hold. The users row then stays as a tombstone, because shared memories, approved tags and the tags the person made all point at it; destroying it would cascade those tags away. The model refuses to destroy a deleted account.

### Asking: `User#request_deletion!(remove_name: false)`

1. **They leave every community now** through `Membership#leave!`, so pending tags unname and shared memories are credited exactly as on leaving. With `remove_name: true` their name comes off those memories now too. A removal for cause stays as it was, so those memories stay hidden.
2. **They are signed out everywhere.** Their email, password, passkeys and OAuth links stay, so they can sign in to cancel.
3. **`deletion_requested_at` is stamped,** with the name choice in `deletion_removes_name`. Asking again doesn't restart the clock.

While they are a community's only owner, it is refused with `Membership::LastOwner` and nothing changes. They choose a successor first; if the community has another owner, it goes ahead.

### Cancelling: `User#cancel_deletion!`

Signing in during the hold cancels it (`Authenticatable#start_new_session_for`, after the session exists, so a request landing meanwhile is still seen). They are reactivated in every community the request took them out of, credited by name again, as anyone coming back inside the 90 days is. Skipped: a community they had left before asking, one that was deleted, suspended or filled up during the hold, and one where an admin removed them, for cause or not, during the hold.

### Completing: `User#complete_deletion!(now:)`

`AccountDeletionSweepJob` runs daily over `User.deletion_due`, the accounts whose 30 days are up. Each one is re-checked under its row lock, so a cancel that lands first wins. In one transaction:

1. **Leave again** any community an admin brought them back to during the hold. With the name choice, communities they had already left lose their name too.
2. **Delete their private memories** in every community, with their resources and photos.
3. **Scrub the account.**
   - Sessions, OAuth links, passkeys, challenges, notifications, preferences and the picture go.
   - So does what the account was granted: operator status (revoked, with its audit row), client access, and being named on memories.
   - Pending invitations and magic links sent to the old email are revoked or deleted, so the address can't later join a new account to what this one left.
   - The email becomes a random placeholder, unrelated to the old address. No sign-in route (password, magic link, reset, passkey, OAuth) finds it, and the old address can register a new account.
   - The password goes. The name stays for the credit unless they removed it, in which case their personal workspace's name goes too.
   - `deleted_at` is stamped.

A deleted account also answers `suspended?` true. The template's sign-in and session guards ask exactly that, so a sign-in already under way when the account is deleted can't land.

If an admin made them a community's only owner during the hold, completing raises `Membership::LastOwner`; the sweep reports it and leaves the account pending for the next run. Their personal workspace stays with the tombstone, unreachable.

The advisory panel's reasoning, and why the row isn't deleted, is in the decisions record.
