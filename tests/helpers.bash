_setup_test_env() {
    export TEST_ROOT="$BATS_TEST_TMPDIR"

    export NODEJS_ROOT="${TEST_ROOT}/opt/nodejs"
    export BIN_DIR="${TEST_ROOT}/usr/local/bin"
    export CONFIG_DIR="${TEST_ROOT}/etc/nodejs-system-manager"
    export LOCK_DIR="${TEST_ROOT}/lock/nodejs-system-manager"
    export CACHE_DIR="${TEST_ROOT}/cache/nodejs-system-manager"

    export JSON_OUTPUT="true"
    export JSON_OUTPUT_COMPACT="true"

    export LOG_LEVEL=0

    export PATH="${BIN_DIR}:${PATH}"
}

_setup_unit_env() {

    declare -gA PACKAGES_VERSION_POLICY=()
    declare -gA PACKAGES_SOURCE=()
}

TESTS_DIR=$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )
UTILS_DIR="${TESTS_DIR}/utils"

_assert_json_code() {
    jq -e --arg code "$1" '.code == $code' <<< "$output"
}

_create_version() {
    local version="$1"
    
    mkdir -p "${NODEJS_ROOT}/${version}/bin"

    touch "${NODEJS_ROOT}/${version}/bin/node"
    chmod +x "${NODEJS_ROOT}/${version}/bin/node"
    touch "${NODEJS_ROOT}/${version}/bin/npm"
    chmod +x "${NODEJS_ROOT}/${version}/bin/npm"
    touch "${NODEJS_ROOT}/${version}/bin/npx"
    chmod +x "${NODEJS_ROOT}/${version}/bin/npx"
}

_link_versions() {
    local src="$1"
    local dst="$2"

    ln -snf "${NODEJS_ROOT}/${dst}" "${NODEJS_ROOT}/${src}"
}

_link_npm() {
    local src="$1"
    local dst="$2"

    ln -snf "${BIN_DIR}/${dst}" "${BIN_DIR}/${src}"
}

_manage_version() {
    local version="$1"

    echo "$version" >> "$MANAGED_FILE"

    ln -snf "${NODEJS_ROOT}/${version}/bin/node" "${BIN_DIR}/node${version}"
    touch "${BIN_DIR}/npm${version}"
    touch "${BIN_DIR}/npx${version}"
    chmod +x "${BIN_DIR}/npm${version}"
    chmod +x "${BIN_DIR}/npx${version}"
}

_mok_npm() {
    local version="$1"

    local npm="${BIN_DIR}/npm${version}"

    cp "${UTILS_DIR}/npm" "$npm"
    sed -i "s|TPL_VER|$version|" "$npm"
    sed -i "s|TPL_DIR|$TEST_ROOT|" "$npm"
    chmod +x "$npm"
}


_mok_curl() {
    local arch="${1:-}"
    local version="${2:-}"
    local disabled="${3:-}"

    # cat > "/tmp/curl" << EOF
    cat > "${BIN_DIR}/curl" << EOF
#!/usr/bin/env bash
case "\$*" in
    *"/index.json"*)
        [[ "$disabled" = "index" ]] && exit 1
        cat ${UTILS_DIR}/index.json
        ;;
    *".tar.xz"*)
        [[ "$disabled" = "tarball" ]] && exit 1
        # cp ${UTILS_DIR}/node.tar.xz "node-v${version}-linux-${arch}.tar.xz"
        echo "FAKE_TARBALL_CONTENT" > "node-v${version}-linux-${arch}.tar.xz"
        ;;
    *"SHASUMS256"*)
        [[ "$disabled" = "shasums" ]] && exit 1
        [[ "$disabled" = "wrong_shasums" ]] && {
            sha256sum /dev/null > SHASUMS256.txt
            sed -i 's|/dev/null|node-v${version}-linux-${arch}.tar.xz|' SHASUMS256.txt
            exit 0
        }
        sha256sum node-v${version}-linux-${arch}.tar.xz > SHASUMS256.txt
        ;;
esac
EOF

    chmod +x "${BIN_DIR}/curl"
}

_mok_curl_index() {
    curl() {
        cat <<EOF
[
    {"version":"v24.1.1"},
    {"version":"v24.1.0"},
    {"version":"v24.0.0"}
]
EOF
    }
}

_mok_tar() {
    cp "${UTILS_DIR}/tar" "${BIN_DIR}/tar"
    chmod +x "${BIN_DIR}/tar"
}

_mok_hook_fail() {
    local hook="$1"

    cat > "${HOOK_DIR}/${hook}.sh" <<EOF
$hook() {
    return 1
}
EOF
}

_mok_hook_success() {
    local hook="$1"

    cat > "${HOOK_DIR}/${hook}.sh" <<EOF
$hook() {
    touch "${TEST_ROOT}/${hook}"
    return 0
}
EOF
}

_mok_hook_skip() {
    local hook="$1"

    cat > "${HOOK_DIR}/${hook}.sh" <<EOF
$hook() {
    HOOK_ACTION=skip
    return 0
}
EOF
}