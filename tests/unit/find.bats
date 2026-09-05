#!/usr/bin/env bats

load ../helpers

setup() {
    bats_require_minimum_version 1.5.0
    _setup_test_env
    _setup_unit_env
    source ./nodejs-system-manager
    init
}

@test "find_parents" {
    mkdir "${NODEJS_ROOT}/24.1.0"
    ln -snf "${NODEJS_ROOT}/24.1.0" "${NODEJS_ROOT}/24.1"
    ln -snf "${NODEJS_ROOT}/24.1" "${NODEJS_ROOT}/24"

    run find_parents 24.1.0
    local re='24\.1[[:space:]]24'
    [[ "$output" =~ $re ]]
}

@test "find_childs" {
    mkdir "${NODEJS_ROOT}/24.1.0"
    ln -snf "${NODEJS_ROOT}/24.1.0" "${NODEJS_ROOT}/24.1"
    ln -snf "${NODEJS_ROOT}/24.1" "${NODEJS_ROOT}/24"

    run find_childs 24
    local re='24\.1[[:space:]]24\.1\.0'
    [[ "$output" =~ $re ]]
}