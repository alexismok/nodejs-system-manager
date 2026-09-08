# Changelog

## [1.1.0] - 2026-09-09

- Add: Reading global configuration from file `CONFIG_DIR/config`
- Add: Option to also send log to a file via `--log-file` or `LOG_FILE`
- Add: New action `dump_config` to show global configuration loaded

- Fix: Remove not implemented option from docs
- Fix: action data not sent to run_pre_hook function which hide them from the final output if the hook fail or skip the action.

## [1.0.0] - 2026-09-05

- First release