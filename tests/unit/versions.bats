#!/usr/bin/env bats

load ../helpers

setup() {
    _setup_test_env
    _setup_unit_env
    source ./nodejs-system-manager
    init
}

@test "version_ge equal" {
    run version_ge 24.1.0 24.1.0

    [[ "$status" -eq 0 ]]
}

@test "version_ge greater" {
    run version_ge 24.1.1 24.1.0

    [[ "$status" -eq 0 ]]
}

@test "version_ge lower" {
    run version_ge 24.1.0 24.1.1

    [[ "$status" -eq 1 ]]
}

@test "resolve_version" {
    _mok_curl_index

    run resolve_version 24
    [[ "$output" = "24.1.1" ]]
    
    run resolve_version 24.1
    [[ "$output" = "24.1.1" ]]
    
    run resolve_version 24.0
    [[ "$output" = "24.0.0" ]]
}

@test "resolve_version cache" {
    _mok_curl_index

    export CACHE_INDEX_FILE_SKIPPED=true
    run resolve_version 24
    run resolve_version 24
    [[ ! -f "${CACHE_DIR}/nodejs-index.json" ]]
    [[ "$output" == "24.1.1" ]]

    unset CACHE_INDEX_FILE_SKIPPED
    run resolve_version 24
    run resolve_version 24
    [[ -f "${CACHE_DIR}/nodejs-index.json" ]]
    [[ "$output" == "24.1.1" ]]
}