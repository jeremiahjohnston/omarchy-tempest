#!/usr/bin/env bash
# Runs scripts/tempest-current against a stubbed curl and checks its JSON output.
set -euo pipefail

root=$(cd "$(dirname "$0")/.." && pwd)
# shellcheck source=tests/stub.sh
source "$root/tests/stub.sh"
run() { TEMPEST_TOKEN=${KEY-test} "$root/scripts/tempest-current" "$@"; }

out=$(run 12345 e)
check "imperial reading" '.ok and .temp == 50 and .feels == 46.4 and .dewpt == 39.2 and .humidity == 66'  "$out"
check "imperial wind, pressure and rain" '.windSpeed == 4.5 and .windGust == 11.2 and .pressure == 30.02 and .precipTotal == 0.5 and .precipRate == 0.24' "$out"
check "station details" '.station == "12345" and .neighborhood == "Cedar Hollow" and .lat == 45.1 and .pressureTrend == "steady"' "$out"
check "observation time in the station time zone" '.obsTime == "2026-10-20 22:40:00"' "$out"
check "recent report is not stale" '.stale == false' "$out"

out=$(run 12345 m)
check "metric units" '.ok and .temp == 10 and .windSpeed == 7.2 and .windGust == 18 and .pressure == 1016.6 and .precipTotal == 12.7' "$out"

out=$(run 12345 h)
check "uk hybrid: celsius with mph" '.ok and .temp == 10 and .windSpeed == 4.5 and .pressure == 1016.6' "$out"

: >"$stub/requests"; run ' 12345 ' e >/dev/null
if grep -q 'observations/station/12345?token=' "$stub/requests"; then echo "ok - station id is trimmed"; else echo "not ok - station id is trimmed"; exit 1; fi
if grep -q 'token' "$stub/args"; then echo "not ok - token stays out of argv"; exit 1; else echo "ok - token stays out of argv"; fi

check "battery from the station's sensor" '.battery == 2.55 and .batteryLow == false' "$(run 12345 e)"
check "battery from a given sensor, low" '.battery == 2.31 and .batteryLow == true' "$(run 12345 e 3)"
check "no sensor found leaves battery out" '.ok and .battery == null and .batteryLow == null' "$(run 55555 e)"
check "missing station" '.code == "no-station" and .error == "No station selected"' "$(run '' e)"
check "non-numeric station" '.code == "no-station"' "$(run KXXDEMO1 e)"
check "missing key" '.code == "no-key"' "$(KEY='' HOME=$stub XDG_CONFIG_HOME=$stub run 12345 e)"
check "rejected key" '.code == "bad-key"' "$(STUB_STATUS=401 run 12345 e)"
check "unknown station" '.code == "no-station" and (.error | test("99999"))' "$(run 99999 e)"
check "error status inside a 200" '.code == "no-station" and (.error | test("Unauthorized station"))' "$(run 88888 e)"
check "station that never reported" '.code == "no-data" and (.error | test("77777"))' "$(run 77777 e)"
check "old report is stale but still shown" '.ok and .stale and .temp == 64.4 and .obsTime == "2026-10-20 21:40:00"' "$(run 55555 e)"
out=$(run 66666 m)
check "no recent station obs falls back to the sensor's last report" '.ok and .stale and .obsTime == "2026-10-20 21:40:00" and .temp == 30.9 and .feels == 31.5' "$out"
check "fallback derives dew point and sea-level pressure" '.dewpt >= 14 and .dewpt <= 14.2 and .pressure >= 1022 and .pressure <= 1024' "$out"
check "fallback keeps battery, rain and lightning" '.battery == 2.45 and .precipTotal == 12.7 and .precipRate == 6 and .lightningLast3Hours == 3 and .pressureTrend == "falling"' "$out"
out=$(run 44444 e)
check "no reading at all shows Tempest's estimate" '.ok and .stale and .estimated and .temp == 51.4 and .feels == 49 and .humidity == 66' "$out"
check "estimate keeps the station details" '.station == "44444" and .neighborhood == "Cedar Hollow" and .obsTime == null and .estimateTime == "2026-10-20 22:41:00"' "$out"
check "estimate units come from the forecast" '.windSpeed == 4 and .pressure == 30.02 and .pressureTrend == "rising"' "$out"
out=$(run 33333 e)
check "stale reading is replaced by the estimate" '.ok and .stale and .estimated and .temp == 51.4 and .obsTime == "2026-10-20 21:40:00"' "$out"
check "estimate keeps what the conditions leave out" '.precipTotal == 0.1' "$out"
check "recent reading is not estimated" '.estimated == null' "$(run 12345 e)"
check "zero volts is a failed reading, not a flat battery" '.battery == null and .batteryLow == null' "$(run 22222 e)"
check "network failure" '.code == "network"' "$(STUB_STATUS=000 run 12345 e)"
check "server error" '.code == "http" and (.error | test("503"))' "$(STUB_STATUS=503 run 12345 e)"
