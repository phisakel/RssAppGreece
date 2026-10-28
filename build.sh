#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")"

action="${1:-build}"
case "$action" in
  build) destination="${2:-generic/platform=iOS Simulator}" ;;
  test) destination="${2:-platform=iOS Simulator,name=iPhone 18 Pro Max}" ;;
  archive) destination="${2:-generic/platform=iOS}" ;;
  *) echo "Usage: $0 [build|test|archive] [destination]" >&2; exit 1 ;;
esac

args=(-project RssReader.xcodeproj -scheme RssReader -destination "$destination")
if [[ "$action" == archive ]]; then
  args+=(-configuration Release -archivePath build/RssReader.xcarchive)
fi
./scripts/with-admob-env.sh xcodebuild "${args[@]}" "$action"
