# Nub — Fast TypeScript/Node Toolchain (nub)

Installs [nub](https://nubjs.com/): a single Rust binary that runs TypeScript/JavaScript files, `package.json` scripts, and local CLIs directly on top of the Node.js and package manager already in the container — no new runtime, no lock-in.

## Why this feature exists

nub is explicitly **not a replacement runtime**: "runs on the node and package manager you already have." It accelerates three things that are normally slow because of Node's own CLI-wrapper overhead:

- Running a `.ts`/`.js` file directly (`nub file.ts`) — faster startup than `tsx`/`ts-node`, full `tsconfig.json` support.
- Running a `package.json` script (`nub run <script>`) — faster than `npm run`/`pnpm run`.
- Running a local CLI binary (`nubx <cli>`) — faster than `npx <cli>`, no Node wrapper.

It also has its own dependency installer (`nub install`) with a unified interface across npm/pnpm/bun lockfiles, and its own Node-version manager — **this feature deliberately doesn't use the latter.** Node's own version is already this container's responsibility via the official `node` feature (`dependsOn` below); letting `nub node install` manage a second, independent version would create two competing version-selection mechanisms in the same container. Use `nub` for the speed, not for the version management.

## Example Usage

```jsonc
{
  "features": {
    "ghcr.io/helpers4/devcontainer/nub:1": {}
  }
}
```

Pin a specific release instead of the default `latest`:

```jsonc
{
  "features": {
    "ghcr.io/helpers4/devcontainer/nub:1": {
      "version": "1.2.3"
    }
  }
}
```

## Options

| Option | Type | Default | Description |
|--------|------|---------|-------------|
| `version` | string | `latest` | Version of nub to install, or a specific release like `1.2.3`. |
| `installGlobally` | boolean | `true` | Symlink `nub`/`nubx` into `/usr/local/bin` so they're available system-wide (all users, root, sudo) without relying on the target user's own `$PATH`. |

## How it works

1. Runs the [official installer](https://nubjs.com/install.sh) as the container's target non-root user (not root — the installer resolves its default install location from `$HOME`), with `NUB_INSTALL_DIR=~/.nub` and `NUB_NO_MODIFY_PATH=1` so it never edits `~/.bashrc`/`~/.zshrc` itself.
2. If `installGlobally` (default), symlinks every binary under `~/.nub/bin/` (`nub` and `nubx`, the latter dispatching on `argv[0]`) into `/usr/local/bin`.

No VS Code extension — nub doesn't have one. This feature is CLI tooling only.

## What this feature does *not* do

- **Does not install the `nub` npm/pnpm shims** (`nub pm shim`, which hardlinks `~/.nub/shims/{npm,npx,…}` to transparently intercept package-manager calls). That's a deeper, PATH-wide interception decision left to the consuming project to opt into explicitly — this feature only makes the `nub`/`nubx` binaries available.
- **Does not manage Node versions.** See "Why this feature exists" above.

## Links

- **nub**: https://nubjs.com/
- **Docs**: https://nubjs.com/docs
- **Source**: https://github.com/nubjs/nub

## Version History

- **v1.1.0**: Switched from an inline copy of `helpers4-common`'s bootstrap (user detection, apt
  helpers) to a direct `dependsOn` on the `helpers4-common` feature — no behavior change, just a
  single source of truth for that logic instead of a copy every feature had to keep in sync.
- **v1.0.0**: Initial release.
