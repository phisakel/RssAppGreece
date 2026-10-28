#!/bin/bash
# Pass exported AdMob environment variables to Xcode, including nested asc builds.
set -euo pipefail

if [[ $# -eq 0 ]]; then
  echo "Usage: $0 command [arguments...]" >&2
  exit 1
fi

config_file="$(mktemp "${TMPDIR:-/tmp}/rss-admob.XXXXXX")"
trap 'rm -f "$config_file"' EXIT
chmod 600 "$config_file"

# Preserve any caller-supplied Xcode override configuration.
if [[ -n "${XCODE_XCCONFIG_FILE:-}" ]]; then
  cat "$XCODE_XCCONFIG_FILE" > "$config_file"
  printf '\n' >> "$config_file"
fi

for name in RSS_ADMOB_APP_ID RSS_ADMOB_BANNER_UNIT_ID RSS_ADMOB_INTERSTITIAL_UNIT_ID; do
  if value="$(printenv "$name")"; then
    if [[ "$name" == RSS_ADMOB_APP_ID ]]; then
      pattern='^ca-app-pub-[0-9]{16}~[0-9]{10}$'
    else
      pattern='^ca-app-pub-[0-9]{16}/[0-9]{10}$'
    fi
    if [[ ! "$value" =~ $pattern ]]; then
      echo "Invalid or empty $name; expected an AdMob identifier." >&2
      exit 1
    fi
    printf '%s = %s\n' "$name" "$value" >> "$config_file"
  fi
done

if [[ -s "$config_file" ]]; then
  export XCODE_XCCONFIG_FILE="$config_file"
fi
"$@"
