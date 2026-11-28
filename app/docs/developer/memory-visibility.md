---
title: Memory Visibility
description: Who may see a memory — the one relation every read goes through, the rules it enforces, and the guard that keeps new reads from skipping it
keywords: visibility visible_to memory access named specific people community guest admin private only_me withdrawn deleted suspended archived policy scope show leak
---

# Memory Visibility

Who may see a memory has one answer: `Memory.visible_to(user)`. It is a relation, so it chains from `@workspace.memories` and composes with anything else a page needs. `MemoryPolicy::Scope#resolve` returns it, and `MemoryPolicy#show?` asks it with `exists?`, so the list and the page can never disagree. The decision behind this shape, and the options it beat, are in the advisory panel's record for slice 3.

## The rules

A viewer sees a memory when all of these hold:

1. The memory hasn't been deleted (`kept`).
2. Its community isn't deleted or suspended. An archived community stays readable.
3. The viewer is a current member of the memory's community. Someone who has left sees nothing there, including what they wrote.
4. The author hasn't blocked the viewer, in this community or everywhere ([Blocks](blocks)).
5. The author hasn't been removed from this community for cause, unless the memory is anonymous. This hides their other memories from everyone, admins included, until an admin's invitation brings them back ([Leaving](leaving)). Anonymous ones stay, since their vanishing at the removal would say who wrote them. A member who simply left or was removed keeps their shared memories in sight.

and at least one of these grants it:

- They wrote it.
- They were named on it (`MemoryAccess`), and it is shared beyond its author: `specific_people` or `community`. Setting a memory back to `only_me` hides it from everyone named on it, without deleting the names, so sharing it again restores them (the spec's "Sharing again"). A screen that re-shares should show the author who that brings back.
- They are tagged on one of its resources, and it is shared beyond its author ([Tags](tags)).
- It is shared with the community and they are a member or admin, or it is also opened to guests.

Admins and the owner have no override. They see a private memory only when its author names them.

Names outlive a membership. Someone who leaves sees nothing, but their names stay on the memories, so if they are invited back everything reconnects, as the spec's leaving rules ask.

In code the four grants are named constants in `Memory::Visibility` (`AUTHORED`, `NAMED`, `TAGGED`, `REACHED_THROUGH_COMMUNITY`) joined by `OR`; a new grant is a new constant in that list.

A guest is a membership with the template's `viewer` role; see [Member Presets](member-presets).

## How it reads in code

```ruby
@workspace.memories.visible_to(Current.user)          # a feed
policy_scope(@workspace.memories).find(params[:id])   # one memory, 404 when hidden
authorize @memory, :show?                              # the same answer, one record
```

Answer 404, never 403, for a memory the viewer can't see, so the response doesn't confirm it exists.

## The guard

`spec/code_smells/memories_are_read_through_visible_to_spec.rb` parses every Ruby and ERB file under `app/` and `lib/` and fails on any mention of `Memory`, `MemoryResource` or `MemoryAccess`, a `memories` or `accesses` call, or a `:memories` or `:accesses` symbol (as in `includes(:memories)`), unless it is the receiver of `visible_to` or `on_exit_page_of` (a removed member's own memories, see [Leaving](leaving)) or sits inside `policy_scope(...)`. It parses rather than greps, so a comment or a string that mentions `visible_to` doesn't satisfy it. Files that define the rule or only build new memories are on its reviewed allow-list, each with a reason. Add to that list with a reason, never to get past it.

## Proving the rules

`spec/models/memory/visibility_spec.rb` builds one world: an author with a memory at each visibility, a withdrawn one, a deleted one, thirteen kinds of viewer (including a blocked member and two tagged people) and a decoy community. It checks each viewer against the exact set they may see, so a query that returns nothing or everything fails. Removing any one clause of the relation fails at least one example. `spec/policies/memory_policy_visibility_spec.rb` checks `show?` against the scope for every viewer and memory.
