#!/usr/bin/env bash
# Runs scripts/tempest-stations against a stubbed curl and checks its JSON output.
set -euo pipefail

root=$(cd "$(dirname "$0")/.." && pwd)
# shellcheck source=tests/stub.sh
source "$root/tests/stub.sh"
run() { TEMPEST_TOKEN=${KEY-test} "$root/scripts/tempest-stations"; }

out=$(run)
check "lists stations" '.ok and (.stations | length) == 2' "$out"
check "public name preferred" '.stations[0] | .id == "12345" and .name == "Cedar Hollow" and .stationName == "Back Yard"' "$out"
check "falls back to the station name" '.stations[1].name == "Cabin"' "$out"
check "sensor device id" '.stations[0].sensorDeviceId == "2" and .stations[1].sensorDeviceId == null' "$out"
check "WU sharing flag" '.stations[0].sharesWithWu == false and .stations[1].sharesWithWu == true' "$out"
check "missing key" '.code == "no-key"' "$(KEY='' HOME=$stub XDG_CONFIG_HOME=$stub run)"
check "rejected key" '.code == "bad-key"' "$(STUB_STATUS=401 run)"
