#!/usr/bin/env bats

load ../helpers

setup() {
    bats_require_minimum_version 1.5.0
}

create_config_dir() {
    mkdir -p "$BATS_TEST_TMPDIR/CONFIG_DIR"
}

write_config_value() {
    echo "$1=$2" >> "$BATS_TEST_TMPDIR/CONFIG_DIR/config"
}

assert_var_value() {
    local var="$1"
    local expected="$2"

    local line name value
    while IFS= read -r line; do
        name="${line%%=*}"
        value="${line#*=}"

        if [[ "$name" == "$var" ]]; then
            if [[ "$value" != "$expected" ]]; then
                echo "$output"
                return 1
            fi
            return 0
        fi
    done <<< "$output"

    return 1
}

@test "Override CONFIG_DIR from env var" {
    create_config_dir

    write_config_value CACHE_DIR /override/nodejs-system-manager

    CONFIG_DIR="$BATS_TEST_TMPDIR/CONFIG_DIR" run --separate-stderr ./nodejs-system-manager dump_config
    
    assert_var_value CACHE_DIR /override/nodejs-system-manager
}

@test "Override CONFIG_DIR from options" {
    create_config_dir

    write_config_value CACHE_DIR /override/nodejs-system-manager

    run --separate-stderr ./nodejs-system-manager dump_config --config-dir "$BATS_TEST_TMPDIR/CONFIG_DIR"

    assert_var_value CACHE_DIR /override/nodejs-system-manager
}

@test "Verify cli option priority" {
    create_config_dir

    write_config_value CACHE_DIR /override/config_file

    export CONFIG_DIR="$BATS_TEST_TMPDIR/CONFIG_DIR"

    CACHE_DIR="/override/env_var" run --separate-stderr ./nodejs-system-manager dump_config --cache-dir "/override/cli_opt"

    assert_var_value CACHE_DIR /override/cli_opt
}

@test "Verify env var priority" {
    create_config_dir

    write_config_value CACHE_DIR /override/config_file
    
    export CONFIG_DIR="$BATS_TEST_TMPDIR/CONFIG_DIR"

    CACHE_DIR="/override/env_var" run --separate-stderr ./nodejs-system-manager dump_config

    assert_var_value CACHE_DIR /override/env_var
}

@test "Verify config file priority" {
    create_config_dir

    write_config_value CACHE_DIR /override/config_file

    export CONFIG_DIR="$BATS_TEST_TMPDIR/CONFIG_DIR"

    run --separate-stderr ./nodejs-system-manager dump_config

    assert_var_value CACHE_DIR /override/config_file
}