# Graphite Development Environment

> Code name: `graphite-dev`

Installs the [Graphite](https://graphite.com/) CLI (`gt`) for stacked pull requests, and the Graphite VS Code extension (`Graphite.gti-vscode`). `gt` is signed in automatically at every container start from a `GRAPHITE_TOKEN` environment variable.

> **Also included automatically:** repairs broken host paths in your git config and restores
> your SSH commit-signing key on every attach — see [`helpers4-common`](../helpers4-common).

## Usage

```json
{
    "features": {
        "ghcr.io/helpers4/devcontainer/graphite-dev:1": {}
    },
    "containerEnv": {
        "GRAPHITE_TOKEN": "${localEnv:GRAPHITE_TOKEN}"
    }
}
```

Get your token at <https://app.graphite.com/activate> and export it on the host as `GRAPHITE_TOKEN`. Without it the container still starts; run `gt auth --token <token>` yourself.

## Options

| Option | Type | Default | Description |
|--------|------|---------|-------------|
| `version` | string | `stable` | Version or npm dist-tag of `@withgraphite/graphite-cli` (`stable`, `latest`, or e.g. `1.8.6`) |

## How it works

- **Install via npm.** Graphite publishes no standalone binary, and its Homebrew formula only wraps `npm install` on brew's own Node. So the feature `dependsOn` the official `node` feature and runs `npm install -g @withgraphite/graphite-cli@<version>`.
- **Auth at start, not at build.** `postStartCommand` runs `gt auth --token "$GRAPHITE_TOKEN"`. The token never enters the image. A missing or rejected token prints a warning and never blocks the container start.
- **No volume.** `gt` keeps its config in `~/.config/graphite`; since the token is re-applied on every start, there is nothing worth persisting.
- **git 2.38+.** `gt` 1.x needs it. The install warns if the container's git is older.

## Version History

- **v1.0.0**: Initial release.
