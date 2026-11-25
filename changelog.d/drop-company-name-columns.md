### Removed

- The unused `company_name` columns on `invitations` and `client_accesses` are dropped (migration included); existing values are deleted. A fork deploys v2026.11.25-2 before this release, since that release stops writing the columns; deploying both at once can fail a client invite accepted mid-deploy.
