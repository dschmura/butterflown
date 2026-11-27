---
title: Member Presets
description: What a community member may do — the contributor, participant and reader presets, who they govern, and where the rules live
keywords: preset contributor participant reader guest member capabilities post reflect comment tag collections suggest invites default override
---

# Member Presets

A community has four roles: owner, admin, member and guest. Members come in three presets, which decide what they may add to the community. Everyone can read what is shared with them; presets are about contributing.

| Preset | Post memories | Reflect | Comment | Tag | Create collections | Suggest invites |
| --- | --- | --- | --- | --- | --- | --- |
| Contributor | yes | yes | yes | yes | yes | yes |
| Participant | no | yes | yes | yes | no | yes |
| Reader | no | no | no | no | no | no |

## Who presets govern

Only members. Admins and the owner act as contributors whatever their row's `preset` column holds, and a guest may do none of it. A guest is a membership with the template's `viewer` role; the product calls it a guest. A member who has left may do nothing.

Every preset keeps the personal protections: managing your own tags, blocking, flagging, requesting removal and downloading your own memories. Those are not preset capabilities and are never gated on them.

## Where the rules live

- `Membership::Preset` holds the table above and answers `may_post_memories?`, `may_reflect?`, `may_comment?`, `may_tag?`, `may_create_collections?` and `may_suggest_invites?`. Callers ask these; nothing compares preset names. It also answers `guest?` and `admin?`; the owner holds the admin permissions too, so `admin?` is true for the owner.
- `memberships.preset` and `workspaces.default_member_preset` each carry a database check that admits only the three names.
- A new membership takes its community's `default_member_preset` unless one is chosen when it is created. The column's own default exists only so the column can be `NOT NULL`.
- `MembershipPolicy#change_preset?` lets an admin or the owner move one member to another preset. It refuses admins, the owner, guests and members who have left, since presets don't govern them.
- The community default is a workspace setting, so `WorkspacePolicy#update?` decides who changes it: the owner.

## The audit trail

A preset change is a privilege change, like a role change. `Trackable` records it as `membership.updated` with the before and after names, and the membership routes it to the admin-only feed. Pinned by `spec/models/membership/preset_spec.rb`.
