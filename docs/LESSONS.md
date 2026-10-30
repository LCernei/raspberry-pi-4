# Operational lessons

This file records verified, reusable findings. Keep entries concise, include
the context that could make them stale, and update or remove them when they
no longer apply.

## 2026-10-30: Keep the Git checkout outside Arcane's projects directory

Arcane scans its configured projects directory for Compose projects. A Git
checkout nested inside that directory was discovered as a project itself.
Keep the source checkout at `$HOME/gitops`, outside Arcane's
`$HOME/containers` projects directory.

## 2026-10-30: Arcane Compose deployments may not have `HOME`

Arcane 2.17.1 logged that `HOME` was unset while discovering Compose projects
whose bind mounts use `${HOME}`. Set `HOME` to the Pi user's home directory
in each Arcane-managed project's local environment, then validate the
resolved Compose configuration before deployment.

## 2026-10-30: Preserve cross-project Docker networks

MPD's Compose project creates `mpd_default`; myMPD joins it to reach MPD.
myMPD creates `mympd_default`; Newt joins it to reach myMPD. External networks
must exist before dependent projects start, so deploy MPD, then myMPD, then
Newt.

## 2026-10-30: Compose path changes require data migration

Existing application data remains under `$HOME/docker`, while the repository
Compose files target `$HOME/containers`. A successful Compose config check
does not migrate data; copy and verify persistent data before switching a
service to the new mounts, and retain the old copy until the service is
verified.
