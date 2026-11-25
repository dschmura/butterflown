---
title: Share with a Client
description: Give someone outside your team a read-only view of chosen documents in one project — turn on client access, share documents, and invite the client.
keywords: clientside client access external share client outside company invite read-only document resource
---

# Share with a Client

A client is someone outside your team, such as a customer or a contractor, who should see some of a project's documents and nothing else. They get a read-only view of the documents you share with them, in that one project. They don't join your workspace and don't take a member seat.

How this works underneath is on [Clientside](/docs/developer/clientside) in the Developer Guide.

## Who can do this

The person who created the project can turn on client access and invite clients. So can a workspace Owner or Admin who is a member of the project.

Sharing a document is done by whoever can edit it: the person who wrote it, or the project's creator.

## 1. Turn on client access

1. Open the project and choose **Client access**.
2. Tick **Turn on Clientside for this project**, then choose **Save**.

## 2. Choose what the client sees

A client sees only the documents you both share and publish.

1. In the project, open **Docs & Files** and open the document.
2. Choose **Edit**.
3. Tick **Share with the client side**. The box appears only once client access is on.
4. Set **Status** to **Published**. A draft stays hidden even when it's shared.
5. Choose **Save changes**.

Do this for each document the client should see.

## 3. Invite the client

1. Open the project's **Client access** page and choose **Invite a client**.
2. Enter their **Client email** and **Their company**, then choose **Send client invite**.

The client gets an email with a **View the invitation** button. The link works for 7 days, and only for the email address you sent it to. Someone who already has an account accepts in one click; anyone else sets up a sign-in first.

## What the client sees

Once they accept, the client lands on the project's own page, which lists the documents you shared and published under **Shared with you**. A client of more than one project finds each of them on their **Shared with you** list. They can read the documents but not change them, and they never see your workspace's members, other projects or settings.

## Stop sharing

- **One document:** untick **Share with the client side**, or set its **Status** back to **Draft**.
- **Every client on the project:** on **Client access**, untick **Turn on Clientside for this project** and choose **Save**. If you turn it back on later, clients you invited before can see the shared documents again.

There's no way yet to remove one client while keeping the others.

**Related:** [Project Collaboration](/docs/user/projects) · [Accept an Invitation](/docs/user/invitations)
