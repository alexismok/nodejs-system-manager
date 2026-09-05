#!/usr/bin/env bats

load ../helpers

setup() {
    bats_require_minimum_version 1.5.0
    _setup_test_env
    # Sourced to use init and define some variable used by helpers
    source ./nodejs-system-manager
    init
}

@test "remove missing version" {

    run --separate-stderr ./nodejs-system-manager remove
    
    [[ "$status" -ne 0 ]]
    [[ "$stderr" =~ Missing[[:space:]]version[[:space:]]number ]]
    _assert_json_code MISSING_VERSION
}

@test "remove not installed version" {

    run --separate-stderr ./nodejs-system-manager remove 24
    
    [[ "$status" -eq 0 ]]
    [[ "$stderr" =~ Version[[:space:]]not[[:space:]]installed ]]
    _assert_json_code VERSION_NOT_INSTALLED
}

@test "remove blocked" {

    _create_version 24.19.0
    _link_versions "24.19" "24.19.0"
    _link_versions "24" "24.19"

    _manage_version 24

    run --separate-stderr ./nodejs-system-manager remove 24.19.0
    
    [[ "$status" -ne 0 ]]
    [[ "$stderr" =~ Version[[:space:]]\'24.19.0\'[[:space:]]cannot[[:space:]]be[[:space:]]removed ]]
    _assert_json_code REMOVE_BLOCKED

    [[ -d "${NODEJS_ROOT}/24" ]]
    [[ -d "${NODEJS_ROOT}/24.19" ]]
    [[ -d "${NODEJS_ROOT}/24.19.0" ]]

    grep -qxF 24 "$MANAGED_FILE"
    [[ -L "${BIN_DIR}/node24" ]]
    [[ -f "${BIN_DIR}/npm24" ]]
    [[ -f "${BIN_DIR}/npx24" ]]
}

@test "remove success" {

    _create_version 24.19.0
    _link_versions "24.19" "24.19.0"
    _link_versions "24" "24.19"

    _manage_version 24

    run --separate-stderr ./nodejs-system-manager remove 24
    
    [[ "$status" -eq 0 ]]
    [[ "$stderr" =~ Successfully[[:space:]]removed[[:space:]]version:[[:space:]]24 ]]
    _assert_json_code VERSION_REMOVED

    [[ ! -d "${NODEJS_ROOT}/24" ]]
    [[ ! -d "${NODEJS_ROOT}/24.19" ]]
    [[ ! -d "${NODEJS_ROOT}/24.19.0" ]]

    run grep -qxF 24 "$MANAGED_FILE"
    [[ "$status" -ne 0 ]]
    [[ ! -L "${BIN_DIR}/node24" ]]
    [[ ! -f "${BIN_DIR}/npm24" ]]
    [[ ! -f "${BIN_DIR}/npx24" ]]
}

@test "remove partial (minor)" {

    _create_version 24.19.0
    _link_versions 24.19 24.19.0
    _link_versions 24 24.19

    _manage_version 24
    _manage_version 24.19

    run --separate-stderr ./nodejs-system-manager remove 24
    
    [[ "$status" -eq 0 ]]
    [[ "$stderr" =~ Version[[:space:]]24[[:space:]]removed,[[:space:]]but[[:space:]]some[[:space:]]versions[[:space:]]were[[:space:]]retained ]]
    _assert_json_code VERSION_PARTIALLY_REMOVED

    [[ ! -d "${NODEJS_ROOT}/24" ]]
    [[ -d "${NODEJS_ROOT}/24.19" ]]
    [[ -d "${NODEJS_ROOT}/24.19.0" ]]

    run grep -qxF 24 "$MANAGED_FILE"
    [[ "$status" -ne 0 ]]
    [[ ! -L "${BIN_DIR}/node24" ]]
    [[ ! -f "${BIN_DIR}/npm24" ]]
    [[ ! -f "${BIN_DIR}/npx24" ]]

    grep -qxF 24.19 "$MANAGED_FILE"
    [[ -L "${BIN_DIR}/node24.19" ]]
    [[ -f "${BIN_DIR}/npm24.19" ]]
    [[ -f "${BIN_DIR}/npx24.19" ]]
}

@test "remove partial (patch)" {

    _create_version 24.19.0
    _link_versions 24.19 24.19.0
    _link_versions 24 24.19

    _manage_version 24
    _manage_version 24.19.0

    run --separate-stderr ./nodejs-system-manager remove 24
    
    [[ "$status" -eq 0 ]]
    [[ "$stderr" =~ Version[[:space:]]24[[:space:]]removed,[[:space:]]but[[:space:]]some[[:space:]]versions[[:space:]]were[[:space:]]retained ]]
    _assert_json_code VERSION_PARTIALLY_REMOVED

    [[ ! -d "${NODEJS_ROOT}/24" ]]
    [[ ! -d "${NODEJS_ROOT}/24.19" ]]
    [[ -d "${NODEJS_ROOT}/24.19.0" ]]

    run grep -qxF 24 "$MANAGED_FILE"
    [[ "$status" -ne 0 ]]
    [[ ! -L "${BIN_DIR}/node24" ]]
    [[ ! -f "${BIN_DIR}/npm24" ]]
    [[ ! -f "${BIN_DIR}/npx24" ]]

    grep -qxF 24.19.0 "$MANAGED_FILE"
    [[ -L "${BIN_DIR}/node24.19.0" ]]
    [[ -f "${BIN_DIR}/npm24.19.0" ]]
    [[ -f "${BIN_DIR}/npx24.19.0" ]]
}

@test "remove pre_remove_version hook fail" {

    _create_version 24.19.0
    _link_versions 24.19 24.19.0
    _link_versions 24 24.19

    _mok_hook_fail pre_remove_version

    _manage_version 24

    run --separate-stderr ./nodejs-system-manager remove 24
    
    [[ "$status" -ne 0 ]]
    [[ "$stderr" =~ Hook[[:space:]]\'pre_remove_version\'[[:space:]]failed ]]
    _assert_json_code HOOK_FAILED

    [[ -d "${NODEJS_ROOT}/24" ]]
    [[ -d "${NODEJS_ROOT}/24.19" ]]
    [[ -d "${NODEJS_ROOT}/24.19.0" ]]

    grep -qxF 24 "$MANAGED_FILE"
    [[ -L "${BIN_DIR}/node24" ]]
    [[ -f "${BIN_DIR}/npm24" ]]
    [[ -f "${BIN_DIR}/npx24" ]]
}

@test "remove pre_remove_version hook skip" {

    _create_version 24.19.0
    _link_versions 24.19 24.19.0
    _link_versions 24 24.19

    _mok_hook_skip pre_remove_version

    _manage_version 24

    run --separate-stderr ./nodejs-system-manager remove 24
    
    [[ "$status" -eq 0 ]]
    [[ "$stderr" =~ skipped[[:space:]]by[[:space:]]hook[[:space:]]pre_remove_version ]]
    _assert_json_code HOOK_SKIPPED

    [[ -d "${NODEJS_ROOT}/24" ]]
    [[ -d "${NODEJS_ROOT}/24.19" ]]
    [[ -d "${NODEJS_ROOT}/24.19.0" ]]

    grep -qxF 24 "$MANAGED_FILE"
    [[ -L "${BIN_DIR}/node24" ]]
    [[ -f "${BIN_DIR}/npm24" ]]
    [[ -f "${BIN_DIR}/npx24" ]]
}

@test "remove success with hooks" {

    _create_version 24.19.0
    _link_versions "24.19" "24.19.0"
    _link_versions "24" "24.19"

    _manage_version 24

    _mok_hook_success pre_remove_version
    _mok_hook_success post_remove_version

    run --separate-stderr ./nodejs-system-manager remove 24
    
    [[ "$status" -eq 0 ]]
    [[ "$stderr" =~ Successfully[[:space:]]removed[[:space:]]version:[[:space:]]24 ]]
    _assert_json_code VERSION_REMOVED

    [[ ! -d "${NODEJS_ROOT}/24" ]]
    [[ ! -d "${NODEJS_ROOT}/24.19" ]]
    [[ ! -d "${NODEJS_ROOT}/24.19.0" ]]

    run grep -qxF 24 "$MANAGED_FILE"
    [[ "$status" -ne 0 ]]
    [[ ! -L "${BIN_DIR}/node24" ]]
    [[ ! -f "${BIN_DIR}/npm24" ]]
    [[ ! -f "${BIN_DIR}/npx24" ]]

    [[ -f "${TEST_ROOT}/pre_remove_version" ]]
    [[ -f "${TEST_ROOT}/post_remove_version" ]]
}