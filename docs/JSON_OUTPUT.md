# JSON output reference

This document is the full reference for `--json`/`--json-compact` output. See the main [README](../README.md) for a general overview.

## Envelope shape

Every mutating action (everything except `list` and `pkg_list`) prints exactly one JSON object with this shape:

```json
{
  "status": "success",
  "changed": true,
  "code": "VERSION_INSTALLED",
  "msg": "Successfully installed Node.js",
  "data": {
    "...": "action-specific fields, see tables below"
  }
}
```

| Field | Type | Meaning |
|---|---|---|
| `status` | `"success"` \| `"warning"` \| `"error"` | Coarse outcome. See [Status and exit codes](#status-and-exit-codes) below. |
| `changed` | boolean | Whether the operation actually modified system state (files, symlinks, npm packages, config). |
| `code` | string | A stable, machine-matchable identifier for the specific outcome. See the per-action tables below. `code` values are only unique *within* the action that produced them — the same string can mean different things in different actions (noted where relevant). |
| `msg` | string | Human-readable summary, also what gets logged (via `log_success`/`log_warn`/`log_error`) in non-JSON mode. |
| `data` | object | Action-specific detail. Shape varies by `code` — not a fixed schema across every outcome of a given action. |

`list` and `pkg_list` are read-only and print their listing directly (no envelope, no `status`/`code`) since there's no success/failure outcome to report beyond the listing itself.

## Status and exit codes

| `status` | Exit code | Meaning |
|---|---|---|
| `success` | `0` | The operation achieved its goal successfully |
| `warning` | `0` | The operation completed, but something is worth reviewing (e.g. a version was only partially removed) |
| `error` | `1`, or a hook's own exit code | The operation did not achieve its goal |

A hook that fails (`pre_*` or `post_*`) causes the whole action to report `status: "error"`, and the script's own exit code becomes **whatever the hook itself returned**, not a fixed `1` — hooks are free to use their own exit-code conventions.

## Hook-related codes (common to every action)

These can appear as the top-level `code` of *any* mutating action, since every action can trigger hooks:

| `code` | `status` | Meaning |
|---|---|---|
| `HOOK_FAILED` | `error` | A `pre_*` or `post_*` hook returned non-zero. `data.hook_name` names which one. If it was a `post_*` hook, the underlying change already happened even though the overall result is an error — hooks cannot roll back completed work. |
| `HOOK_SKIPPED` | `success` | A `pre_*` hook set `HOOK_ACTION=skip`. The operation was not performed; `data.hook_name` names the hook that requested the skip. |

`CRITICAL_ERROR` can also be emitted (via `die()`) for startup-level failures that aren't tied to a specific action — missing required commands, an unrecognized CLI flag, or lock acquisition failure. These print to stderr and exit `1` before any action-specific logic runs.

## `install`

| `code` | `status` | `changed` | Meaning |
|---|---|---|---|
| `MISSING_VERSION` | error | false | No version argument given |
| `INVALID_VERSION` | error | false | Version doesn't match `MAJOR[.MINOR[.PATCH]]` |
| `VERSION_ALREADY_INSTALLED` | success | false | Already installed at the exact requested path; use `--force` |
| `VERSION_NOT_AVAILABLE` | error | false | No published Node.js release matches the requested version |
| `UNSUPPORTED_ARCH` | error | false | Host architecture isn't `x86_64`/`aarch64`/`arm64` |
| `TARBALL_DOWNLOAD_FAILED` | error | false | Couldn't download the Node.js tarball |
| `SHASUMS_DOWNLOAD_FAILED` | error | false | Couldn't download `SHASUMS256.txt` |
| `INVALID_CHECKSUM` | error | false | Downloaded tarball failed checksum verification |
| `FOLDER_CREATION_FAILED` | error | false | Couldn't create the target install directory |
| `TARBALL_EXTRACT_FAILED` | error | false | `tar` extraction failed |
| `UNKNOWN_ERROR` | error | false | Internal fallback for an unrecognized failure code |
| `VERSION_MANAGED` | success | varies | While `VERSION_ALREADY_INSTALLED` is triggered if you try to install version 24 when version 24, 24.1 or 24.1.0 are already installed. When you first install version 24.1.0 then you try to install version 24 or 24.1 resolved to 24.1.0, it will create the symlink for this version, manage it and give this code |
| `PACKAGES_INSTALLATION_FAILED` | warning | true | Node.js installed fine, but one or more tracked packages failed to install |
| `VERSION_INSTALLED` | success | true | Full success — installed, linked, managed, packages installed |

`install`'s final report also embeds the raw result of the internal `install_version` step whenever it short-circuits — check `data.results.install_version.code` for the more specific reason (any code from the table above can appear there).

## `update`

Per-target-version codes (each appears inside `data.results[]` in the aggregate, and standalone if only one version was targeted):

| `code` | `status` | `changed` | Meaning |
|---|---|---|---|
| `VERSION_NOT_INSTALLED` | error | false | The version isn't actually installed (shouldn't normally occur for a managed version) |
| `VERSION_NOT_AVAILABLE` | error | false | Couldn't resolve a matching published release |
| `INVALID_VERSION` | error | false | A version in the managed list no longer matches the expected format |
| `VERSION_UP_TO_DATE` | success | false | Floating version already resolves to the latest release, no packages changed either |
| `VERSION_LINK_UPDATED` | success | true | The exact release was already installed, but the floating symlink didn't point at it yet — relinked |
| `VERSION_UPDATED` | success | true | Installed a newer release and/or updated tracked packages |
| *(any `install_packages` code, see below)* | — | — | Surfaces directly when packages fail while Node.js itself updated fine |

Aggregate codes (top-level result when updating more than one version, or the single-version result when no target is given):

| `code` | `status` | Meaning |
|---|---|---|
| `NO_VERSION_FOUND` | success | No managed versions exist to update |
| `UPDATE_SUCCESS` | success | Every targeted version updated successfully |
| `UPDATE_WARNING` | warning | At least one targeted version finished with `status: "warning"` |
| `UPDATE_FAILED` | error | At least one targeted version finished with `status: "error"` |

`data.results` always contains the full per-version array regardless of aggregate outcome.

## `remove`

| `code` | `status` | `changed` | Meaning |
|---|---|---|---|
| `MISSING_VERSION` | error | false | No version argument given |
| `VERSION_NOT_INSTALLED` | success | false | Nothing to remove — idempotent no-op |
| `INVALID_PATH` | error | varies | Walked into a symlink chain segment that no longer exists on disk |
| `REMOVE_BLOCKED` | error | varies | A segment is still referenced by another version's symlink, and can't be removed until that version is deleted first |
| `REMOVE_FAILED` | error | varies | A filesystem `rm` call failed |
| `HOOK_FAILED` | error | varies | See [Hook-related codes](#hook-related-codes-common-to-every-action) — can come from `pre_remove_version`, `post_remove_version`, or from the internal `unmanage_version` step |
| `VERSION_PARTIALLY_REMOVED` | warning | true | Some path segments were removed, others retained (managed or still-referenced) — see `data.retained[]` for versions and reasons (`"managed"` or `"referenced"`) |
| `VERSION_REMOVED` | success | true | The full chain was removed cleanly |

`data.removed[]` and `data.retained[]` list the path segment names involved in every outcome that reaches the removal loop.

## `manage`

| `code` | `status` | `changed` | Meaning |
|---|---|---|---|
| `MISSING_VERSION` | error | false | No version argument given |
| `VERSION_NOT_INSTALLED` | error | false | Can't manage a version that isn't installed on disk |
| `VERSION_ALREADY_MANAGED` | success | false | No-op — already managed |
| `VERSION_MANAGED` | success | true | Now managed: added to the managed list, `BIN_DIR` symlinks created |

## `unmanage`

| `code` | `status` | `changed` | Meaning |
|---|---|---|---|
| `MISSING_VERSION` | error | false | No version argument given |
| `VERSION_NOT_INSTALLED` | error | false | Nothing on disk to unmanage |
| `VERSION_NOT_MANAGED` | success | false | No-op — wasn't managed |
| `VERSION_UNMANAGED` | success | true | Removed from the managed list, `BIN_DIR` symlinks removed (installation files are untouched) |

## `pkg_add`

| `code` | `status` | `changed` | Meaning |
|---|---|---|---|
| `MISSING_VERSION` / `MISSING_PACKAGE` | error | false | Missing argument |
| `INVALID_PACKAGE_NAME` | error | false | Doesn't match npm package-name syntax |
| `VERSION_NOT_INSTALLED` | error | false | Target version isn't installed (`default` is exempt from this check) |
| `VERSION_NOT_MANAGED` | error | false | Target version isn't managed |
| `PACKAGE_ALREADY_INSTALLED` | success | false | Already installed at the requested spec and already tracked |
| `PACKAGE_TARGET_MISMATCH_WITH_LINKED_VERSION` | error | false | A linked version (see [Version hierarchy & linked versions](../README.md#version-hierarchy--linked-versions)) tracks this package name with a different version spec; `data.conflicts[]` lists which versions and what they track. |
| `PACKAGE_ADDED_AS_DEFAULT` | success | true | Added to the shared `default` package set (no install performed — `default` isn't a real version) |
| `PACKAGE_TRACKED` | success | true | Already installed outside of tracking; now added to the tracking file (no reinstall performed) |
| *(any `install_packages` code)* | — | — | The normal path — install actually ran; see the table below |

## `pkg_del`

| `code` | `status` | `changed` | Meaning |
|---|---|---|---|
| `MISSING_VERSION` / `MISSING_PACKAGE` | error | false | Missing argument |
| `INVALID_PACKAGE_NAME` | error | false | Doesn't match npm package-name syntax |
| `VERSION_NOT_INSTALLED` | error | false | Target version isn't installed |
| `VERSION_NOT_MANAGED` | error | false | Target version isn't managed |
| `PACKAGE_NOT_TRACKED` | success | false | This version's own config file doesn't track the package — no-op, nothing touched |
| `PACKAGE_REMOVAL_FAILED` | error | false | `npm uninstall` failed |
| `PACKAGE_UNTRACKED_STILL_REQUIRED` | warning | true | Untracked from this version's config, but the physical package was **kept installed** because a linked version (or the `default` set) still requires it; `data` includes which versions |
| `PACKAGE_REMOVED_FROM_DEFAULT` | success | true | Removed from the shared `default` set (no npm action — `default` isn't a real version) |
| `PACKAGE_REMOVED` | success | true | Untracked and physically uninstalled |
| `PACKAGE_UNTRACKED` | success | true | Untracked from config; it wasn't actually installed, so nothing to uninstall |

## `install_packages` (internal — surfaces inside `install`, `update`, `pkg_add`)

These are not a top-level action, but their `code` values appear directly as the outer `code` in `install`, `update`, and `pkg_add` whenever the packages step is the deciding factor:

| `code` | `status` | `changed` | Meaning |
|---|---|---|---|
| `PACKAGES_INSTALLATION_FAILED` | error | false | Every tracked package failed to install |
| `SOME_PACKAGES_INSTALLATION_FAILED` | error | true | At least one, but not all, tracked packages failed |
| `NO_PACKAGE_TO_INSTALL` | success | false | Nothing is tracked for this version |
| `PACKAGES_UP_TO_DATE` | success | false | Everything tracked is already installed at the right version |
| `PACKAGES_INSTALLED` | success | true | At least one package was newly installed, updated, or removed to match tracking |

`data.packages[]` (tracked packages) and `data.dependencies[]` (installed but untracked, e.g. transitive) each carry a per-package `status`: `"installed"`, `"updated"`, `"up_to_date"`, `"removed"`, or `"error"` (with an `error` field holding npm's own JSON error payload).
