# rpi-gitops

GitOps-managed container services for my Raspberry Pi.

AI assistants should start with [AGENTS.md](AGENTS.md), which points to the
deployment specification and verified operational lessons.

## Repository layout

Each directory is an independent Compose project:

```text
arcane/             Arcane dashboard and Git deployment manager
mpd/                MPD audio server
mympd/              myMPD web interface
music-assistant/    Music Assistant
newt/               Newt tunnel client
```

Compose project names are set explicitly so moving these files does not
silently rename Docker networks. In particular, MPD's project name is `mpd`,
which keeps its default network named `mpd_default`; myMPD joins that network
to reach MPD. Newt joins myMPD's `mympd_default` network to reach myMPD.
Deploy myMPD once before Newt so that external network exists.

## Secrets and local settings

Never commit `.env` files, credentials, or private keys. Each project that
needs local settings has an `.env.example` template. For manual Compose
deployment, copy the template to `.env` and replace placeholders on the host.
For Arcane Git Pull projects, configure the corresponding variables in the
project's local environment settings instead. Keep persistent application
data outside this repository.

The Newt `.env` contains its endpoint and credentials. Arcane's `.env` only
holds its encryption key.

## Arcane bootstrap

Arcane is included for reproducibility, but bootstrap it manually before
configuring Arcane to deploy the other projects:

1. Copy this repository's Arcane Compose file and `.env.example` to
   `$HOME/arcane`. No full Git checkout is needed on the Pi.
2. In `$HOME/arcane`, copy `.env.example` to `.env`.
3. Generate an encryption key with `openssl rand -hex 32`, then set it as
   `ENCRYPTION_KEY` in the local `.env`.
4. Arcane uses `$HOME/containers/arcane` for its application data and
   `$HOME/gitops` as its projects directory. This is an Arcane-managed workspace,
   not a Git checkout. Compose expands `$HOME` from the
   environment of the process doing deployment. For Arcane Git Sync, set
   `HOME` to the Pi user's home directory (for example `/home/example`) through
   **Customization -> Variables**, scoped to the Pi environment. Arcane writes
   this to `.env.global`; project-local `.env` values override it. Arcane may
   not inherit the Pi host's `HOME`.
   Set `APP_URL` in the local `arcane/.env` to the address you use to open
   the dashboard.
5. Create the data directory and give it to the configured Arcane user:

   ```sh
   sudo mkdir -p "$HOME/containers/arcane" "$HOME/gitops"
   sudo chown 1000:1000 "$HOME/containers/arcane" "$HOME/gitops"
   ```

6. From `$HOME/arcane`, start Arcane with `docker compose up -d`.
7. Sign in, change the initial password, and connect this repository using
   read-only Git credentials.
8. Create a **Pull** sync for each application project. Add Newt's endpoint
   and credentials to its local environment settings, using `newt/.env.example`
   as the variable-name reference. Enable automatic sync only after verifying
   the initial deployment and environment settings.

Keep the Arcane dashboard reachable only from a trusted LAN or VPN. Access to
the Docker socket gives Arcane administrative control of the host.

## Deploying projects

From a project directory, Docker Compose can validate and start a stack:

```sh
docker compose config --quiet
docker compose up -d
```

For GitOps, configure each application directory as its own Arcane Git Pull
project. Do not have Arcane and another manager independently deploy the same
Compose project.

Bind mounts require a nonempty `HOME`: Compose fails with
`HOME must be configured` if it is missing or empty, rather than creating
data directories at the filesystem root. This guard does not validate that
the configured home directory is correct.

## Container log rotation

All five services use Docker's `json-file` driver, rotating at `10m` with
three files retained per container (roughly 30 MB each, 150 MB for the stack).
This only bounds stdout/stderr logs, not application-managed log files.
View logs through Arcane or `docker logs`.

The settings take effect when containers are recreated, not merely restarted.
After syncing the changes, recreate each application through Arcane. Update
the manually managed Compose file in `$HOME/arcane` separately, validate it,
and run `docker compose up -d --pull never` there to apply Arcane's logging
configuration without intentionally updating its image. Persistent bind
mounts are retained; do not select options that delete or recreate data volumes.

## Recovery after a disk failure

Git restores configuration, not application state. Before a failure, keep
encrypted off-device backups of:

- `$HOME/containers`, including Arcane's database and application state.
- `$HOME/arcane`, including its local `.env` and original encryption key.
- Local environment files under `$HOME/gitops`, including Newt's credentials
  and `.env.global`. Backing up the whole workspace also preserves local
  project files.
- Git repository credentials and recovery information in a password manager.

For a simple consistent backup, stop the applications and Arcane before
copying their data, then restart them. Do not copy live SQLite database files
as if they were a consistent backup. Preserve numeric ownership, permissions,
and all database sidecar files when backing up stopped services. Backup
automation is not configured by these Compose files; test restoration.

### Restore the host and Arcane

1. Install a supported 64-bit OS and Docker Engine with the Compose plugin.
   Recreate the service user with the original UID/GID where possible; these
   Compose files expect `1000:1000` and MPD uses audio group ID `29`.
   Verify sound devices and group IDs on the replacement host.
2. Before starting any containers, restore `$HOME/containers`, `$HOME/arcane`,
   and the workspace/local environment backups to their intended paths.
   Preserve ownership and permissions. If the home directory changes, update
   Arcane's global `HOME` and any project-local overrides before deploying.
3. If `$HOME/arcane` is unavailable, obtain `arcane/compose.yaml` and the
   environment template from GitHub and follow [Arcane bootstrap](#arcane-bootstrap).
   When restoring an existing Arcane database, use its **original encryption
   key**, not a newly generated one. Without that key, encrypted credentials
   may need to be re-entered or Arcane reconfigured.
4. From `$HOME/arcane`, run `docker compose config --quiet`, check the
   resolved mounts, and start Arcane with `docker compose up -d`.
   Prefer the backed-up image version/digest if recorded; mutable tags may
   now resolve to a different release.

### Reconnect and deploy the applications

1. For a restored Arcane database, inspect the existing repository and Git
   sync entries rather than creating duplicates. Turn off automatic sync
   and redeployment while checking recovery settings.
2. If starting with a fresh Arcane database, add the GitHub repository with
   read-only credentials. Under **Customization -> Variables**, set `HOME`
   to the restored user's home (for example `/home/example`).
3. Create or reconnect **Pull** syncs on branch `master` with these paths:

   | Project | Compose file path |
   |---|---|
   | `mpd` | `mpd/compose.yaml` |
   | `mympd` | `mympd/compose.yaml` |
   | `newt` | `newt/compose.yaml` |
   | `music-assistant` | `music-assistant/compose.yaml` |

   If a restored workspace folder exists but Arcane has no project record,
   import/discover and link that project before adding its sync. Do not
   delete application data to resolve project-folder conflicts.
4. Verify Newt's project-local credentials and check every resolved bind
   mount points to the restored data. Keep automatic deployment off until
   these checks pass. Never create an Arcane Git sync over its live data.
5. Deploy MPD, then myMPD, then Newt so the external networks exist.
   Music Assistant can be deployed independently.
6. Confirm MPD responds on port 6600, myMPD opens on port 80, Music Assistant
   opens on port 8095, and the Newt tunnel works remotely. Test actual
   playback, discovery, playlists, and saved settings before re-enabling
   automatic sync/redeployment.

## Existing Pi data

The Pi's application data has been migrated to `$HOME/containers`. All four
application projects have been recreated through Arcane Git Pull in `$HOME/gitops`.
The user verified all applications and their data after deployment; the
migration is complete. The old MPD, myMPD, and Music Assistant data under
`$HOME/docker` was removed with the user's approval. Dockge was subsequently
stopped and removed along with its files and the empty `$HOME/docker` directory.
Git history tracks configuration, not persistent application data.
