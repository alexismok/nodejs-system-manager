#!/usr/bin/env bats

load ../helpers

setup() {
    bats_require_minimum_version 1.5.0
    _setup_test_env
    # Sourced to use init and define some variable used by helpers
    source ./nodejs-system-manager
    init
}

@test "manage not installed version" {
    run --separate-stderr ./nodejs-system-manager manage 24

    [[ "$status" -ne 0 ]]
    [[ "$stderr" =~ Version[[:space:]]not[[:space:]]installed ]]
    _assert_json_code VERSION_NOT_INSTALLED
}

@test "manage already managed version" {
    _create_version 24
    _manage_version 24

    run --separate-stderr ./nodejs-system-manager manage 24

    [[ "$status" -eq 0 ]]
    [[ "$stderr" =~ Version[[:space:]]already[[:space:]]managed ]]
    _assert_json_code VERSION_ALREADY_MANAGED

    run grep -c '^24$' "$MANAGED_FILE"
    [[ "$output" = "1" ]]
}

@test "manage version" {
    _create_version 24

    run --separate-stderr ./nodejs-system-manager manage 24

    [[ "$status" -eq 0 ]]
    [[ "$stderr" =~ Successfully[[:space:]]managed[[:space:]]version:[[:space:]]24 ]]
    _assert_json_code VERSION_MANAGED

    grep -qxF 24 "$MANAGED_FILE"
    [[ -L "${BIN_DIR}/node24" ]]
    [[ -x "${BIN_DIR}/npm24" ]]
    [[ -x "${BIN_DIR}/npx24" ]]
}
