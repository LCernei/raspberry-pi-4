# Agent guidance

This file is the vendor-neutral entry point for AI assistants working in this
repository. Before changing infrastructure, read [the deployment spec](docs/SPEC.md)
and [the lessons log](docs/LESSONS.md), then inspect the affected Nix modules
and current repository state.

## Working rules

- Treat `docs/SPEC.md` as the current intended behavior. If a user explicitly
  changes a durable requirement, update the spec and related README guidance
  in the same change.
- Compare proposed changes with the spec and lessons. If an observed state
  diverges, explain the difference and resolve it rather than silently
  preserving stale documentation.
- Add to `docs/LESSONS.md` only verified, reusable operational findings or
  durable user decisions. Do not record transient chat details, assumptions,
  or secrets. Ask before recording an ambiguous or inferred preference.
- Keep guidance vendor-neutral. Do not add provider-specific instruction files
  unless the user asks for them or a concrete compatibility need requires one.
- The repository is meant to be public. Never commit credentials, keys
  (not even public SSH keys or encrypted secrets), personal data, or
  generated runtime data. Secrets live only on the Pi under
  `/var/lib/secrets` and in backups.
- Preserve service names, state paths under `/var/lib`, and pinned versions
  unless the user requests a change.
- Treat deployment, data migration, and container replacement as operational
  changes: inspect the current state, back up persistent data, and do not
  disrupt running services without explicit approval.
- Validate with `nix flake check` and by building the system before
  deploying. Deploy with deploy-rs so a lost SSH connection rolls back.
- Changes to `hosts/rpi/hardware.nix` (kernel, firmware, `config.txt`,
  boot loader) can leave the Pi unbootable; test them while physical access
  is available.
- Keep changes focused. Update user-facing documentation when behavior or
  operating steps change.

## Project references

- [Deployment spec](docs/SPEC.md): intended layout, networking, data and
  acceptance checks.
- [Lessons log](docs/LESSONS.md): verified pitfalls and operational findings.
- [Plans](docs/PLANS.md): undecided improvement proposals; not current
  behavior.
- [README](README.md): project overview and operator setup.
