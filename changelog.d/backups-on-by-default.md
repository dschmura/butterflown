### Changed

- `config/deploy.yml` ships with backups on: `BACKUP_PATH` is set and `/srv/backups/<your_app>` is mounted, so a fork's first deploy backs up once that folder exists on the server.
