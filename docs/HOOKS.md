# Hooks reference

See the main [README](../README.md#hooks) for the general concept. This document lists every hook point precisely: when it fires, how to skip or fail an operation from it, and which variables are reliably available inside each one.

## How hooks are loaded

Every `*.sh` file in `CONFIG_DIR/hooks/` (default `/etc/nodejs-system-manager/hooks/`) is sourced into the running script at startup, in filename order. Any function you define whose name matches a recognized hook point below is called automatically, there's no registration step.

Run with `--ignore-hooks` to skip loading the hooks directory entirely for one invocation.

## Skipping vs. failing

- **Abort the operation**: `return` a non-zero exit code from your hook function and the action will be stopped with `status: error` without any change. A `post_*` hook returning non-zero still marks the action as failed, but the underlying change has already happened and cannot be undone by the hook.
- **Skip cleanly** (pre-hooks only): set `HOOK_ACTION=skip` and `return 0`. The action reports `status: "success"`, `code: "HOOK_SKIPPED"`, and does none of its normal work. Setting `HOOK_ACTION=skip` inside a `post_*` hook has **no effect** — post-hooks don't check it, since the work they'd be "skipping" already ran.
- Doing neither (returning 0, `HOOK_ACTION` left at `continue`) lets the operation proceed normally.

`HOOK_ACTION` is reset to `"continue"` before every hook invocation, so you don't need to reset it yourself between hooks.

## Variable access

Hook functions are called as ordinary Bash functions from deep inside the script's own call stack, so, they can read `local` variables from every function still active in that call chain, not just exported environment variables. This is how a hook knows *which* version or package it's being called about, without any argument-passing convention.

**This means the variables available to a given hook are exactly the `local` variables declared, by that point, in the function that triggered it.** The tables below list the ones worth relying on. Treat this as the hook "API" for this script — if you rely on a variable not listed here, a future refactor of the script's internals could rename or remove it without warning, since these aren't a formally exported interface.

This globals are available in **every** hook, regardless of which one fired:
- `$ACTION_NAME` — name of the CLI action requested.
- `$HOOK_ACTION` — skip or continue (default) action process. 
- The configuration globals (`$NODEJS_ROOT`, `$BIN_DIR`, `$CONFIG_DIR`, `$LOCK_DIR`, `$CACHE_DIR`, `$JSON_OUTPUT`, etc.).
- `$PACKAGES_VERSION_POLICY` / `$PACKAGES_SOURCE` (associative arrays) — the currently loaded package policy, keyed by package name. Populated before `install_packages` runs; may be stale or empty outside a packages-related hook.

This variables are scopped to the current actions and only available to `post_*` hooks:
- `$__out` — JSON object stored as string which contain the action result with some datas. For exemple, on post_install_packages it may contain the install result and details per package. I recommend using `jq` to read it; as it's a requirement for the script, it'll be availables in hooks.

## Hook points

### `pre_manage_version` / `post_manage_version`

Fires around: adding a version to the managed list and creating its `BIN_DIR` symlinks.

| Variable | Value |
|---|---|
| `$version` | The version being managed (as passed on the command line — may be a floating major/minor) |
| `$target_path` | `${NODEJS_ROOT}/${version}` — where the real installation resolves to |

### `pre_unmanage_version` / `post_unmanage_version`

Fires around: removing a version from the managed list and deleting its `BIN_DIR` symlinks.

| Variable | Value |
|---|---|
| `$version` | The version being unmanaged |

### `pre_install_version` / `post_install_version`

Fires around: downloading, verifying, and extracting a specific Node.js release.

| Variable | Value |
|---|---|
| `$full` | The exact release being installed, e.g. `24.1.0` |
| `$dir` | `${NODEJS_ROOT}/${full}` — the target install directory |
| `$arch` | The detected architecture (`x64`/`arm64`) — **only set by the time `post_install_version` fires**, not available in `pre_install_version` |
| `$version` | Not defined in `install_version()`, but should be available from the caller, this is the case for now (`update_version()`, `cmd_install()`) |

### `pre_update_version` / `post_update_version`

Fires around: re-resolving a floating version and reinstalling its tracked packages.

| Variable | Value | Available in |
|---|---|---|
| `$version` | The version being updated (as passed on the command line or from the managed list) | Both |
| `$current_full` | The exact release currently resolved by `$version`'s symlink chain, before this update | Both |
| `$latest_full` | The exact release `$version` resolves to as of this run (may equal `$current_full`) | Both |
| `$dots` | `0`, `1`, or `2` — how precise `$version` was specified | Both |
| `$link` | `${NODEJS_ROOT}/${version}` | Both |
| `$install_version_result` | JSON object stored as string. Contain the result of the `install_version()` called to update current floating version. Usefull to read the `code` or the `changed` values and adapt hook actions.| `post_update_version` |

### `pre_install_packages` / `post_install_packages`

Fires around: installing/updating packages currently defined in `$PACKAGES_VERSION_POLICY`/`$PACKAGES_SOURCE` for a version. From `install` or `update` this contains all tracked package for a version. And from `pkg_add` this contain only the package requested via CLI.

| Variable | Value |
|---|---|
| `$version` | The version packages are being installed for (can be `default`, though `default` never actually triggers an npm install) |
| `$PACKAGES_VERSION_POLICY` | Associative array keyed by package name containing the requested version constraint (empty string means "latest"). |
| `$PACKAGES_SOURCE` | Associative array keyed by package name containing the source of truth for the package version (`default`, a specific version file, `cli`, or a `migrated` on version update) |

### `pre_del_package` / `post_del_package`

Fires around: untracking (and possibly uninstalling) one package from one version.

| Variable | Value | Available in |
|---|---|---|
| `$version` | The version being modified | both |
| `$package` | The package argument exactly as given | both |
| `$pkg_installed` | `"true"`/`"false"` — whether the package was physically installed on function call (Not updated after action ran) | both |
| `$pkg_tracked` | `"true"`/`"false"` — whether this version's own config file tracked it (Not updated after action ran) | both |
| `$npm` | Path to this version's `npm` wrapper, `${BIN_DIR}/npm${version}` | both |
| `$versions_using_package` | Bash array of linked versions (plus `"default"` if applicable) still requiring this package — only meaningful when non-empty | `post_del_package` only (not yet computed when the pre-hook fires) |

## Points with no hooks

For completeness — these operations currently have **no** hook points at all: `pkg_add` (adding/installing a package, use *_install_packages hooks), `list`, `pkg_list`, `remove`'s file-walk loop itself (only the overall `pre_remove_version`/`post_remove_version` wrap it — see below).

`remove` is a special case: it wraps the whole multi-step removal in `pre_remove_version`/`post_remove_version`, with the same `$version` variable as the other version-level hooks, but the actual per-path-segment removal loop and the internal `unmanage_version` call it triggers are not separately hookable.

## Example hook file

```bash
# /etc/nodejs-system-manager/hooks/pre_install_version.sh

pre_install_version() {
    echo "About to install Node.js ${full}" >&2
    # Block installs of a version we know is broken in our environment
    if [[ "$full" == "24.0.0" ]]; then
        log_error "24.0.0 is blocked in this environment, use 24.1.0+"
        return 1
    fi
    return 0
}

# /etc/nodejs-system-manager/hooks/pre_manage_version.sh

pre_manage_version() {
    # Skip managing anything outside our approved major versions
    case "${version%%.*}" in
        20|22|24) : ;;
        *)
            HOOK_ACTION=skip
            return 0
            ;;
    esac
}

# /etc/nodejs-system-manager/hooks/post_update_version.sh

post_del_package() {
    if jq -e '.changed' <<< "$install_version_result" >/dev/null; then
        local svc="nodejs${version}-services.target"
        log_info "Restart service: $svc"
        run_cmd systemctl restart "$svc"
    else
        log_info "No changes, no service to restart"
    fi
}
```

Hooks can call the script's own logging functions (`log_info`, `log_warn`, `log_error`, `log_debug`, `log_success`) directly, since they run in the same process — this keeps hook output consistent with the rest of the script's log formatting, timestamps, and `--json`/`--quiet` behavior.  

