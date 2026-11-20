### Changed

- Specs share `add_member`, `sign_in_as_owner_of`, `permit_open_join_links` and `axe_options` from `spec/support`, plus `:viewer` membership and `:operator` user traits. A fork whose own specs define one of those names fails `spec_helpers_are_defined_once_spec` after `bin/sync`; delete the local copy and call the shared one.
- The membership factory builds its roles with `Role.system_default!`, so a plain `rspec` run (no seeds) gives a factory member the real member role's `manage_projects`, as the seeded suite and CI already did.
