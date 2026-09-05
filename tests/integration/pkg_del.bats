#!/usr/bin/env bats

load ../helpers

setup() {
    bats_require_minimum_version 1.5.0
    _setup_test_env
    # Sourced to use init and define some variable used by helpers
    source ./nodejs-system-manager
    init
}

@test "pkg_del missing version" {

    run --separate-stderr ./nodejs-system-manager pkg_del
    
    [[ "$status" -ne 0 ]]
    [[ "$stderr" =~ Missing[[:space:]]version[[:space:]]number ]]
    _assert_json_code MISSING_VERSION
}

@test "pkg_del missing package" {

    run --separate-stderr ./nodejs-system-manager pkg_del 24
    
    [[ "$status" -ne 0 ]]
    [[ "$stderr" =~ Missing[[:space:]]package ]]
    _assert_json_code MISSING_PACKAGE
}

@test "pkg_del invalid package name" {
    _create_version 24
    _manage_version 24

    run --separate-stderr ./nodejs-system-manager pkg_del 24 zzz@
    
    [[ "$status" -ne 0 ]]
    [[ "$stderr" =~ Invalid[[:space:]]package[[:space:]]name: ]]
    _assert_json_code INVALID_PACKAGE_NAME
}

@test "pkg_del version not installed" {

    run --separate-stderr ./nodejs-system-manager pkg_del 24 pnpm
    
    [[ "$status" -ne 0 ]]
    [[ "$stderr" =~ Node.js[[:space:]]version[[:space:]]24[[:space:]]not[[:space:]]installed ]]
    _assert_json_code VERSION_NOT_INSTALLED
}

@test "pkg_del version not managed" {
    _create_version 24

    run --separate-stderr ./nodejs-system-manager pkg_del 24 pnpm

    [[ "$status" -ne 0 ]]
    [[ "$stderr" =~ Cannot[[:space:]]delete[[:space:]]package[[:space:]]from[[:space:]]unmanaged[[:space:]]version:[[:space:]]24 ]]
    _assert_json_code VERSION_NOT_MANAGED
}

@test "pkg_del success" {
    _create_version 24
    _manage_version 24
    echo 'pnpm@^5' > "${PACKAGES_DIR}/24"

    _mok_npm 24
    "${BIN_DIR}/npm24" install -g --json pnpm@^5 >/dev/null

    run --separate-stderr ./nodejs-system-manager pkg_del 24 pnpm

    [[ "$status" -eq 0 ]]
    [[ "$stderr" =~ Successfully[[:space:]]removed[[:space:]]package:[[:space:]]pnpm ]]
    _assert_json_code PACKAGE_REMOVED

    echo "FILE CONTENT:"
    cat "${PACKAGES_DIR}/24"
    run ! grep -xqF "pnpm@^5" "${PACKAGES_DIR}/24"
}

@test "pkg_del fail" {
    _create_version 24
    _manage_version 24
    echo 'faildelpkg@^5' > "${PACKAGES_DIR}/24"

    _mok_npm 24

    "${BIN_DIR}/npm24" install -g --json faildelpkg@^5 >/dev/null

    run --separate-stderr ./nodejs-system-manager pkg_del 24 faildelpkg

    [[ "$status" -ne 0 ]]
    [[ "$stderr" =~ Package[[:space:]]removal[[:space:]]failed:[[:space:]]faildelpkg ]]
    _assert_json_code PACKAGE_REMOVAL_FAILED

    [[ -f "${PACKAGES_DIR}/24" ]] && grep -xqF "faildelpkg@^5" "${PACKAGES_DIR}/24"
}

@test "pkg_del default package" {
    echo 'pnpm@^5' > "${PACKAGES_DIR}/default"

    run --separate-stderr ./nodejs-system-manager pkg_del default pnpm

    [[ "$status" -eq 0 ]]
    [[ "$stderr" =~ Successfully[[:space:]]removed[[:space:]]package[[:space:]]from[[:space:]]default: ]]
    _assert_json_code PACKAGE_REMOVED_FROM_DEFAULT

    run ! grep -xqF "pnpm@^5" "${PACKAGES_DIR}/default"
}

@test "pkg_del not tracked" {
    _create_version 24
    _manage_version 24

    run --separate-stderr ./nodejs-system-manager pkg_del 24 pnpm

    [[ "$status" -eq 0 ]]
    [[ "$stderr" =~ Package[[:space:]]not[[:space:]]tracked[[:space:]]by[[:space:]]this[[:space:]]version,[[:space:]]nothing[[:space:]]to[[:space:]]do ]]
    _assert_json_code PACKAGE_NOT_TRACKED
}

@test "pkg_del not installed" {
    _create_version 24
    _manage_version 24
    echo 'pnpm@^5' > "${PACKAGES_DIR}/24"

    _mok_npm 24

    run --separate-stderr ./nodejs-system-manager pkg_del 24 pnpm

    [[ "$status" -eq 0 ]]
    [[ "$stderr" =~ Package[[:space:]]were[[:space:]]not[[:space:]]installed,[[:space:]]untracked[[:space:]]it ]]
    _assert_json_code PACKAGE_UNTRACKED
}

@test "pkg_del tracked by another version" {
    _create_version 24.1
    _manage_version 24.1
    _link_versions 24 24.1
    _manage_version 24

    echo 'pnpm@^5' > "${PACKAGES_DIR}/24.1"
    echo 'pnpm@^5' > "${PACKAGES_DIR}/24"

    _mok_npm 24.1
    _link_npm 24 24.1

    run --separate-stderr ./nodejs-system-manager pkg_del 24 pnpm

    [[ "$status" -eq 0 ]]
    [[ "$stderr" =~ Package[[:space:]]is[[:space:]]required[[:space:]]by[[:space:]]versions ]]
    _assert_json_code PACKAGE_UNTRACKED_STILL_REQUIRED

    grep -xqF 'pnpm@^5' "${PACKAGES_DIR}/24.1"
    [[ -f "${PACKAGES_DIR}/24" ]] && ! grep -xqF 'pnpm@^5' "${PACKAGES_DIR}/24"
}
