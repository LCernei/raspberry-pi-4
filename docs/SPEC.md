# Deployment specification

## Purpose and scope

Manage the Raspberry Pi's home services as independent Docker Compose
projects, with configuration in Git and Arcane providing a dashboard and
Git-based deployment. The Git repository is the source of truth for Compose
configuration; persistent application state and credentials are not stored
in Git.

## Layout

- Git source checkout: `$HOME/gitops`.
- Arcane projects directory: `$HOME/containers`.
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

## Data and secrets

- Intended persistent application data paths are below
  `$HOME/containers/<project>/`.
- Compose host paths use `${HOME}` rather than a user-specific absolute home
  path. Arcane deployments must receive the correct `HOME` value; verify this
  in Arcane's project environment before deploying.
- Real environment files, credentials, and encryption keys stay local and
  are excluded from Git. Commit only placeholder `.env.example` files.
- Arcane's encryption key must be backed up securely with Arcane's application
  data.

## Current migration state

The Compose files describe the intended `$HOME/containers` data paths, but
the existing application stacks have not yet been migrated from
`$HOME/docker`. Do not deploy the changed mounts until each service's data has
been copied, checked, and the migration is approved.

Arcane is currently running with application data at
`$HOME/containers/arcane`, while `$HOME/containers` is its configured projects
directory. Resolve this path overlap before configuring an Arcane Git Pull
project named `arcane`; never sync over Arcane's live application data.

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
