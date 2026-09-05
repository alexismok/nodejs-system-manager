#!/usr/bin/env bats

load ../helpers

setup() {
    bats_require_minimum_version 1.5.0
    _setup_test_env
    # Sourced to use init and define some variable used by helpers
    source ./nodejs-system-manager
    init
}

@test "install missing version" {

    run --separate-stderr ./nodejs-system-manager install
    
    [[ "$status" -ne 0 ]]
    [[ "$stderr" =~ Missing[[:space:]]version[[:space:]]number ]]
    _assert_json_code MISSING_VERSION
}

@test "install invalid version" {

    run --separate-stderr ./nodejs-system-manager install toto
    
    [[ "$status" -ne 0 ]]
    [[ "$stderr" =~ Invalid[[:space:]]version: ]]
    _assert_json_code INVALID_VERSION
}

@test "install already installed version" {
    _create_version 24

    run --separate-stderr ./nodejs-system-manager install 24
    
    [[ "$status" -eq 0 ]]
    [[ "$stderr" =~ Version[[:space:]]already[[:space:]]installed ]]
    _assert_json_code VERSION_ALREADY_INSTALLED
}

@test "install unknown version" {

    run --separate-stderr ./nodejs-system-manager install 99999
    
    [[ "$status" -ne 0 ]]
    [[ "$stderr" =~ No[[:space:]]published[[:space:]]Node.js[[:space:]]release[[:space:]]match: ]]
    _assert_json_code VERSION_NOT_AVAILABLE
}

@test "install resolve fail" {
    
    _mok_curl x64 24.19.0 index

    run --separate-stderr ./nodejs-system-manager install 24
    
    [[ "$status" -ne 0 ]]
    [[ "$stderr" =~ No[[:space:]]published[[:space:]]Node.js[[:space:]]release[[:space:]]match: ]]
    _assert_json_code VERSION_NOT_AVAILABLE
}

@test "install tarball download fail" {
    
    _mok_curl x64 24.19.0 tarball

    run --separate-stderr ./nodejs-system-manager install 24
    
    [[ "$status" -ne 0 ]]
    [[ "$stderr" =~ Failed[[:space:]]to[[:space:]]download[[:space:]]Node.js[[:space:]]tarball ]]
    _assert_json_code TARBALL_DOWNLOAD_FAILED
}

@test "install shasums download fail" {
    
    _mok_curl x64 24.19.0 shasums

    run --separate-stderr ./nodejs-system-manager install 24
    
    [[ "$status" -ne 0 ]]
    [[ "$stderr" =~ Failed[[:space:]]to[[:space:]]download[[:space:]]SHASUMS256.txt ]]
    _assert_json_code SHASUMS_DOWNLOAD_FAILED
}

@test "install wrong shasums" {
    
    _mok_curl x64 24.19.0 wrong_shasums

    run --separate-stderr ./nodejs-system-manager install 24
    
    [[ "$status" -ne 0 ]]
    [[ "$stderr" =~ Checksum[[:space:]]verification[[:space:]]failed ]]
    _assert_json_code INVALID_CHECKSUM
}

@test "install success" {

    _mok_curl x64 24.19.0
    _mok_tar
    _mok_npm 24

    run --separate-stderr ./nodejs-system-manager install 24
    
    [[ "$status" -eq 0 ]]
    [[ "$stderr" =~ Successfully[[:space:]]installed[[:space:]]Node.js[[:space:]]version ]]
    _assert_json_code VERSION_INSTALLED

    [[ -x "${NODEJS_ROOT}/24/bin/node" ]]
    [[ -x "${NODEJS_ROOT}/24/bin/npm" ]]
    [[ -x "${NODEJS_ROOT}/24/bin/npx" ]]
    
    grep -qxF 24 "$MANAGED_FILE"
    [[ -L "${BIN_DIR}/node24" ]]
    [[ -x "${BIN_DIR}/npm24" ]]
    [[ -x "${BIN_DIR}/npx24" ]]
}

@test "install success with hooks" {

    _mok_curl x64 24.19.0
    _mok_tar

    _mok_hook_success pre_install_version
    _mok_hook_success post_install_version

    run --separate-stderr ./nodejs-system-manager install 24
    
    [[ "$status" -eq 0 ]]
    [[ "$stderr" =~ Successfully[[:space:]]installed[[:space:]]Node.js[[:space:]]version ]]
    _assert_json_code VERSION_INSTALLED

    [[ -x "${NODEJS_ROOT}/24/bin/node" ]]
    [[ -x "${NODEJS_ROOT}/24/bin/npm" ]]
    [[ -x "${NODEJS_ROOT}/24/bin/npx" ]]
    
    grep -qxF 24 "$MANAGED_FILE"
    [[ -L "${BIN_DIR}/node24" ]]
    [[ -x "${BIN_DIR}/npm24" ]]
    [[ -x "${BIN_DIR}/npx24" ]]

    [[ -f "${TEST_ROOT}/pre_install_version" ]]
    [[ -f "${TEST_ROOT}/post_install_version" ]]
}

@test "install pre_install_version hook failed" {

    _mok_curl x64 24.19.0

    _mok_hook_fail pre_install_version

    run --separate-stderr ./nodejs-system-manager install 24
    
    [[ "$status" -ne 0 ]]
    [[ "$stderr" =~ Hook[[:space:]]\'pre_install_version\'[[:space:]]failed ]]
    _assert_json_code HOOK_FAILED

    [[ ! -f "${NODEJS_ROOT}/24/bin/node" ]]
    [[ ! -f "${NODEJS_ROOT}/24/bin/npm" ]]
    [[ ! -f "${NODEJS_ROOT}/24/bin/npx" ]]
}

@test "install pre_install_version hook skip" {

    _mok_curl x64 24.19.0

    _mok_hook_skip pre_install_version

    run --separate-stderr ./nodejs-system-manager install 24
    
    [[ "$status" -eq 0 ]]
    [[ "$stderr" =~ skipped[[:space:]]by[[:space:]]hook[[:space:]]pre_install_version ]]
    _assert_json_code HOOK_SKIPPED

    [[ ! -f "${NODEJS_ROOT}/24/bin/node" ]]
    [[ ! -f "${NODEJS_ROOT}/24/bin/npm" ]]
    [[ ! -f "${NODEJS_ROOT}/24/bin/npx" ]]
}

@test "install post_install_version hook failed" {

    _mok_curl x64 24.19.0
    _mok_tar

    _mok_hook_fail post_install_version

    run --separate-stderr ./nodejs-system-manager install 24
    
    [[ "$status" -ne 0 ]]
    [[ "$stderr" =~ Hook[[:space:]]\'post_install_version\'[[:space:]]failed ]]
    _assert_json_code HOOK_FAILED

    [[ ! -f "${NODEJS_ROOT}/24/bin/node" ]]
    [[ ! -f "${NODEJS_ROOT}/24/bin/npm" ]]
    [[ ! -f "${NODEJS_ROOT}/24/bin/npx" ]]
}

@test "install version with existing resolved version" {

    _create_version 24.19.0
    _manage_version 24.19.0

    _mok_curl x64 24.19.0

    run --separate-stderr ./nodejs-system-manager install 24
    
    [[ "$status" -eq 0 ]]
    [[ "$stderr" =~ Successfully[[:space:]]managed[[:space:]]version:[[:space:]]24 ]]
    _assert_json_code VERSION_MANAGED

    [[ -x "${NODEJS_ROOT}/24/bin/node" ]]
    [[ -x "${NODEJS_ROOT}/24/bin/npm" ]]
    [[ -x "${NODEJS_ROOT}/24/bin/npx" ]]
    
    grep -qxF 24 "$MANAGED_FILE"
    [[ -L "${BIN_DIR}/node24" ]]
    [[ -x "${BIN_DIR}/npm24" ]]
    [[ -x "${BIN_DIR}/npx24" ]]
}

