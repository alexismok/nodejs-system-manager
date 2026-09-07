# nodejs-system-manager

A lightweight Node.js version manager for Linux servers, designed for hosting environments where multiple Node.js versions must coexist and be managed centrally.

Unlike developer-oriented tools such as `nvm`, which are designed for personal use (per-user management), this tool is intended for production servers and provides:

* Installation of Node.js directly from official binaries.
* Support for floating versions (`24`, `24.1`) which will be resolved to their latest versions and exact versions for strong stability (`24.1.2`).
* Per-version global npm package tracking, with a default package set applied to every managed version.
* Automatic updates of managed versions and packages.
* Version-specific wrappers (`node24`, `npm24`, `node24.1`, etc.) to avoid PATH changes.
* Automatic cleanup of obsolete versions.
* Lifecycle hook (pre/post) for mutating action, with the ability to skip an operation from a hook.
* JSON output mode for scripting and automation.
* Local caching of the Node.js release index.
* File-lock based concurrency protection.

---

## Requirements

Strict requirements (script early exit if missing): 
* `bash` >= 4
* `curl`, `jq`, `tar`, `sha256sum`, `xz`, `flock`


Debian packages:
```bash
apt install bash curl jq xz-utils ca-certificates coreutils
```

The script must run as a user with write access to `NODEJS_ROOT`, `BIN_DIR`, `CONFIG_DIR`, `LOCK_DIR`, and `CACHE_DIR` (see configuration for defaults).

---

## Installation

```bash
curl -fsSL -o /usr/local/sbin/nodejs-system-manager https://raw.githubusercontent.com/alexismok/nodejs-system-manager/main/nodejs-system-manager
chmod +x /usr/local/sbin/nodejs-system-manager
nodejs-system-manager --version
```

## Quick start

```bash
# Install and manage an exact patch version
nodejs-system-manager install 22.5.0

# Force-reinstall a version even if already present
nodejs-system-manager install 24 --force

# Update all managed versions (Node.js + global packages)
nodejs-system-manager update

# Update all only package of specific version
nodejs-system-manager update 24.1 --packages-only

# Install a global package to a specific version
nodejs-system-manager pkg_add 24 @myorg/cli@2.3.1

# Automation-friendly: get the result as compact JSON, check exit code
if ! nodejs-system-manager install 24 --json --quiet > result.json; then
    jq -r '.msg' result.json >&2
    exit 1
fi

# List everything, machine-readable
nodejs-system-manager list --json | jq '.managed[].version'
```

## Concepts

### Version hierarchy & linked versions

A version can be specified at three levels of precision:

| Form | Example | Behavior |
|---|---|---|
| Major | `24` | Floating - symlinked to the latest installed `24.x` minor |
| Major.minor | `24.1` | Floating - symlinked to the latest installed `24.1.x` patch |
| Major.minor.patch | `24.1.0` | Exact - a real installation directory, not a symlink |

Installing `24` creates the chain `24 → 24.1 → 24.1.0`, where `24.1.0` is the only real directory under `NODEJS_ROOT`; `24` and `24.1` are symlinks. **All three names share the exact same physical Node.js/npm installation** - `npm24`, `npm24.1`, and `npm24.1.0` all operate on the same global `node_modules`.

### Managed vs. unmanaged

`install <version>` automatically **manages** that version. A managed version:

- Is eligible for `update`, `pkg_add`, `pkg_del`, `pkg_list`.
- Gets `BIN_DIR` symlinks/wrappers: `node<version>`, `npm<version>`, `npx<version>`, and `corepack<version>` (Node.js < 25 only).
- Is protected from automatic cleanup during another version's `update` - its directory (and everything below it in the symlink chain) is kept even if it would otherwise look "unreferenced".

`manage`/`unmanage` let you add or drop this status independently of installing/removing the actual files. `remove` automatically unmanages a version as part of deleting it - you don't need to `unmanage` first.

### Package tracking

Each managed version has its own package list file, plus one shared `default` list applied to every version:

- `pkg_add <version> <package>[@<version-spec>]` - track a package for one version.
- `pkg_add default <package>[@<version-spec>]` - track a package for **every current and future managed version**. This only updates the config file; it does not retroactively install into already-managed versions (run `update` for that).
- `pkg_del <version|default> <package>` - remove a package for the version. For default, it does not remove packages from installed versions, only untrack it from configuration file.
- `pkg_list <version|default>` - show what's tracked, its policy (requested constraint), source (`default` vs. version-specific file vs. npm command report), and (for a real version) the actually-installed version.

As stated earlier, version MAJOR or MAJOR.MINOR are linked to a real MAJOR.MINOR.PATCH version, so they share the same node_modules folder.  
This matters for package tracking: if `pnpm` is tracked by both `24` and `24.1`'s config, removing it via `pkg_del 24.1 pnpm` would physically break `24` too, since it's the same npm install. The script detects this automatically:

- **`pkg_del`** — checks whether any other version *linked to the same installation* (an ancestor or descendant in the symlink chain) still tracks the package, or whether the `default` package set requires it. If so, the package is untracked from the requested version's own config file (with a warning), but the actual `npm uninstall` is skipped so sibling versions aren't broken.
- **`pkg_add`** — if a linked version already tracks the same package name at a *different* version constraint (e.g. `24` wants `pnpm@6`, you're adding `pnpm@8` to `24.1`), the command refuses adding the package since installing would silently change the package to every linked version resolved to this one.

### Update

You can update version and it package according to this table:

| Type     | Node update | Package update |
| -------- | ----------- | -------------- |
| `24`     | Yes         | Yes            |
| `24.1`   | Yes         | Yes            |
| `24.1.2` | No          | Yes            |

Remaining unused and unmanaged versions will be cleaned after an update.  

When floating versions are updated, packages will be installed on the new version following this sources ordered by priority (lowest to highest):
* Current version packages with strict package version.
* Default packages (from: `CONFIG_DIR/packages/default`)
* Version packages (from: `CONFIG_DIR/packages/<version>`)

As stated above, to prevent package loss on update, if a package is installed outside of this script (directly via `npm install -g`) it will be installed on the new Node.js version to the exact package version it was installed before.  

It's not possible to skip package update on this command as MAJOR or MAJOR.MINOR version would loose their packages. To prevent a package update, add it via a strict version constraint so it never get updated. 

### JSON output

To allow programatic usage you can specify the option `--json`, all output are redirected to stderr, and the stdout will print a JSON object with the result of the action.
You can read more about it in [docs/JSON_OUTPUT.md](docs/JSON_OUTPUT.md).

## Actions

| Action | Usage | Description |
|---|---|---|
| `install` | `install <version> [--force]` | Install a Node.js version (also manages it and installs its tracked packages) |
| `update` | `update [<version>] [--packages-only]` | Re-resolve floating version(s) to the latest release and reinstall tracked packages; without an argument, updates every managed version |
| `remove` | `remove <version>` | Unmanage and remove an installation (and unused symlink ancestors) |
| `manage` | `manage <version>` | Start managing an already-installed version |
| `unmanage` | `unmanage <version>` | Stop managing a version (removes its `BIN_DIR` symlinks, keeps the files) |
| `pkg_add` | `pkg_add <version\|default> <package>[@<spec>]` | Track and install a global npm package for a version (or `default`) |
| `pkg_del` | `pkg_del <version\|default> <package>` | Untrack (and, if safe, uninstall) a global npm package |
| `pkg_list` | `pkg_list <version\|default>` | List tracked packages for a version |
| `list` | `list [--ignore-managed] [--ignore-unmanaged]` | List installed versions, managed and unmanaged, with their resolved target and symlink hierarchy |
| `help` | `help` | Show usage |
| `version` | `version`, `--version`, `-V` | Print the script's own version |

Run `<action> --help` for that action's specific options and parameters (e.g. `nodejs-system-manager install --help`).

## Global options

These apply to every action; place them anywhere on the command line after the action.

| Option | Effect | ENV VAR | CONFIG FILE |
|---|---|---|---|
| `--verbose`, `-v` | Enable debug-level logs |||
| `--quiet`, `-q` | Suppress console log output entirely |||
| `--no-timestamp` | Omit timestamps from log lines | LOG_TIMESTAMP | Yes |
| `--no-colors` | Disable ANSI color in log output | LOG_COLOR | Yes |
| `--syslog` | Also send logs to syslog (even with `--quiet`) | SYSLOG_ENABLED | Yes |
| `--log-file <path/file>` | Also send log to file (even with `--quiet`) | LOG_FILE | Yes |
| `--json` | Print the action's result as JSON on stdout; all logs move to stderr |||
| `--json-compact` | Same as `--json`, but single-line/compact JSON |||
| `--nodejs-root <path>` | Override `NODEJS_ROOT` (default `/opt/nodejs`) | NODEJS_ROOT | Yes |
| `--bin-dir <path>` | Override `BIN_DIR` (default `/usr/local/bin`) | BIN_DIR | Yes |
| `--config-dir <path>` | Override `CONFIG_DIR` (default `/etc/nodejs-system-manager`) | CONFIG_DIR | No |
| `--lock-dir <path>` | Override `LOCK_DIR` (default `/var/lock/nodejs-system-manager`) | LOCK_DIR | Yes |
| `--cache-dir <path>` | Override `CACHE_DIR` (default `/var/cache/nodejs-system-manager`) | CACHE_DIR | Yes |
| `--skip-index-cache` | Don't read or write the cached Node.js release index; always fetch fresh | CACHE_INDEX_FILE_SKIPPED | Yes |
| `--cache-index-ttl <seconds>` | Cached Node.js release index cache duration (default 3600s) | CACHE_INDEX_TTL | Yes |
| `--ignore-hooks` | Don't load or run any hooks for this invocation | DISABLE_HOOKS | Yes |
| `--force`, `-f` | Action-specific: reinstall / reinstall-and-relink (see each action's `--help`) |||

Options with an `ENV VAR` can be defined from environnement variable.  
Options with `CONFIG FILE` to `Yes` can be defined in `CONFIG_DIR/config`, one variable per line with the following syntax: `VARNAME=varvalue`.  
Options without expected value (e.g. --no-timestamp) need `true` or `false` as value in environnement variable or config file.

Here is the configuration priority : CLI Options > environment variables > configuration file > defaults value.

## Configuration & directory layout

```
NODEJS_ROOT/                       Node.js installations (default /opt/nodejs)
  24.1.0/                          real install directory (exact patch)
  24.1 -> 24.1.0                   symlink (floating minor)
  24   -> 24.1                     symlink (floating major)

BIN_DIR/                           version-suffixed binaries (default /usr/local/bin)
  node24, npm24, npx24, ...

CONFIG_DIR/                        default /etc/nodejs-system-manager
  managed.list                     one managed version name per line
  packages/
    default                        packages applied to every managed version
    24                             packages specific to version "24"
    24.1                           packages specific to version "24.1"
  hooks/
    *.sh                           any number of hook scripts, sourced alphabetically

LOCK_DIR/                          default /var/lock/nodejs-system-manager
  nodejs-system-manager.lock       single global lock, held for the duration of any mutating action

CACHE_DIR/                         default /var/cache/nodejs-system-manager
  nodejs-index.json                cached https://nodejs.org/dist/index.json, TTL 3600s
```

### Concurrency

Every mutating action (`install`, `update`, `remove`, `manage`, `unmanage`, `pkg_add`, `pkg_del`) acquires a single exclusive file lock before doing any work and holds it for the whole operation. A second concurrent invocation fails fast with an error identifying the holding PID, rather than blocking or interleaving with the first. Read-only actions (`list`, `pkg_list`) don't take the lock.

## Exit codes

- **`0`** - the action's `status` was `success` or `warning` (the operation achieved its goal, possibly with something worth reviewing in the logs.
- **`1`** - the action's `status` was `error`.
- **Any other non-zero code** - uncatched errors or hook explicit exit code.

## Hooks

Any `*.sh` file dropped in `CONFIG_DIR/hooks/` is sourced into the running script at startup. Defining a function named after one of the recognized hook points (e.g. `pre_install_version`) is enough to have it invoked automatically at the right time - no registration needed.

- A **pre_\*** can prevent the main action execution by defining `HOOK_ACTION=skip` with a zero exit code. If the hook has uncatched errors or non-zero exit code, the action will be stopped instantly and script will be stopped, except for multiple versions actions like `update`.
- A **post_\*** hook runs after the real work is done; if it fails, the operation is still reported as failed even though the underlying change already happened - hooks can't roll anything back. These hook is not executed if the action has failed.
- Hooks run with full dynamic-scope access to the triggering function's local variables (e.g. `$version`), not just exported environment variables.

Full hook reference - every hook point, exactly when it fires, and which variables are reliably available in each - is in [docs/HOOKS.md](docs/HOOKS.md).

## License

MIT
