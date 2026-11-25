---
title: Share with a Client
description: Give someone outside your team a read-only view of chosen documents in one project — turn on client access, share documents, and invite the client.
keywords: clientside client access external share client outside company invite read-only document resource
---

# Share with a Client

Clientside lets a team share selected project resources with an external client, who sees a focused, read-only area and never joins the workspace. How it works underneath is on [Clientside](/docs/developer/clientside) in the Developer Guide.

## Enabling Clientside on a project

Each project has a `clientside_enabled` boolean (default `false`). The project's creator and workspace members who can manage members (`ProjectPolicy#manage_clientside?`) toggle it via `Workspaces::Projects::ClientsidesController` (edit/update), reachable at the project's Clientside settings page.

## Sharing resources with a client

`Resource` gains a `shared_with_client` boolean. The team checks "Share with the client side" on a resource's edit form (the checkbox is only shown when Clientside is enabled on the project).

- `Project#client_visible_resources` — `resources.kept.published.where(shared_with_client: true).positioned`

A resource must be both shared **and** published to appear in the client area.

## Inviting a client

`Invitation` supports a client variant. A client invite is identified by a non-blank `company_name`:

- `Invitation#client_invite?` — `company_name.present?`
- Role is not required on a client invite (`validates :role, presence: true, unless: :client_invite?`)
- `Invitation.invite_client!(project:, email:, company_name:, invited_by:)` creates the invitation and queues `InvitationMailer#invite_client`

Client invitations are sent from `Workspaces::Projects::ClientInvitationsController` (`new`/`create`), which allows the same people (`ProjectPolicy#manage_clientside?`) and verifies Clientside is enabled before rendering.

### Acceptance

**Existing user** accepting a client invite → one-click → lands in the client area.

**New email** → sets up a login → client area.

## Security boundary

- A client can only see resources on a specific project they have been explicitly invited to.
- Revoking access (discarding the `ClientAccess`) immediately stops the client from reaching that project — `set_client_project` finds no kept access and redirects.
- Disabling Clientside on a project (`clientside_enabled: false`) blocks all client access to that project via `ensure_clientside_enabled`, even if `ClientAccess` records still exist.
- Clients operate under the `clientside` layout with no workspace context — workspace data, member lists, and workspace settings are never in scope.

See [Project Collaboration](/docs/user/projects) for the workspace-side project model.
