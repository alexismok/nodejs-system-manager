#!/usr/bin/env bats

load ../helpers

setup() {
    bats_require_minimum_version 1.5.0
    _setup_test_env
    _setup_unit_env
    source ./nodejs-system-manager
    init
}

@test "read_package_file parses versions" {

    cat > "${CONFIG_DIR}/packages/default" <<EOF
pnpm@10
typescript@^5
eslint
@angular/cli@17
EOF

    read_package_file \
        "${CONFIG_DIR}/packages/default" \
        default

    echo "${PACKAGES_VERSION_POLICY[*]}"

    [[ "${PACKAGES_VERSION_POLICY[pnpm]}" = "10" ]]
    [[ "${PACKAGES_VERSION_POLICY[typescript]}" = "^5" ]]
    [[ "${PACKAGES_VERSION_POLICY[eslint]}" = "" ]]
    [[ "${PACKAGES_VERSION_POLICY[@angular/cli]}" = "17" ]]
}


@test "channel overrides default" {

    cat > "${CONFIG_DIR}/packages/default" <<EOF
typescript@5
pnpm
EOF

    cat > "${CONFIG_DIR}/packages/24" <<EOF
typescript@5.9
EOF

    cat > "${BIN_DIR}/npm24" <<EOF
#!/usr/bin/env bash
cat <<EOF2
{
  "dependencies": {
    "typescript": {
      "version": "9.0.0"
    },
    "pnpm": {
      "version": "1.0.0"
    },
    "pm2": {
      "version": "1.0.0"
    }
  }
}
EOF2
EOF
    chmod +x "${BIN_DIR}/npm24"

    load_packages 24

    [[ "${PACKAGES_VERSION_POLICY[typescript]}" = "5.9" ]]
    [[ "${PACKAGES_VERSION_POLICY[pnpm]}" = "" ]]
    [[ "${PACKAGES_VERSION_POLICY[pm2]}" = "1.0.0" ]]
}

@test "package name + version regex" {
    is_valid_name() {
        [[ "$1" =~ $NPM_PKG_FULL_REGEX ]] && [[ "${#BASH_REMATCH[1]}" -lt $NPM_PKG_MAX_LENGTH ]]
    }
    is_invalid_name() {
        ! [[ "$1" =~ $NPM_PKG_FULL_REGEX ]] || [[ "${#BASH_REMATCH[1]}" -gt $NPM_PKG_MAX_LENGTH ]]
    }

    # Success - name only
    is_valid_name 'npm-validate'
    is_valid_name 'example.com'
    is_valid_name 'under_score'
    is_valid_name 'period.js'
    is_valid_name '123numeric'
    is_valid_name '@npm/thingy'

    # Success - name + version
    is_valid_name 'npm-validate@latest'
    is_valid_name 'example.com@1.0.0'
    is_valid_name 'under_score@^5'
    is_valid_name 'period.js@>=10,<20'
    is_valid_name '123numeric@<20'
    is_valid_name '@npm/thingy@5.x'

    # Fail
    is_invalid_name 'example.com@'
    is_invalid_name 'crazy!'
    is_invalid_name '@npm-zors/money!time.js'
    is_invalid_name '.start-with-period'
    is_invalid_name '@npm/'
    is_invalid_name '@npm/.'
    is_invalid_name '@npm/..'
    is_invalid_name '@npm/.package'
    is_invalid_name '@npm/..package'
    is_invalid_name '_start-with-underscore'
    is_invalid_name 'contain:colons'
    is_invalid_name ' leading-space'
    is_invalid_name '  multiple leading space'
    is_invalid_name 'trailing-space '
    is_invalid_name 'multiple-trailing-space  '
    is_invalid_name 's/l/a/s/h/e/s'
    is_invalid_name '123numericamzeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeee'

}