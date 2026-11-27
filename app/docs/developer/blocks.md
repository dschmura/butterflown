---
title: Blocks
description: How one member blocks another — what a block hides, where it applies, and why nobody else ever sees it
keywords: block blocks blocker blocked everywhere silent feed hide visibility memory moderation unblock
---

# Blocks

A member can block another member, guest or admin in their community. A block is one step, asks for no reason, and is silent: the blocked person is never told, and admins never see who blocked whom.

## What a block does

When A blocks B:

- B can't see A's memories, even ones B was named on. The block is a clause in `Memory.visible_to` ([Memory Visibility](memory-visibility)) and beats every grant.
- A's feed hides B's memories: `hiding_authors_blocked_by(user)`, chained after `visible_to`. Only the feed hides them. Elsewhere the spec collapses B's content for A rather than removing it, so `visible_to` alone still returns B's memories to A.
- B's anonymous memories stay in A's feed. Otherwise blocking someone and watching which anonymous memories vanish would reveal who wrote them; blocks are free, silent and reversible, so that would unmask every anonymous author in turn.
- Nothing changes for anyone else. B's memories stay visible to the rest of the community.

Tags are off both ways between them, and existing tags read as unnamed; that arrives with tags.

## Where a block applies

In the community where it was made. With `everywhere`, it applies in every community they share, including ones either joins later.

## Who can see a block

Only the blocker. `BlockPolicy` lets any current member create a block for themselves, and lets only its blocker see, widen to everywhere, or lift it; admins and the owner are refused. Seeing and lifting don't depend on still being a member, so someone who has left the community where they made a block can still lift it. `BlockPolicy::Scope` returns only the viewer's own blocks. `Block` is not `Trackable`, because the activity feed would tell the community.

## Not yet built, in the order to build them

1. **The moderation exemption.** A member who blocks the only admin hides their content from that admin. Moderation must read flagged content through its own sanctioned path, scoped to items in the queue, never through `visible_to` with the block in it. Until it exists nothing is hidden from oversight that oversight could otherwise see, because there is no moderation path at all.
2. **The optional report and the pattern signal.** The report goes to the queue with the blocker's name; the signal shows a count of three or more blockers, never their names, and never to the admin it is about.
3. **The private prompt** when a blocked person turns up in another community, and tags between them going unnamed (with tags).
