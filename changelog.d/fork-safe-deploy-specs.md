### Fixed

- A fork that edits `config/deploy.yml` as the quickstart says no longer fails four deploy-file specs: they bring their own `deploy.yml` or check what the guide's command is for, and only the two checks of the template's untouched files are `:template_only`.
