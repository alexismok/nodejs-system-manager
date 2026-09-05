#!/usr/bin/env bash
dir="$(dirname -- "${BASH_SOURCE[0]}")"
/usr/bin/bats --verbose-run "${dir}/integration"
/usr/bin/bats --verbose-run "${dir}/unit"