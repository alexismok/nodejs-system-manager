#!/usr/bin/env bats

load ../helpers

setup() {
    bats_require_minimum_version 1.5.0
    _setup_test_env
    # Sourced to use init and define some variable used by helpers
    source ./nodejs-system-manager
    init
}

validate_packages() {
    local pkg
    for pkg in "$@"; do
        local version=""
        local status="installed"
        case "$pkg" in
            "fail")
                status="error"
                ;;
            "foo")
                version="14.3.2"
                ;;
            "bar")
                version="2"
                ;;
            "toto")
                version="1.0.0"
                ;;
        esac
        jq -e \
            --arg name "$pkg" \
            --arg version "$version" \
            --arg status "$status" \
            '.data.results[0].data.packages[] | select(.name == $name) | (.version // "") == $version and .status == $status' > /dev/null <<< "$output"
    done
}

@test "update unmanaged version" {

    run --separate-stderr ./nodejs-system-manager update 24

    [[ "$status" -ne 0 ]]
    [[ "$stderr" =~ Cannot[[:space:]]update[[:space:]]unmanaged[[:space:]]version ]]
    _assert_json_code VERSION_NOT_MANAGED
}

@test "update non installed version" {
    _manage_version 24

    run --separate-stderr ./nodejs-system-manager update 24

    [[ "$status" -ne 0 ]]
    [[ "$stderr" =~ Version[[:space:]]not[[:space:]]installed ]]
    _assert_json_code UPDATE_FAILED
}

@test "update no version found" {

    run --separate-stderr ./nodejs-system-manager update

    [[ "$status" -eq 0 ]]
    [[ "$stderr" =~ No[[:space:]]version[[:space:]]to[[:space:]]update[[:space:]]found, ]]
    _assert_json_code NO_VERSION_FOUND
}

@test "update packages only" {

    _create_version 24
    _manage_version 24

    {
        echo "foo@14.3.2"
        echo "bar@2"
    } > "${CONFIG_DIR}/packages/24"

    {
        echo "foo@13"
        echo "toto"
    } > "${CONFIG_DIR}/packages/default"

    _mok_npm 24

    run --separate-stderr ./nodejs-system-manager update --packages-only

    [[ "$status" -eq 0 ]]
    [[ "$stderr" =~ Successfully[[:space:]]installed[[:space:]]packages[[:space:]]for[[:space:]]version:[[:space:]]24 ]]
    _assert_json_code UPDATE_SUCCESS
    jq -e '.status == "success"' <<< "$output"
    jq -e '.changed == true' <<< "$output"
    jq -e '.data.versions_changed == false' <<< "$output"
    jq -e '.data.packages_changed == true' <<< "$output"
    validate_packages foo bar toto
}

@test "update packages only - some packages failed" {

    _create_version 24
    _manage_version 24

    {
        echo "foo@14.3.2"
        echo "bar@2"
    } > "${CONFIG_DIR}/packages/24"

    {
        echo "fail@13"
        echo "toto"
    } > "${CONFIG_DIR}/packages/default"

    _mok_npm 24

    run --separate-stderr ./nodejs-system-manager update --packages-only

    [[ "$status" -ne 0 ]]
    [[ "$stderr" =~ Some[[:space:]]packages[[:space:]]installation[[:space:]]failed[[:space:]]for[[:space:]]version:[[:space:]]24 ]]
    _assert_json_code UPDATE_FAILED
    jq -e '.status == "error"' <<< "$output"
    jq -e '.changed == true' <<< "$output"
    jq -e '.data.versions_changed == false' <<< "$output"
    jq -e '.data.packages_changed == true' <<< "$output"
    jq -e '.data.results[0].code == "SOME_PACKAGES_INSTALLATION_FAILED"' <<< "$output"
    validate_packages "fail" foo bar toto
}

@test "update packages only - all packages failed" {

    _create_version 24
    _manage_version 24

    {
        echo "fail"
    } > "${CONFIG_DIR}/packages/24"

    _mok_npm 24

    run --separate-stderr ./nodejs-system-manager update --packages-only

    [[ "$status" -ne 0 ]]
    [[ "$stderr" =~ Packages[[:space:]]installation[[:space:]]failed[[:space:]]for[[:space:]]version:[[:space:]]24 ]]
    _assert_json_code UPDATE_FAILED
    jq -e '.status == "error"' <<< "$output"
    jq -e '.changed == false' <<< "$output"
    jq -e '.data.versions_changed == false' <<< "$output"
    jq -e '.data.packages_changed == false' <<< "$output"
    jq -e '.data.results[0].code == "PACKAGES_INSTALLATION_FAILED"' <<< "$output"
    validate_packages "fail"
}

@test "update minor from major" {

    _create_version 24.18.0
    _link_versions "24.18" "24.18.0"
    _link_versions "24" "24.18"
    _manage_version 24

    _mok_curl x64 24.19.0
    _mok_tar

    {
        echo "foo@14.3.2"
        echo "bar@2"
    } > "${CONFIG_DIR}/packages/24"

    {
        echo "foo@13"
        echo "toto"
    } > "${CONFIG_DIR}/packages/default"

    _mok_npm 24

    run --separate-stderr ./nodejs-system-manager update

    [[ "$status" -eq 0 ]]
    [[ "$stderr" =~ Successfully[[:space:]]installed[[:space:]]Node.js[[:space:]]version:[[:space:]]24.19.0 ]]
    _assert_json_code UPDATE_SUCCESS

    [[ -d "${NODEJS_ROOT}/24" ]]
    [[ -d "${NODEJS_ROOT}/24.19" ]]
    [[ -d "${NODEJS_ROOT}/24.19.0" ]]
    [[ ! -d "${NODEJS_ROOT}/24.18" ]]
    [[ ! -d "${NODEJS_ROOT}/24.18.0" ]]

    jq -e '.status == "success"' <<< "$output"
    jq -e '.changed == true' <<< "$output"
    jq -e '.data.versions_changed == true' <<< "$output"
    jq -e '.data.packages_changed == true' <<< "$output"
    jq -e '.data.results[0].data.from == "24.18.0"' <<< "$output"
    jq -e '.data.results[0].data.to == "24.19.0"' <<< "$output"
    validate_packages foo bar toto
}

@test "update patch from minor" {

    _create_version 24.18.0
    _link_versions "24.18" "24.18.0"
    _manage_version 24.18

    _mok_curl x64 24.18.1
    _mok_tar

    {
        echo "foo@14.3.2"
        echo "bar@2"
    } > "${CONFIG_DIR}/packages/24.18"

    {
        echo "foo@13"
        echo "toto"
    } > "${CONFIG_DIR}/packages/default"

    _mok_npm 24.18

    run --separate-stderr ./nodejs-system-manager update

    [[ "$status" -eq 0 ]]
    [[ "$stderr" =~ Successfully[[:space:]]installed[[:space:]]Node.js[[:space:]]version:[[:space:]]24.18.1 ]]
    _assert_json_code UPDATE_SUCCESS

    [[ -d "${NODEJS_ROOT}/24.18" ]]
    [[ -d "${NODEJS_ROOT}/24.18.1" ]]
    [[ ! -d "${NODEJS_ROOT}/24.18.0" ]]

    jq -e '.status == "success"' <<< "$output"
    jq -e '.changed == true' <<< "$output"
    jq -e '.data.versions_changed == true' <<< "$output"
    jq -e '.data.packages_changed == true' <<< "$output"
    jq -e '.data.results[0].data.from == "24.18.0"' <<< "$output"
    jq -e '.data.results[0].data.to == "24.18.1"' <<< "$output"
    validate_packages foo bar toto
}

@test "update minor from major - some packages failed" {

    _create_version 24.18.0
    _link_versions "24.18" "24.18.0"
    _link_versions "24" "24.18"
    _manage_version 24

    _mok_curl x64 24.19.0
    _mok_tar

    {
        echo "foo@14.3.2"
        echo "bar@2"
    } > "${CONFIG_DIR}/packages/24"

    {
        echo "fail@13"
        echo "toto"
    } > "${CONFIG_DIR}/packages/default"

    _mok_npm 24

    run --separate-stderr ./nodejs-system-manager update

    [[ "$status" -ne 0 ]]
    [[ "$stderr" =~ Successfully[[:space:]]installed[[:space:]]Node.js[[:space:]]version:[[:space:]]24.19.0 ]]
    [[ "$stderr" =~ Some[[:space:]]packages[[:space:]]installation[[:space:]]failed[[:space:]]for[[:space:]]version:[[:space:]]24 ]]
    _assert_json_code UPDATE_FAILED

    [[ -d "${NODEJS_ROOT}/24" ]]
    [[ -d "${NODEJS_ROOT}/24.19" ]]
    [[ -d "${NODEJS_ROOT}/24.19.0" ]]
    [[ ! -d "${NODEJS_ROOT}/24.18" ]]
    [[ ! -d "${NODEJS_ROOT}/24.18.0" ]]

    jq -e '.status == "error"' <<< "$output"
    jq -e '.changed == true' <<< "$output"
    jq -e '.data.results[0].data.version_changed == true' <<< "$output"
    jq -e '.data.results[0].data.packages_changed == true' <<< "$output"
    jq -e '.data.results[0].code == "SOME_PACKAGES_INSTALLATION_FAILED"' <<< "$output"
    validate_packages "fail" foo bar toto
}

@test "update minor from major - all packages failed" {

    _create_version 24.18.0
    _link_versions "24.18" "24.18.0"
    _link_versions "24" "24.18"
    _manage_version 24

    _mok_curl x64 24.19.0
    _mok_tar

    {
        echo "fail@14.3.2"
    } > "${CONFIG_DIR}/packages/24"

    _mok_npm 24

    run --separate-stderr ./nodejs-system-manager update

    [[ "$status" -ne 0 ]]
    [[ "$stderr" =~ Successfully[[:space:]]installed[[:space:]]Node.js[[:space:]]version:[[:space:]]24.19.0 ]]
    [[ "$stderr" =~ Packages[[:space:]]installation[[:space:]]failed[[:space:]]for[[:space:]]version:[[:space:]]24 ]]
    _assert_json_code UPDATE_FAILED

    [[ -d "${NODEJS_ROOT}/24" ]]
    [[ -d "${NODEJS_ROOT}/24.19" ]]
    [[ -d "${NODEJS_ROOT}/24.19.0" ]]
    [[ ! -d "${NODEJS_ROOT}/24.18" ]]
    [[ ! -d "${NODEJS_ROOT}/24.18.0" ]]

    jq -e '.status == "error"' <<< "$output"
    jq -e '.changed == true' <<< "$output"
    jq -e '.data.results[0].data.version_changed == true' <<< "$output"
    jq -e '.data.results[0].data.packages_changed == false' <<< "$output"
    jq -e '.data.results[0].code == "PACKAGES_INSTALLATION_FAILED"' <<< "$output"
    validate_packages "fail"
}

@test "update minor from major - update failed" {

    _create_version 24.18.0
    _link_versions "24.18" "24.18.0"
    _link_versions "24" "24.18"
    _manage_version 24

    _mok_curl x64 24.19.0 tarball
    _mok_tar

    _mok_npm 24

    run --separate-stderr ./nodejs-system-manager update

    [[ "$status" -ne 0 ]]
    [[ "$stderr" =~ Failed[[:space:]]to[[:space:]]download[[:space:]]Node.js[[:space:]]tarball ]]
    _assert_json_code UPDATE_FAILED

    [[ -d "${NODEJS_ROOT}/24" ]]
    [[ ! -d "${NODEJS_ROOT}/24.19" ]]
    [[ ! -d "${NODEJS_ROOT}/24.19.0" ]]
    [[ -d "${NODEJS_ROOT}/24.18" ]]
    [[ -d "${NODEJS_ROOT}/24.18.0" ]]

    jq -e '.status == "error"' <<< "$output"
    jq -e '.changed == false' <<< "$output"
    jq -e '.data.versions_changed == false' <<< "$output"
    jq -e '.data.packages_changed == false' <<< "$output"
    jq -e '.data.results[0].code == "TARBALL_DOWNLOAD_FAILED"' <<< "$output"
}

@test "update minor from major - pre_update_version hook failed" {

    _create_version 24.18.0
    _link_versions "24.18" "24.18.0"
    _link_versions "24" "24.18"
    _manage_version 24

    _mok_curl x64 24.19.0
    _mok_tar

    _mok_npm 24

    _mok_hook_fail pre_update_version

    run --separate-stderr ./nodejs-system-manager update

    [[ "$status" -ne 0 ]]
    [[ "$stderr" =~ Hook[[:space:]]\'pre_update_version\'[[:space:]]failed ]]
    _assert_json_code UPDATE_FAILED

    [[ -d "${NODEJS_ROOT}/24" ]]
    [[ ! -d "${NODEJS_ROOT}/24.19" ]]
    [[ ! -d "${NODEJS_ROOT}/24.19.0" ]]
    [[ -d "${NODEJS_ROOT}/24.18" ]]
    [[ -d "${NODEJS_ROOT}/24.18.0" ]]

    jq -e '.status == "error"' <<< "$output"
    jq -e '.changed == false' <<< "$output"
    jq -e '.data.versions_changed == false' <<< "$output"
    jq -e '.data.packages_changed == false' <<< "$output"
    jq -e '.data.results[0].code == "HOOK_FAILED"' <<< "$output"
}

@test "update minor from major - pre_update_version hook skipped" {

    _create_version 24.18.0
    _link_versions "24.18" "24.18.0"
    _link_versions "24" "24.18"
    _manage_version 24

    _mok_curl x64 24.19.0
    _mok_tar

    _mok_npm 24

    _mok_hook_skip pre_update_version

    run --separate-stderr ./nodejs-system-manager update

    [[ "$status" -eq 0 ]]
    [[ "$stderr" =~ skipped[[:space:]]by[[:space:]]hook[[:space:]]pre_update_version ]]
    _assert_json_code UPDATE_SUCCESS

    [[ -d "${NODEJS_ROOT}/24" ]]
    [[ ! -d "${NODEJS_ROOT}/24.19" ]]
    [[ ! -d "${NODEJS_ROOT}/24.19.0" ]]
    [[ -d "${NODEJS_ROOT}/24.18" ]]
    [[ -d "${NODEJS_ROOT}/24.18.0" ]]

    jq -e '.status == "success"' <<< "$output"
    jq -e '.changed == false' <<< "$output"
    jq -e '.data.versions_changed == false' <<< "$output"
    jq -e '.data.packages_changed == false' <<< "$output"
    jq -e '.data.results[0].code == "HOOK_SKIPPED"' <<< "$output"
}

@test "update minor from major - post_update_version hook failed" {

    _create_version 24.18.0
    _link_versions "24.18" "24.18.0"
    _link_versions "24" "24.18"
    _manage_version 24

    _mok_curl x64 24.19.0
    _mok_tar

    _mok_npm 24

    _mok_hook_fail post_update_version

    run --separate-stderr ./nodejs-system-manager update

    [[ "$status" -ne 0 ]]
    [[ "$stderr" =~ Hook[[:space:]]\'post_update_version\'[[:space:]]failed ]]
    _assert_json_code UPDATE_FAILED

    [[ -d "${NODEJS_ROOT}/24" ]]
    [[ -d "${NODEJS_ROOT}/24.19" ]]
    [[ -d "${NODEJS_ROOT}/24.19.0" ]]
    [[ ! -d "${NODEJS_ROOT}/24.18" ]]
    [[ ! -d "${NODEJS_ROOT}/24.18.0" ]]

    jq -e '.status == "error"' <<< "$output"
    jq -e '.changed == true' <<< "$output"
    jq -e '.data.versions_changed == true' <<< "$output"
    jq -e '.data.packages_changed == false' <<< "$output"
    jq -e '.data.results[0].code == "HOOK_FAILED"' <<< "$output"
}

@test "update minor from major - success with hooks" {

    _create_version 24.18.0
    _link_versions "24.18" "24.18.0"
    _link_versions "24" "24.18"
    _manage_version 24

    _mok_curl x64 24.19.0
    _mok_tar

    _mok_hook_success pre_update_version
    _mok_hook_success post_update_version

    {
        echo "foo@14.3.2"
        echo "bar@2"
    } > "${CONFIG_DIR}/packages/24"

    {
        echo "foo@13"
        echo "toto"
    } > "${CONFIG_DIR}/packages/default"

    _mok_npm 24

    run --separate-stderr ./nodejs-system-manager update

    [[ "$status" -eq 0 ]]
    [[ "$stderr" =~ Successfully[[:space:]]installed[[:space:]]Node.js[[:space:]]version:[[:space:]]24.19.0 ]]
    _assert_json_code UPDATE_SUCCESS

    [[ -d "${NODEJS_ROOT}/24" ]]
    [[ -d "${NODEJS_ROOT}/24.19" ]]
    [[ -d "${NODEJS_ROOT}/24.19.0" ]]
    [[ ! -d "${NODEJS_ROOT}/24.18" ]]
    [[ ! -d "${NODEJS_ROOT}/24.18.0" ]]

    jq -e '.status == "success"' <<< "$output"
    jq -e '.changed == true' <<< "$output"
    jq -e '.data.versions_changed == true' <<< "$output"
    jq -e '.data.packages_changed == true' <<< "$output"
    jq -e '.data.results[0].data.from == "24.18.0"' <<< "$output"
    jq -e '.data.results[0].data.to == "24.19.0"' <<< "$output"
    validate_packages foo bar toto

    [[ -f "${TEST_ROOT}/pre_update_version" ]]
    [[ -f "${TEST_ROOT}/post_update_version" ]]
}
