#!/usr/bin/env bash
# Checks scripts/tempest-save-key writes an owner-only key file and clears it.
set -euo pipefail

root=$(cd "$(dirname "$0")/.." && pwd)
config=$(mktemp -d)
trap 'rm -rf "$config"' EXIT
key_file="$config/omarchy/tempest.key"

check() {
  if [[ $2 == "$3" ]]; then echo "ok - $1"; else echo "not ok - $1: got '$2', want '$3'"; exit 1; fi
}

XDG_CONFIG_HOME=$config TEMPEST_NEW_TOKEN='  abc123 
' "$root/scripts/tempest-save-key"
check "saves the trimmed key" "$(cat "$key_file")" abc123
check "owner-only permissions" "$(stat -c %a "$key_file")" 600

XDG_CONFIG_HOME=$config TEMPEST_NEW_TOKEN='' "$root/scripts/tempest-save-key"
check "empty key removes the file" "$([[ -e $key_file ]] && echo present || echo absent)" absent
