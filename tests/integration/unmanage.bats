#!/usr/bin/env bats

load ../helpers

setup() {
    bats_require_minimum_version 1.5.0
    _setup_test_env
    # Sourced to use init and define some variable used by helpers
    source ./nodejs-system-manager
    init
}

@test "unmanage version" {
    _create_version 24
    _manage_version 24

    run --separate-stderr ./nodejs-system-manager unmanage 24

    [[ "$status" -eq 0 ]]
    [[ "$stderr" =~ Successfully[[:space:]]unmanaged[[:space:]]version:[[:space:]]24 ]]
    _assert_json_code VERSION_UNMANAGED

    run grep -qxF 24 "$MANAGED_FILE"
    [[ "$status" -ne 0 ]]
    [[ ! -L "${BIN_DIR}/node24" ]]
    [[ ! -f "${BIN_DIR}/npm24" ]]
    [[ ! -f "${BIN_DIR}/npx24" ]]
}

@test "unmanage not installed version" {
    run --separate-stderr ./nodejs-system-manager unmanage 24

    [[ "$status" -ne 0 ]]
    [[ "$stderr" =~ Version[[:space:]]not[[:space:]]installed ]]
    _assert_json_code VERSION_NOT_INSTALLED
}

@test "unmanage already unmanaged version" {
    _create_version 24

    run --separate-stderr ./nodejs-system-manager unmanage 24

    [[ "$status" -eq 0 ]]
    [[ "$stderr" =~ Version[[:space:]]not[[:space:]]managed ]]
    _assert_json_code VERSION_NOT_MANAGED
}
