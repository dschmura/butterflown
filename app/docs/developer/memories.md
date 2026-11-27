---
title: Memories
description: How a memory and its resources are stored and posted — the one posting verb, what a new memory defaults to, and the rules the models enforce
keywords: memory memories resource resources reflection photo perspective anonymous post visibility only_me specific_people community comment reflect tag rule content warning encrypted
---

# Memories

A memory is one thing a member remembers. Its content is one or more resources: a written reflection or a photo, each from a contributor. The memory's author owns it; a resource from anyone else is a perspective.

## Posting

`Workspace#post_memory(author:, resources:, **attrs)` is the one way a memory is created. It builds the memory and every resource, credits each resource to the author, and saves them in one transaction under the workspace's row lock. It returns the memory, persisted or carrying its errors, so a form can render them. Resources arrive as plain attribute hashes (`kind:`, `body:`, `photo:`, `content_warning:`), so a controller converts its permitted params with `to_h` first.

Every resource posted this way is the author's. A perspective, a resource from another member on someone else's memory, will arrive through its own verb on `Memory`, gated by the memory's `reflect_rule`; `post_memory` keeps its promise that everything in it is the author's.

A memory refuses to save when:

- it has no resources;
- its author isn't a current member of the community;
- the community is archived, deleted or suspended (`Workspace#accepts_new_memories?`, which `MemoryPolicy#create?` asks too);
- it is anonymous and the community has `anonymous_posting` off.

An anonymous memory still records its author, because admins can reveal one.

## What a new memory starts as

| Field | Default | Choices |
| --- | --- | --- |
| `visibility` | `only_me` | `only_me`, `specific_people`, `community` |
| `comment_rule`, `reflect_rule`, `tag_rule` | `viewers` | `viewers`, `author` |
| `visible_to_guests` | false | |
| `anonymous` | false | |

The audience values avoid `private`, which would collide with Ruby's `Module#private` as an enum scope. Each choice is checked in the model and by a database constraint.

## Resources

`MemoryResource` is named apart from the template's `Resource`, which belongs to exactly one project. A written reflection needs words and carries no image; a photo needs an image (the app's `IMAGE_CONTENT_TYPES`, under 20 MB) and may carry a caption in the same column. A content warning is a short label of 60 characters or fewer.

The words are personal, so `body` is encrypted at rest.

Not yet built from the spec's data model: video, audio and document resources; the image fingerprint behind duplicate detection; a memory's date or era, place and topics.

## Kept out of the activity feed

`Memory` does not include `Trackable`. The template's activity feed is visible to the whole workspace, so a tracked memory would announce that a private memory exists. Audit rows for memories, when they come, need their own visibility rules.

## When an account is deleted

The foreign keys from `memories.author_id` and `memory_resources.contributor_id` to `users` are `on_delete: :restrict`, so an account with memories can't be deleted yet. The product's rule (shared memories stay, credited to a former member; private ones go) needs its own change; until then, refusing is the posture that loses nothing.

## Who may post, change and delete

`MemoryPolicy`: posting needs `Membership#may_post_memories?` in a community that accepts new memories. Only the author, while still a member, may change or delete their memory; admins and the owner may not. Who may see a memory is a separate question, answered by the visibility rules.
