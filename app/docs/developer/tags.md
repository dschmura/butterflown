---
title: Tags
description: How people are tagged on a memory's resources — the three states, the tag setting, who may tag and remove, and how a tag grants sight of a memory
keywords: tag tags tagged pending approved unnamed typed name consent tag setting approve okay lapse 14 days visibility anonymous block
---

# Tags

A tag links one person, or a typed name, to one resource: one photo or written reflection inside a memory ([Memories](memories)). It only ever decides whether a name shows; it never hides or changes the resource. Naming someone in a reflection's words is not a tag.

## States

| State | Name shown? | How it gets there |
| --- | --- | --- |
| `pending` | No | The tagged person approves their tags (`tag_setting: "approve"`, the default) |
| `approved` | Yes | They approve it, they're okay appearing, they tagged themselves, or it's a typed name |
| `unnamed` | No, "unnamed" | They remove their name, or a pending tag goes 14 days unanswered |

`MemoryResource#tag(by:, person: nil, name: nil)` creates a tag in the right opening state and returns it, persisted or carrying its errors. The tagged person moves it with `approve!`, `unname!` and `restore!`, with no say from the author. `Tag#name_shown?` is the one answer to "show the name?": approved, and no block between tagger and tagged.

`Tag.lapse_overdue(now:)` turns pending tags past their 14 days unnamed. A recurring job to call it is not wired yet. A pending tag on a memory that is still private to its author has no expiry: the clock starts when the memory is first shared, which belongs to the sharing verb.

Typed names are encrypted at rest and grant nothing.

## What a tag refuses

- Anonymous memories carry no tags, and a memory with tags can't be made anonymous afterwards.
- A tagged account must be a current member of the community; anyone else is a typed name.
- A person and a typed name together, or neither.
- Tagging across a block, either way. It gives the same answer as for a non-member (`:not_taggable`), so a failed tag can't tell the tagger they were blocked.
- The same person twice on one resource.

## Who may tag, change and remove

`TagPolicy`:

- **Tag:** tagging is open by default, within what each member's preset allows: anyone who can see the memory and whose preset allows tagging (`may_tag?`; readers and guests can't), in the memory's own community. When the author limits tagging (`tag_rule: "author"`), only the author. Only the author may tag someone who can't already see the memory, because that widens its audience.
- **Approve, remove my name, restore:** only the tagged person.
- **Delete:** whoever added it, and the memory's author.

Because `Tag` has no `workspace_id`, `ApplicationPolicy`'s cross-workspace guard can't check it, so the policy verifies that the memory's community matches the current one itself.

## Tags and who can see the memory

A member the author tagged sees the memory, through a fourth grant in `Memory.visible_to` ([Memory Visibility](memory-visibility)). Any state grants sight, pending and unnamed included. It holds only while the memory is shared beyond its author, like being named: withdrawing to "only me" hides it from the people tagged too. Removing the tag removes the sight, because the grant is derived from the tag itself. A block still beats it.

Only the author's tags grant sight. Anyone else can only tag people who can already see the memory, so their tags add nothing; and if they granted sight, a tag made while a memory was shared with the community would hold it open after the author narrowed it. This is the narrower of two readings of the spec, logged as an open question.

Reads of tags go through `Tag.visible_to(user)`, which keeps tags on memories the viewer can't see out of lists such as My tags; the read guard covers `Tag` and `tags` too. It filters by memory, not by state, so pending and unnamed tags come back with their rows: anything that shows a name asks `name_shown?`.

Not built yet: the record that stops anyone but the author re-tagging a person the author removed, the change history, and notices and digests.
