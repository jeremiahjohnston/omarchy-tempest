# Shared by the tempest-* scripts: token loading, requests and errors.
# shellcheck shell=bash

key_file="${XDG_CONFIG_HOME:-$HOME/.config}/omarchy/tempest.key"
api="https://swd.weatherflow.com/swd/rest"

# Prints {ok: false, code, error} and exits. The widget keys its setup hints
# off `code`: no-key, bad-key, no-station, no-data, network, http, too-large.
fail() {
  jq -cn --arg c "$1" --arg e "$2" '{ok: false, code: $c, error: $e}'
  exit 0
}

# Reads the access token from $TEMPEST_TOKEN or the key file into $key.
load_key() {
  key="${TEMPEST_TOKEN:-$(tr -d "[:space:]" 2>/dev/null <"$key_file")}"
  [[ -n $key ]] || fail no-key "No access token set"
}

# Station IDs are numeric; anything else is treated as unset.
station_id() {
  local id
  id=$(tr -d '[:space:]' <<<"${1:-}")
  [[ $id =~ ^[0-9]+$ ]] && echo "$id"
}

# Units code (e, m or h, as in the WU plugin) to better_forecast's unit
# parameters: e is °F/mph/inHg/in, m is °C/km/h/mb/mm, h is °C/mph/mb/mm.
units_query() {
  case $1 in
    m) echo "units_temp=c&units_wind=kph&units_pressure=mb&units_precip=mm&units_distance=km" ;;
    h) echo "units_temp=c&units_wind=mph&units_pressure=mb&units_precip=mm&units_distance=mi" ;;
    *) echo "units_temp=f&units_wind=mph&units_pressure=inhg&units_precip=in&units_distance=mi" ;;
  esac
}

# The largest response read from the API, in bytes. A forecast is about
# 50 KB and an account's station list a few KB, so anything near this is not
# a response the widget can use.
max_bytes=1048576

# GETs $api/$1 with the token appended and prints the body. The URL goes to
# curl as a config file on stdin so the token never appears in the process
# list. Sets $status to the HTTP status (000 when the request did not
# complete) and $body to the response, both for the calling script.
# The body is capped at $max_bytes twice over: curl's --max-filesize stops a
# download that runs past it, and head -c stops reading there whatever curl
# does, so an oversized response is never held in memory. Either way it
# fails with code too-large.
# shellcheck disable=SC2034
request() {
  local out rc sep='?'
  [[ $1 == *\?* ]] && sep='&'
  # curl's exit code rides on the last line; 63 is --max-filesize tripping.
  out=$(
    curl -s --max-time 15 --max-filesize "$max_bytes" -w '\n%{http_code}' -K - <<<"url = \"$api/$1${sep}token=$key\"" |
      head -c "$((max_bytes + 5))"
    printf '\n%s' "${PIPESTATUS[0]}"
  )
  rc=${out##*$'\n'}
  out=${out%$'\n'*}
  # Bytes, not characters: the body may hold multibyte text.
  if [[ $rc == 63 ]] || (( $(LC_ALL=C; echo "${#out}") > max_bytes + 4 )); then
    fail too-large "Tempest sent a response over $((max_bytes / 1024)) KB"
  fi
  status=${out##*$'\n'}
  body=${out%$'\n'*}
}

# Fails with a readable message for a non-200 response.
check_status() {
  case $status in
    200) ;;
    401 | 403) fail bad-key "Access token was rejected" ;;
    404) fail "${1:-no-data}" "${2:-No data available}" ;;
    000) fail network "Could not reach swd.weatherflow.com" ;;
    *) fail http "Tempest returned HTTP $status" ;;
  esac
}
