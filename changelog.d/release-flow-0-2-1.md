### Fixed

- `bin/release prepare` names a fork's first release instead of crashing when its `CHANGELOG.md` holds only an empty `## [Unreleased]`, and writes the changelog with a single trailing newline (release_flow 0.2.1).
