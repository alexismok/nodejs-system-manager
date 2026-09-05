#!/usr/bin/env bats

load ../helpers

setup() {
    bats_require_minimum_version 1.5.0
    _setup_test_env
    # Sourced to use init and define some variable used by helpers
    source ./nodejs-system-manager
    init
}

@test "pkg_add missing version" {

    run --separate-stderr ./nodejs-system-manager pkg_add
    
    [[ "$status" -ne 0 ]]
    [[ "$stderr" =~ Missing[[:space:]]version[[:space:]]number ]]
    _assert_json_code MISSING_VERSION
}

@test "pkg_add missing package" {

    run --separate-stderr ./nodejs-system-manager pkg_add 24
    
    [[ "$status" -ne 0 ]]
    [[ "$stderr" =~ Missing[[:space:]]package ]]
    _assert_json_code MISSING_PACKAGE
}

@test "pkg_add invalid package name" {
    _create_version 24
    _manage_version 24

    run --separate-stderr ./nodejs-system-manager pkg_add 24 zzz@
    
    [[ "$status" -ne 0 ]]
    [[ "$stderr" =~ Invalid[[:space:]]package[[:space:]]name: ]]
    _assert_json_code INVALID_PACKAGE_NAME
}

@test "pkg_add to not installed version" {

    run --separate-stderr ./nodejs-system-manager pkg_add 24 pnpm@^5
    
    [[ "$status" -ne 0 ]]
    [[ "$stderr" =~ Node.js[[:space:]]version[[:space:]]24[[:space:]]not[[:space:]]installed ]]
    _assert_json_code VERSION_NOT_INSTALLED
}

@test "pkg_add not managed version" {
    _create_version 24

    _mok_npm 24

    run --separate-stderr ./nodejs-system-manager pkg_add 24 pnpm@^5

    [[ "$status" -ne 0 ]]
    [[ "$stderr" =~ Cannot[[:space:]]add[[:space:]]package[[:space:]]to[[:space:]]unmanaged[[:space:]]version:[[:space:]]24 ]]
    _assert_json_code VERSION_NOT_MANAGED
}

@test "pkg_add success" {
    _create_version 24
    _manage_version 24

    _mok_npm 24

    run --separate-stderr ./nodejs-system-manager pkg_add 24 pnpm@^5

    [[ "$status" -eq 0 ]]
    [[ "$stderr" =~ Successfully[[:space:]]added[[:space:]]package:[[:space:]]pnpm@\^5 ]]
    _assert_json_code PACKAGES_INSTALLED

    grep -xqF "pnpm@^5" "${PACKAGES_DIR}/24"
}

@test "pkg_add fail" {
    _create_version 24
    _manage_version 24

    _mok_npm 24

    run --separate-stderr ./nodejs-system-manager pkg_add 24 "fail@^5"

    [[ "$status" -ne 0 ]]
    [[ "$stderr" =~ Package[[:space:]]installation[[:space:]]failed:[[:space:]]fail@\^5 ]]
    _assert_json_code PACKAGES_INSTALLATION_FAILED

    [[ ! -f "${PACKAGES_DIR}/24" ]] || run ! grep -xqF "fail@^5" "${PACKAGES_DIR}/24"
}

@test "pkg_add default package" {

    run --separate-stderr ./nodejs-system-manager pkg_add default pnpm@^5

    [[ "$status" -eq 0 ]]
    [[ "$stderr" =~ Successfully[[:space:]]added[[:space:]]package:[[:space:]]pnpm@\^5 ]]
    _assert_json_code PACKAGE_ADDED_AS_DEFAULT

    grep -xqF "pnpm@^5" "${PACKAGES_DIR}/default"
}

@test "pkg_add already installed and tracked package" {
    
    _create_version 24
    _manage_version 24

    _mok_npm 24

    "${BIN_DIR}/npm24" install -g --json pnpm >/dev/null
    echo "pnpm" > "${PACKAGES_DIR}/24"

    run --separate-stderr ./nodejs-system-manager pkg_add 24 pnpm@^5

    [[ "$status" -eq 0 ]]
    [[ "$stderr" =~ Package[[:space:]]already[[:space:]]installed ]]
    _assert_json_code PACKAGE_ALREADY_INSTALLED

    grep -xqF "pnpm" "${PACKAGES_DIR}/24"
}

@test "pkg_add already installed and not tracked package" {
    
    _create_version 24
    _manage_version 24

    _mok_npm 24

    "${BIN_DIR}/npm24" install -g --json pnpm >/dev/null

    run --separate-stderr ./nodejs-system-manager pkg_add 24 pnpm@^5

    [[ "$status" -eq 0 ]]
    [[ "$stderr" =~ Package[[:space:]]already[[:space:]]installed[[:space:]]but[[:space:]]not[[:space:]]tracked ]]
    _assert_json_code PACKAGE_TRACKED

    grep -xqF "pnpm@^5" "${PACKAGES_DIR}/24"
}

@test "pkg_add already tracked but not installed package" {
    
    _create_version 24
    _manage_version 24

    _mok_npm 24

    echo "pnpm" > "${PACKAGES_DIR}/24"

    run --separate-stderr ./nodejs-system-manager pkg_add 24 pnpm@^5

    [[ "$status" -eq 0 ]]
    [[ "$stderr" =~ Successfully[[:space:]]added[[:space:]]package:[[:space:]]pnpm@\^5 ]]
    [[ "$stderr" =~ Package[[:space:]]already[[:space:]]tracked[[:space:]]but[[:space:]]not[[:space:]]installed,[[:space:]]installing[[:space:]]it... ]]
    _assert_json_code PACKAGES_INSTALLED

}

@test "pkg_add already tracked by a linked version same target and installed" {
    
    _create_version 24.1
    _manage_version 24.1
    _link_versions 24 24.1
    _manage_version 24

    _mok_npm 24.1
    _link_npm 24 24.1

    "${BIN_DIR}/npm24.1" install -g --json pnpm@^5 >/dev/null
    echo "pnpm@^5" > "${PACKAGES_DIR}/24.1"

    run --separate-stderr ./nodejs-system-manager pkg_add 24 pnpm@^5

    [[ "$status" -eq 0 ]]
    [[ "$stderr" =~ Package[[:space:]]already[[:space:]]installed[[:space:]]but[[:space:]]not[[:space:]]tracked ]]
    _assert_json_code PACKAGE_TRACKED

    grep -xqF "pnpm@^5" "${PACKAGES_DIR}/24.1"

}

@test "pkg_add already tracked by a linked version different target" {
    
    _create_version 24.1
    _manage_version 24.1
    _link_versions 24 24.1
    _manage_version 24

    _mok_npm 24.1
    _link_npm 24 24.1

    "${BIN_DIR}/npm24.1" install -g --json pnpm@^5 >/dev/null
    echo "pnpm@^5" > "${PACKAGES_DIR}/24.1"

    run --separate-stderr ./nodejs-system-manager pkg_add 24 pnpm@^6

    [[ "$status" -ne 0 ]]
    [[ "$stderr" =~ Package[[:space:]]\'pnpm\'[[:space:]]is[[:space:]]tracked[[:space:]]by[[:space:]]linked[[:space:]]versions[[:space:]]with[[:space:]]a[[:space:]]different[[:space:]]target ]]
    _assert_json_code PACKAGE_TARGET_MISMATCH_WITH_LINKED_VERSION

    grep -xqF "pnpm@^5" "${PACKAGES_DIR}/24.1"
}

