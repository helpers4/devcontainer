# Roadmap / Ideas — devcontainer

Backlog of future work — not an active plan like the (now-removed) audit `TODO.md` was.
Items here are ideas or known gaps, not yet scoped or scheduled.

- **OpenSSF Scorecard.** Already set up in `helpers4/typescript`
  (`.github/workflows/scorecard.yml` + badge in `README.md`) — replicate the same workflow
  here: weekly cron + `workflow_dispatch`, `ossf/scorecard-action`, SARIF upload to code
  scanning, badge linking to `securityscorecards.dev/viewer/?uri=github.com/helpers4/devcontainer`.
  Needs a `SCORECARD_TOKEN` repo secret (check whether the typescript repo's can be reused
  org-wide or if this repo needs its own PAT).

- **`peon-ping`: sound forwarding is broken.** Currently relies on
  `host.docker.internal:19998` for the container → host audio relay (see feature README,
  "Container sends audio requests to `host.docker.internal:19998` automatically. No port
  forwarding configuration needed.") — doesn't actually work right now. Needs investigation:
  confirm whether `host.docker.internal` resolves in the affected environments (Linux Docker
  without Docker Desktop doesn't get this DNS entry for free), whether the relay listener is
  actually running/reachable, and whether an explicit `appPort`/`forwardPorts` entry is needed
  in the feature or documented as a consumer requirement.

- **`peon-ping`: simplify configuration around a single language/pack choice.** Right now
  config exposes packs, categories, rotation, volume, etc. separately — consider collapsing
  the common case to "pick a pack, pre-configured for you" instead of composing multiple
  options by hand. Reference: [openpeon.com](https://openpeon.com) for how the packs are
  presented there. Needs a concrete design pass before touching `devcontainer-feature.json`'s
  options schema (backward compatibility with existing option names to consider).

- **New feature: `python-dev`.** Python-specific dev environment + extensions, following the
  shape of `typescript-dev`/`angular-dev` (dependsOn `essential-dev`, VS Code extensions,
  relevant settings). Check first whether an existing official/community feature
  (`ghcr.io/devcontainers/features/python`) already covers the CLI/interpreter install — if so,
  this feature's job is likely just extensions + settings on top, same pattern as `angular-dev`
  delegating CLI install to `ghcr.io/devcontainers-extra/features/angular-cli`. Use the
  `/add-devcontainer-feature` skill once scoped.
