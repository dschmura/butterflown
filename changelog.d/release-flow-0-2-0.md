### Changed

- A release PR merged on GitHub now ships by itself: with `AUTO_RELEASE` on, the release workflow publishes its tag and merges `main` back into `next` (release_flow 0.2.0). Without it, `bin/release cut` names the `ship` command that finishes the release.
