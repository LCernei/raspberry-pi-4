# Operational lessons

This file records verified, reusable findings. Keep entries concise, include
the context that could make them stale, and update or remove them when they
no longer apply.

## 2026-10-30: Keep the Git checkout outside Arcane's projects directory

Arcane scans its configured projects directory for Compose projects. A Git
checkout nested inside that directory was discovered as a project itself.
Keep any source checkout outside Arcane's `$HOME/gitops` projects directory.
That directory is now a managed workspace, not a checkout.

## 2026-10-30: Keep project workspaces separate from application data

Arcane 2.17.1 refused to create a Git Pull project named `mpd` because its
projects root already contained an `mpd` data directory. Use
`$HOME/gitops` for Arcane-managed Compose files and keep application
data under `$HOME/containers`. Never delete application data to resolve a
project-name collision.

## 2026-10-30: Arcane Compose deployments may not have `HOME`

Arcane 2.17.1 logged that `HOME` was unset while discovering Compose projects
whose bind mounts use `${HOME}`. Configure shared values through
**Customization -> Variables**, scoped to the appropriate environment.
For example, set `HOME=/home/example`; Arcane writes it to `.env.global`
and uses it for Compose substitution across projects. A project's local
`.env` overrides the global value. Prefer the Variables UI over manually
editing the managed `.env.global` file.

With `HOME` unset, `${HOME}/containers/mpd/music` resolved to
`/containers/mpd/music`, and Docker created a bind directory at the host's
filesystem root instead of using existing application data. Validate resolved
mount paths before deploying. After correcting the variable, recreate the
container; restarting it does not change its mounts. Keep incorrectly created
directories until the corrected deployment and intended data are verified.

## 2026-10-30: Preserve cross-project Docker networks

MPD's Compose project creates `mpd_default`; myMPD joins it to reach MPD.
myMPD creates `mympd_default`; Newt joins it to reach myMPD. External networks
must exist before dependent projects start, so deploy MPD, then myMPD, then
Newt.

## 2026-10-30: Compose path changes require data migration

The application data was copied from `$HOME/docker` to `$HOME/containers`
before switching each service to the new mounts. A successful Compose config
check does not migrate data; copy and verify persistent data before switching
a service, and retain the old copy until the new deployment is verified.
After migration, MPD's protocol greeting, myMPD's HTTP response and MPD
connection, and Music Assistant's HTTP response were checked. Newt was
confirmed running on `mympd_default`. The user subsequently verified all
applications and their data, completing the migration. Retained rollback
copies are not ongoing backups and should not replace a backup policy.
