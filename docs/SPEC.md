# Deployment specification

## Purpose and scope

Manage the Raspberry Pi's home services as independent Docker Compose
projects, with configuration in Git and Arcane providing a dashboard and
Git-based deployment. The Git repository is the source of truth for Compose
configuration; persistent application state and credentials are not stored
in Git.

## Layout

- GitHub is the source of truth; no Git checkout is required on the Pi.
- Arcane projects directory: `$HOME/gitops`, mounted at `/projects`. This is
  a managed workspace, not a Git checkout.
- Arcane bootstrap Compose and local environment: `$HOME/arcane`.
- Application data: `$HOME/containers`, separate from the project workspace.
- Each application is a separate Compose project and Arcane Git Pull project:
  `mpd`, `mympd`, `music-assistant`, and `newt`.
- Arcane is bootstrapped separately from the other application projects.
  Its application data must not be overwritten by a Git sync.
- Keep project names explicit where needed so relocating Compose files does
  not silently change Docker network names.

## Service and network requirements

- **MPD** uses `/dev/snd`, exposes port `6600`, and serves the music and
  playlist directories read-only to clients where applicable.
- **myMPD** is a separate Compose project, exposes HTTP on host port `80`,
  and joins MPD's external `mpd_default` network to connect to MPD.
- **Newt** is a separate project and joins myMPD's external `mympd_default`
  network so the tunnel can reach myMPD. Deploy myMPD before Newt to create
  that network.
- **Music Assistant** uses host networking for discovery and streaming.
- Preserve stable service/container names unless explicitly changed by the
  user.
- All five services use Docker's `json-file` logging driver with `max-size:
  "10m"` and `max-file: "3"`. These limits cover container stdout/stderr,
  not log files written inside application data directories.

## Data and secrets

- Intended persistent application data paths are below
  `$HOME/containers/<project>/`.
- Compose host paths use `${HOME:?HOME must be configured}` rather than a user-specific absolute home
  path. Arcane deployments must receive the correct `HOME` value; verify this
  through Arcane's environment-scoped global Variables before deploying.
  Project-local `.env` values override the shared value.
- Real environment files, credentials, and encryption keys stay local and
  are excluded from Git. Commit only placeholder `.env.example` files.
- Arcane's encryption key must be backed up securely with Arcane's application
  data.

## Current migration state

The migration is complete. The user confirmed all applications work and
their data is present after the final Arcane deployments.

MPD, myMPD, Music Assistant, and Newt have been recreated through Arcane Git
Pull in `$HOME/gitops`, with persistent data under `$HOME/containers`.
All five containers, including Arcane, were verified running with zero
restarts; application bind mounts and cross-project networks were checked.
myMPD and Music Assistant returned HTTP 200 after recreation.
Application data and local secrets were retained. After functional verification,
the previous MPD, myMPD, and Music Assistant data under `$HOME/docker` was
removed with the user's approval. Dockge was subsequently stopped and removed,
including its files and the empty `$HOME/docker` directory. Arcane is the sole
deployment manager. Newt has no persistent bind-mounted application data.

Basic runtime checks passed after migration: MPD returned its protocol
greeting, myMPD returned HTTP 200 and connected to MPD, Music Assistant
returned HTTP 200 on port 8095, and Newt was running on `mympd_default`.
The user subsequently confirmed successful use of all applications.

Arcane is bootstrapped separately, with application data at
`$HOME/containers/arcane` and `$HOME/gitops` as its projects directory.
The former checkout is no longer present. Temporary migration backups were
removed with the user's approval; active application data and local
configuration remain intact. Never sync a project over Arcane's live
application data.

## Change acceptance checks

Before deploying an affected project:

1. Compare changes with this spec and `docs/LESSONS.md`.
2. Verify local secrets and environment values are available without adding
   them to Git.
3. Run `docker compose config --quiet` on the Pi for the affected project.
4. Back up persistent data and confirm the required external networks exist.
5. Apply one project at a time and verify service health and its dependent
   connections before continuing.

Update this spec when the user confirms a durable change to intended
architecture or operating behavior.
