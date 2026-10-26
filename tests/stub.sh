# Shared by the tests: a fake curl on $PATH. The scripts pass the URL as a
# curl config on stdin and append the HTTP status with -w, so the stub reads
# the URL from stdin and answers with a body and a status per endpoint.
# STUB_STATUS overrides the status for every request. Times are in
# America/Chicago: the demo station last reported 2026-10-20 22:40.
# shellcheck shell=bash

stub=$(mktemp -d)
trap 'rm -rf "$stub"' EXIT
# Two minutes after the demo station's last report.
export TEMPEST_NOW=1792554120

cat >"$stub/curl" <<'STUB'
#!/usr/bin/env bash
config=$(cat)
printf '%s\n' "$config" >>"$(dirname "$0")/requests"
printf '%s\n' "$*" >>"$(dirname "$0")/args"
respond() { printf '%s\n%s' "$1" "${STUB_STATUS:-$2}"; }
station='"station_id":%s,"station_name":"Back Yard","public_name":"Cedar Hollow","latitude":45.1,"longitude":-110.2,"timezone":"America/Chicago","status":{"status_code":0,"status_message":"SUCCESS"}'
case "$config" in
  */observations/station/99999\?*) respond '{"status":{"status_code":404,"status_message":"NOT FOUND"}}' 404 ;;
  */observations/station/88888\?*) respond '{"status":{"status_code":2,"status_message":"Unauthorized station"}}' 200 ;;
  */observations/station/77777\?*) respond "{$(printf "$station" 77777),\"obs\":[]}" 200 ;;
  */observations/station/66666\?*) respond "{$(printf "$station" 66666),\"elevation\":285,\"obs\":[]}" 200 ;;
  */stations/66666\?*) respond '{"status":{"status_code":0},"stations":[{"station_id":66666,"devices":[{"device_id":5,"device_type":"HB"},{"device_id":4,"device_type":"ST"}]}]}' 200 ;;
  */observations/device/4\?*) respond '{"status":{"status_code":0},"type":"obs_st","summary":{"feels_like":31.5,"pressure_trend":"falling","strike_count_1h":1,"strike_count_3h":3},
    "obs":[[1792550400,0,2,5,225,3,988.6,30.9,36,30,0.5,12,0.1,0,0,0,2.45,1,12.7,0,0,0]]}' 200 ;;
  */observations/station/55555\?*) respond "{$(printf "$station" 55555),\"obs\":[{\"timestamp\":1792550400,\"air_temperature\":18.0,\"feels_like\":18.0}]}" 200 ;;
  */observations/station/12345\?*) respond "{$(printf "$station" 12345),\"obs\":[{\"timestamp\":1792554000,
    \"air_temperature\":10.0,\"feels_like\":8.0,\"dew_point\":4.0,\"relative_humidity\":66,\"wind_avg\":2.0,\"wind_gust\":5.0,
    \"wind_direction\":225,\"sea_level_pressure\":1016.6,\"pressure_trend\":\"steady\",\"precip\":0.1,\"precip_accum_local_day\":12.7,
    \"uv\":0,\"solar_radiation\":0,\"lightning_strike_count_last_1hr\":0,\"lightning_strike_count_last_3hr\":2}]}" 200 ;;
  */better_forecast\?station_id=99999\&*) respond '{"status":{"status_code":404,"status_message":"NOT FOUND"}}' 404 ;;
  */better_forecast\?station_id=12345*) respond '{"timezone":"America/Chicago","status":{"status_code":0},
    "current_conditions":{"time":1792554000,"conditions":"Clear","icon":"clear-night","pressure_trend":"steady","precip_accum_local_day":0.5},
    "forecast":{"daily":[
      {"day_start_local":1792472400,"conditions":"Clear","icon":"clear-day","sunrise":1792499520,"sunset":1792538700,"air_temp_high":61,"air_temp_low":49,"precip_probability":0},
      {"day_start_local":1792558800,"conditions":"Rain Likely","icon":"rainy","sunrise":1792585980,"sunset":1792625040,"air_temp_high":76,"air_temp_low":50,"precip_probability":60,"precip_type":"rain"}],
    "hourly":[
      {"time":1792555200,"conditions":"Clear","icon":"clear-night","air_temperature":48,"feels_like":45,"precip_probability":0,"wind_avg":5,"wind_gust":9,"wind_direction":220},
      {"time":1792558800,"conditions":"Clear","icon":"clear-night","air_temperature":47,"feels_like":44,"precip_probability":5,"wind_avg":4,"wind_gust":8,"wind_direction":215}]}}' 200 ;;
  */stations/12345\?*) respond '{"status":{"status_code":0},"stations":[{"station_id":12345,"devices":[{"device_id":1,"device_type":"HB"},{"device_id":2,"device_type":"ST"}]}]}' 200 ;;
  */observations/device/2\?*) respond '{"status":{"status_code":0},"type":"obs_st","obs":[[1792554000,0,2,5,225,3,988.6,10,66,30,0,0,0,0,0,0,2.55,1]]}' 200 ;;
  */observations/device/3\?*) respond '{"status":{"status_code":0},"type":"obs_st","obs":[[1792554000,0,2,5,225,3,988.6,10,66,30,0,0,0,0,0,0,2.31,1]]}' 200 ;;
  */stations\?*) respond '{"status":{"status_code":0},"stations":[
    {"station_id":12345,"name":"Back Yard","public_name":"Cedar Hollow","latitude":45.1,"longitude":-110.2,"timezone":"America/Chicago","station_meta":{"share_with_wu":false},
     "devices":[{"device_id":1,"device_type":"HB"},{"device_id":2,"device_type":"ST"}]},
    {"station_id":23456,"name":"Cabin","latitude":46.0,"longitude":-111.0,"timezone":"America/Denver","station_meta":{"share_with_wu":true}}]}' 200 ;;
  *) respond '' 000 ;;
esac
STUB
chmod +x "$stub/curl"
export PATH="$stub:$PATH"

check() {
  local name=$1 filter=$2 out=$3
  if jq -e "$filter" <<<"$out" >/dev/null; then echo "ok - $name"; else echo "not ok - $name: $out"; exit 1; fi
}
