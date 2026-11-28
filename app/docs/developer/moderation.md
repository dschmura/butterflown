---
title: Moderation
description: Removal requests, who answers them, urgent hides, and how moderation routes around an admin with a block involved
keywords: moderation removal request remove change keep hide urgent relay anonymous admin block routing audit log 3 days
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

## What is logged

Decisions, urgent hides and relays are written to the activity log at admin visibility, with who did it and the outcome, never the reason. Asking is not logged: the request itself is the record.

## Reading resources

`MemoryResource.visible_to(user)` is whoever sees the memory, less hidden resources (except their author's own) and resources the viewer asked to remove. The memory read guard allows it alongside `Memory.visible_to`.
