---
title: Moderation
description: Removal requests, flags, block reports and the block signal, the moderation queue, admin tools, urgent hides, and how moderation routes around an admin with a block involved
keywords: moderation removal request remove change keep hide urgent relay anonymous admin block routing audit log 3 days flag report block report signal queue reveal anonymous author history clear removed for cause
---

# Moderation

Members moderate their own space first, by blocking and by asking for removal. Admins step in on requests, flags and urgent cases. This page covers the rules in the models; the screens come later.

## Who handles an item

`Moderation.admins_for(workspace, involving:)` answers "which admins hear about this?" for anything involving some members:

- Every current admin of the community, owner included (anyone whose role may manage members).
- **Not an admin who is part of it.** An admin never handles a request they made or one about their own resource.
- **Not an admin with a block involved.** An admin with a block either way with anyone involved, in this community or an everywhere block, is passed over while another admin is clear.
- **Unless no other admin is clear.** Then the blocked admins handle it, as the spec allows.

If the only admin is part of it, nobody handles it.

## Removal requests

`RemovalRequest` is one member asking for one resource to be removed or changed, with a reason (encrypted at rest).

- **Who can ask:** any member who can see the resource, except its author, who changes or removes it themselves. One request per person per resource.
- **Where it goes:** to the author, the admins, or both. A request about an anonymous memory's own resource always goes to the admins. Its author hears of it only when an admin relays it (`relay!`), so the requester never learns who wrote it.
- **The requester stops seeing the resource at once,** and for good, whatever the answer. Everyone else still sees it, with no public label.
- **"Removal requested"** shows on the resource for its author (when the request reaches them) and for the admins handling it, while it is open: `MemoryResource#removal_requested_for?(user)`.
- **Who answers:** the admins handling it, whenever it reaches the admins; the author, when it went only to them. `RemovalRequestPolicy#decide?`.
- **The clock:** `due_at` is 3 days after asking. `RemovalRequest.overdue` lists open requests past it.
- **Outcomes:** `removed`, `changed` or `kept`, through `decide!(outcome, by:)`, once. Removed hides the resource. Kept or changed brings back a resource hidden urgently, unless another request on it was answered removed.
- **Urgent hide:** an admin handling the request can hide the resource at once with `hide_now!(by:)`.
- **What the requester sees:** their own requests and outcomes, `RemovalRequest.made_by(user)`.

A hidden resource (`memory_resources.hidden_at`) is out of everyone's sight but its author's, who can still download it.

## Flags

`Flag` is a member asking the admins to look at a memory or one of its resources, with a reason (encrypted). Comments don't exist yet; they will be flaggable too.

- **Who can flag:** any member who can see it, except its author. Once per person per item.
- **The flagger keeps seeing it.** Unlike a removal request, a flag takes nothing out of sight.
- **Who handles it:** `Moderation.admins_for`, with the flagger and the item's author involved. On an anonymous memory the author is still involved, so a blocked admin is routed around without anyone being told who wrote it.
- **Urgent hide:** `hide_now!(by:)` hides the flagged resource, or every resource of a flagged memory, from everyone but its author.
- **Resolving:** `resolve!(outcome, by:)`, once, with `acted` or `dismissed`. Dismissing brings back what an urgent hide took, unless a removal request on it was answered removed.

## Block reports

After blocking, the blocker may tell the admins: `Block#report!(reason:, note:)`. The reason is one of harassment, unwanted contact, something they posted, or other; the note is optional and encrypted. Without a report no reason is stored and admins never learn who blocked whom. A report outlives the block, since the admins were told. A handling admin closes it with `resolve!(by:)`.

## The moderation queue

`Moderation::Queue.new(workspace, admin)` is what one admin has to handle in one community, each list holding only items routed to them:

- `removal_requests`: open requests that reach the admins.
- `flags` and `block_reports`: open ones.
- `block_signals`: each member blocked by three or more current members of this community (blocks made here, or everywhere blocks), as a person and a count, never the names of who blocked. A signal is routed like any item with that person involved, so it is never shown to the admin it is about, and a signal about the only admin isn't shown at all.

## Admin tools

- **Revealing an anonymous author:** `Memory#reveal_author_to!(admin, reason:)` returns the author and records an `AuthorReveal` with the reason (encrypted). `MemoryPolicy#reveal_author?` allows any admin, on an anonymous memory. Every reveal is logged with who, when and which memory.
- **Clearing the memories of someone removed for cause:** `Membership#clear_memories_for_cause!(by:)` deletes every memory they posted in this community, anonymous ones too, without listing which, so it never points at who wrote an anonymous one. It is logged with a count. `MembershipPolicy#clear_memories_for_cause?` allows any admin, only after a removal for cause. Deleting one named memory of theirs stays as before (`MemoryPolicy#destroy?`).
- **A member's moderation history:** `Moderation::History.new(membership)` holds the flags against what they posted, the removal requests upheld against their resources (removed or changed), block reports about them, and how many members block them once it reaches three. What they posted anonymously is left out, since counting it would say who wrote it. `MembershipPolicy#moderation_history?` allows any admin, never on their own record.

## What is logged

Decisions, urgent hides, relays, resolutions, author reveals and clearings are written to the activity log at admin visibility, with who did it and the outcome, never the reason or note. Raising an item is not logged: the item itself is the record.

## Reading resources

`MemoryResource.visible_to(user)` is whoever sees the memory, less hidden resources (except their author's own) and resources the viewer asked to remove. The memory read guard allows it alongside `Memory.visible_to`.
