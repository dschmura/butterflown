---
title: Backups and Restore
description: Back up the database and uploaded files every day to a folder or a bucket, check that the backups run, and restore from one.
keywords: backup restore database copy BACKUP_PATH OBJECT_STORAGE_BUCKET BACKUP_SCHEDULE bucket s3 vacuum sqlite production.key backup:now backup:status backup:restore disaster recovery
---

# Back up the database

Once a day, `DatabaseBackupJob` makes one file holding the database and the
uploaded files, and stores it in a folder or a bucket. The database copy comes
from SQLite's own `VACUUM INTO`, which takes a consistent copy while the app
keeps writing, and is checked with SQLite's integrity check before it's kept.

Production boots without a destination, so an idea you're still testing can
ship first. Until you set one, the boot log and every scheduled run say
"Backups are off", and `backup:status` says the same. Set one before real
people put real data in.

- **Backed up:** `storage/production.sqlite3`, which holds every account,
  workspace and record, and the uploaded files beside it on the storage volume.
- **Not needed:** the cache and cable databases, which rebuild themselves.
- **An accepted loss:** the queue database. Jobs waiting at the moment of a
  disaster are lost; recurring ones run again on schedule.
- **How much you can lose:** up to a day. `BACKUP_SCHEDULE` takes any schedule
  Solid Queue reads, such as `every hour` or `every day at 4am`, under
  `env.clear` in `config/deploy.yml`. Each backup holds every uploaded file, so
  a frequent schedule multiplies the space a large upload folder takes.
- **The key that opens them:** a backup decrypts only with `production.key`,
  so keep that key in your password manager, off the server.

## Start with a folder

Set `BACKUP_PATH` to a folder the container can write to. Where that folder
lives decides what the backups survive:

| The folder is on | It survives | It doesn't survive |
| --- | --- | --- |
| The server's own disk, such as `/srv/backups` | a bad migration, a deleted record | a dead disk |
| A second drive, or a NAS on your network | a dead server disk | a fire, flood or theft that takes the site |
| A bucket elsewhere ([next section](#move-to-a-bucket-when-the-data-matters)) | losing the whole site | |

On the server, make the folder and let the container's user, uid 1000, write
to it. For a NAS or a drive, mount it there first so it comes back at boot
(NFS or SMB in `/etc/fstab`).

```bash
ssh root@<server-ip> "mkdir -p /srv/backups && chown 1000:1000 /srv/backups"
```

Then pass it into the container and point `BACKUP_PATH` at it in
`config/deploy.yml`:

```yaml
volumes:
  - "modelrails_base_storage:/rails/storage"
  - "/srv/backups:/backups"

env:
  clear:
    BACKUP_PATH: /backups
```

- **Retention:** after each backup the app deletes that deployment's backups
  older than `BACKUP_RETENTION_DAYS`, 30 unless you set it. That means the
  server can delete its own backups, so on a NAS turn on its snapshots, which
  the server can't reach, against someone who breaks in.
- **On the database's disk:** when the folder shares a disk with the database,
  every backup logs a warning and `backup:status` repeats it. The backup still
  runs. That's expected for `/srv/backups`. For a NAS it means the drive isn't
  mounted, and the backups are landing on the server's own disk.

The backups sit in the folder as ordinary files, under `backups/<deployment>/`,
so you can copy them anywhere by hand.

## Move to a bucket when the data matters

A bucket with a different company from your server's survives losing the
whole site. It costs a little each month, which is why it's the second step,
not the first. Remove `BACKUP_PATH`, name the bucket under `env.clear`, and put
its key in `bin/rails credentials:edit --environment production`:

```yaml
env:
  clear:
    OBJECT_STORAGE_BUCKET: yourapp-backups
    OBJECT_STORAGE_REGION: eu-central-003
    OBJECT_STORAGE_ENDPOINT: https://s3.eu-central-003.backblazeb2.com
```

```yaml
object_storage:
  access_key_id: ...
  secret_access_key: ...
```

Production refuses to boot with a bucket that's missing its region or key, or
with both `BACKUP_PATH` and a bucket set.

| Provider | `OBJECT_STORAGE_REGION` | `OBJECT_STORAGE_ENDPOINT` |
| --- | --- | --- |
| Backblaze B2 | the bucket's region, such as `eu-central-003` | `https://s3.<region>.backblazeb2.com` |
| Cloudflare R2 | `auto` | `https://<account-id>.r2.cloudflarestorage.com` |
| Hetzner Object Storage | the location, such as `fsn1` | `https://<location>.your-objectstorage.com` |
| Amazon S3 | the bucket's region, such as `eu-central-1` | leave it unset |

A server you run yourself, such as Garage, usually also needs
`OBJECT_STORAGE_FORCE_PATH_STYLE: "true"`.

- **The key:** scope it as narrowly as the provider allows, to this one bucket
  and, where the provider can, without permission to delete. The app only
  uploads and downloads, so a key taken from the server can't erase the
  history.
- **Retention:** give the bucket a lifecycle rule that deletes objects under
  `backups/` after 30 days, or whatever window you want. The bucket deletes old
  backups, not the app, which is what lets the key go without delete
  permission.

Each backup is `backups/<deployment>/<time>.tar.gz`, and
`backups/<deployment>/latest` names the newest. The deployment is
`production`, or the credentials a deploy runs on (`staging`), so staging can
share the bucket, or the folder, without touching production's backups.

## Check it runs

`bin/kamal app exec "bin/rails backup:status"` names the latest backup, and
its time should be within your schedule, a day by default. A backup that fails
is a failed `DatabaseBackupJob`; the next scheduled run tries again.

## Restore

A restore replaces the live database, so the app stops for it:

```bash
bin/kamal app version                           # note the running version
bin/kamal app stop
bin/kamal app exec "bin/rails backup:restore"   # the latest backup
bin/kamal app start --version <that version>
```

`app start` on its own starts your checkout's commit, and fails with "did
the container boot?" once your branch has moved past what's deployed.

To go further back, name a backup from the folder or the bucket's listing:

```bash
bin/kamal app exec "bin/rails 'backup:restore[backups/production/2026-11-01T020005Z.tar.gz]'"
```

The restore checks the backup's database with SQLite's integrity check before
it touches anything. It then brings back any uploaded file that's missing, and
moves the current database aside, with its WAL files, as
`production.sqlite3.before-restore-<time>`, so a restore can itself be undone.
Delete that file once you're sure.

The same restore moves an app to a new server: deploy there, copy a backup
into its folder under the same name, and restore it by that name.

**Practise a restore before you need one.** Run it once on staging or a
throwaway server, and write down the date. A backup nobody has restored is
a hope, not a backup.
