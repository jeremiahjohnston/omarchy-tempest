#!/usr/bin/env bash
# Runs scripts/tempest-details against a stubbed curl and checks its JSON output.
set -euo pipefail

root=$(cd "$(dirname "$0")/.." && pwd)
# shellcheck source=tests/stub.sh
source "$root/tests/stub.sh"
run() { env TEMPEST_TOKEN=test "$root/scripts/tempest-details" "$@"; }

out=$(run 12345 e)
check "today from the first forecast day" '.ok and .today.high == 61 and .today.low == 49 and .today.precipTotal == 0.5' "$out"
check "sunrise and sunset in 12-hour station time" '.sunrise == "7:32 AM" and .sunset == "6:25 PM"' "$out"
check "hourly forecast" '.hourly | length == 2 and .[0].name == "11 PM" and .[0].temp == 48 and .[1].name == "12 AM"' "$out"
check "daily forecast" '.days[0].name == "Today" and (.days[1] | .name == "Wed" and .high == 76 and .precipChance == 60 and .precipType == "rain")' "$out"
check "current conditions" '.conditions == "Clear" and .icon == "clear-night"' "$out"
if grep -q 'units_temp=f&units_wind=mph&units_pressure=inhg' <(tail -1 "$stub/requests"); then echo "ok - imperial units requested"; else echo "not ok - imperial units requested"; exit 1; fi

run 12345 m >/dev/null
if grep -q 'units_temp=c&units_wind=kph&units_pressure=mb&units_precip=mm' <(tail -1 "$stub/requests"); then echo "ok - metric units requested"; else echo "not ok - metric units requested"; exit 1; fi

check "hour limit" '.hourly | length == 1' "$(run 12345 e 1)"
check "no forecast" '.code == "no-data" and (.error | test("99999"))' "$(run 99999 e)"
check "rejected key" '.code == "bad-key"' "$(STUB_STATUS=401 run 12345 e)"
