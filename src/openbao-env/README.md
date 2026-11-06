# OpenBao secrets

> Code name: `openbao-env`

Loads secrets from [OpenBao](https://openbao.org/) (KV v2) into the environment of **every process in the container**: VS Code and its extensions, terminals, the lifecycle hooks of other features, AI agents (Claude Code, Remote Control sessions). The container fetches its own secrets, so they no longer depend on which client attached and what it had in its `localEnv`.

> **Also included automatically:** repairs broken host paths in your git config and restores
> your SSH commit-signing key on every attach — see [`helpers4-common`](../helpers4-common).

## Usage

```json
{
    "features": {
        "ghcr.io/helpers4/devcontainer/openbao-env:1": {
            "address": "https://bao.example.com:8200",
            "paths": "shared/font-awesome,shared/web-awesome,orgs/my-org"
        }
    }
}
```

Each key of each path becomes an environment variable of the same name: store keys under their final in-container names (`GH_TOKEN`, `GEMINI_API_KEY`, ...). On a duplicate key, the later path wins (above: `orgs/my-org` over `shared/*`).

Then give the container credentials — one of the three setups below.

## Options

| Option | Type | Default | Description |
|--------|------|---------|-------------|
| `paths` | string | `""` | Comma-separated KV v2 paths, later ones override earlier ones |
| `mount` | string | `kv` | Mount path of the KV v2 engine |
| `address` | string | `""` | Server address. `BAO_ADDR` in the container's environment wins when set |
| `installCli` | boolean | `true` | Also install the `bao` CLI (GitHub releases, checksum verified). The loader doesn't need it |
| `version` | string | `latest` | `bao` CLI version when `installCli` is on, e.g. `2.7.2` |

Runtime environment overrides: `BAO_ADDR`, `BAO_CACERT` (custom CA bundle), `OPENBAO_PATHS`, `OPENBAO_MOUNT`, `OPENBAO_APPROLE_MOUNT` (default `approle`), `OPENBAO_ENV_TIMEOUT` (seconds for one fetch, default `5`), `OPENBAO_ENV_DISABLE=1` (never fetch from a shell).

## Credentials

First match wins:

1. **`BAO_TOKEN`** in the environment.
2. **Files dropped by the host** before the lifecycle hooks: `/dev/shm/openbao/role-id` + `/dev/shm/openbao/wrapped-secret-id` (a response-wrapped AppRole `secret_id`). The loader unwraps it (`sys/wrapping/unwrap`), logs in, and deletes `wrapped-secret-id` at once: it is single-use.
3. **A token cached** by an earlier login, in `/dev/shm/openbao/token`, until its TTL runs out — so `openbao-env refresh` works without new credentials meanwhile.
4. **`BAO_ROLE_ID` + `BAO_SECRET_ID`** in the environment (a reusable `secret_id`).

### a. A host tool with a two-phase `devcontainer up`

The host mints a short-lived wrapped `secret_id` and drops it in the container between creating it and running the lifecycle hooks:

```bash
devcontainer up --workspace-folder . --skip-post-create
id=$(docker ps -q --filter "label=devcontainer.local_folder=$PWD")
user=vscode   # the container's remoteUser

docker exec -u "$user" "$id" sh -c 'umask 077; mkdir -p /dev/shm/openbao'
bao read -field=role_id auth/approle/role/my-org/role-id \
    | docker exec -i -u "$user" "$id" sh -c 'umask 077; cat > /dev/shm/openbao/role-id'
bao write -f -wrap-ttl=120s -field=wrapping_token auth/approle/role/my-org/secret-id \
    | docker exec -i -u "$user" "$id" sh -c 'umask 077; cat > /dev/shm/openbao/wrapped-secret-id'

devcontainer run-user-commands --workspace-folder .
```

Write the files **as the remote user** (`-u`), mode 600: the directory must be theirs (if it isn't, the loader tries `sudo chown`). `/dev/shm` is memory only and emptied when the container stops, so the next start needs a new wrapped `secret_id`.

### b. GitHub Codespaces

Add `BAO_ROLE_ID` and `BAO_SECRET_ID` (and `BAO_ADDR` if not in the `address` option) as [Codespaces secrets](https://docs.github.com/en/codespaces/managing-your-codespaces/managing-your-account-specific-secrets-for-github-codespaces) for the repository. If the server is only reachable on a private network (e.g. a tailnet), add the [Tailscale feature](https://github.com/tailscale/codespace) and an auth key, so the container can reach it. Codespaces secrets that already hold a value (e.g. a `GH_TOKEN` secret) are kept over the OpenBao ones.

### c. A token

`BAO_TOKEN` in `containerEnv` / `remoteEnv` / a Codespaces secret. Simplest, but the token lives as long as you let it.

## ⚠️ Remove secret entries from `remoteEnv`

```jsonc
"remoteEnv": {
    "GH_TOKEN": "${localEnv:GH_TOKEN}"   // ← remove
}
```

`remoteEnv` is applied on top of the shell environment: when the attaching client doesn't have the variable, `${localEnv:…}` resolves to an empty string, and that empty value **replaces** the one loaded from OpenBao. Keep secrets out of `remoteEnv` and `containerEnv` once they are in OpenBao.

## How it works

- **A loader in every shell.** `/usr/local/share/openbao-env/loader.sh` (POSIX sh) is sourced from `/etc/profile.d/`, `/etc/bash.bashrc` and zsh's global `zshrc`. VS Code and the devcontainer CLI probe the user's environment with a login interactive shell (`userEnvProbe`) **before any `onCreate`/`postCreate`/`postStart` hook of any feature**, and hand that environment to the server, extensions, terminals and every lifecycle hook. So e.g. `org-workspace` (cloning with `GH_TOKEN`) and `graphite-dev` (`GRAPHITE_TOKEN` on start) already see the secrets.
- **Two pieces.** `loader.sh` is *sourced*: only a sourced file can export variables into a shell. It just reads the cache and exports. Everything else (login, network, cache write) is in the `openbao-env` command, a separate process, so nothing it does can leak into your shell.
- **A memory-only cache.** The first shell fetches every path and writes `/dev/shm/openbao/env` (directory 700, files 600, owned by the remote user). Later shells only read it: no network. `/dev/shm` is a tmpfs, never on disk, emptied when the container stops.
- **Bounded and quiet.** A fetch takes at most ~5 s, one at a time (`flock`; concurrent shells wait and reuse the result). On failure: one line on stderr naming the cause (no credentials, no answer, HTTP 403 on a path, ...), never a value; the shell starts normally; new shells don't retry for 5 minutes unless the host drops new credentials. The loader never sets shell options or exits.
- **Existing variables win.** A variable already set to a non-empty value (Codespaces secret, `containerEnv`, your own `export`) is left alone; an empty one counts as unset. Variables the loader set itself are replaced after a `refresh`.
- **Secrets never in argv or logs.** Tokens and `secret_id`s reach `curl` through 600 files in `/dev/shm/openbao`, never on the command line (readable by any process in `/proc`). Status and errors print key names, paths and HTTP statuses only.
- **Only `curl` + `jq` at runtime.** The `bao` CLI is optional.
- **`postStartCommand`** runs `openbao-env check`: a one-line warning if nothing is loaded.

## `openbao-env`

```text
openbao-env status    address, paths, key names per path, cache age, token TTL — never values
openbao-env refresh   fetch again into the cache
openbao-env clear     remove the cache and the cached token
```

After `refresh`, open a new terminal, or run **Developer: Reload Window** for VS Code and its extensions to get the new values (in the current shell: `. /usr/local/share/openbao-env/loader.sh`).

## Version History

- **v1.0.0**: Initial release.
