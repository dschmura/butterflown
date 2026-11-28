---
title: Leaving
description: What happens when someone leaves a community or an admin removes them — how it is recorded, how their memories are credited, what is held and purged, the exit page, and coming back
keywords: leave leaving left removed removal former member name removed remove my name departure purge 90 days exit page rejoin reconnect
---

# Leaving

When someone goes from a community, the memories they shared stay with it. This page covers leaving and removal by an admin. Removal for cause and account deletion are not built yet; each adds rules of its own.

## How a departure is recorded

The template ends a membership one way, `Membership#deactivate!(removed_by:)`, and keeps the row with a `discarded_at` ([Membership lifecycle](membership-lifecycle)). Two columns record how it ended:

| Column | Values | Set by |
| --- | --- | --- |
| `departure` | `left`, `removed`; null while a member | Every deactivation: `left` when the member ended it themselves, `removed` otherwise |
| `name_removed` | true or false | `Membership#leave!(remove_name: true)` |

Removal for cause will add a third value with its own rules.

Because the departure is worked out on every deactivation, the template's own leave and remove screens record it with no change. `leave!` adds only the name choice. The database refuses a departure on a row that is still a member.

Coming back (`reactivate!`) clears both, so a returning member is credited by name again.

The activity feed, which the whole community reads, records neither column. A line saying who removed their name would point back at the memories that just lost it, and how someone left is not the community's business.

Memberships that ended before these columns existed have no departure. They get no exit page and their private memories are not purged: the safe gap, logged as a question.

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
- **Private memories are held for 90 days, then purged.** `Memory.purge_left_behind(now:)` destroys "only me" memories, including ones the author had already deleted, whose author left or was removed more than 90 days ago, with their resources and tags. The recurring job to call it is not wired yet.
- **The departing person loses sight** of everything in that community, because every grant needs them to be a member.
- **Pending tags naming them become unnamed.** Approved tags stay approved. Tags elsewhere are untouched.

## The exit page

`Memory.on_exit_page_of(user)` is a removed member's own memories, of any audience, for 90 days after an admin removed them: memories they haven't already deleted, in a community that still exists. `MemoryPolicy#destroy?` lets them delete these, and nothing else. Someone who left on their own has no exit page; the leave screen offers their download before they go.

It is the one read besides `visible_to` that the memory read guard allows.

## Coming back

Both rules read the membership as it is now, not a copy taken when the person left. Someone invited back inside the 90 days finds their private memories where they left them, and their access returns with the membership. Tags that became unnamed stay unnamed until they restore them.
