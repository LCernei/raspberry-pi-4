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

## Existing Pi data

The Pi's application data has been migrated to `$HOME/containers`. All four
application projects have been recreated through Arcane Git Pull in `$HOME/gitops`.
The user verified all applications and their data after deployment; the
migration is complete. The old MPD, myMPD, and Music Assistant data under
`$HOME/docker` was removed with the user's approval. Dockge was subsequently
stopped and removed along with its files and the empty `$HOME/docker` directory.
Git history tracks configuration, not persistent application data.
