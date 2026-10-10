build:
    xcodebuild -project Mer.xcodeproj -scheme Mer -destination 'generic/platform=iOS Simulator' -derivedDataPath build build CODE_SIGNING_ALLOWED=NO -quiet

format:
    swift format format --in-place --parallel --recursive Mer MerWidget

lint:
    swift format lint --strict --parallel --recursive Mer MerWidget

clean-sim:
    #!/usr/bin/env bash
    set -euo pipefail
    group=$(xcrun simctl get_app_container booted com.polo.Mer groups | awk -F'\t' '$1 == "group.com.polo.Mer" { print $2 }')
    if [ -z "$group" ]; then echo "Mer has no app group container on the booted simulator." >&2; exit 1; fi
    xcrun simctl terminate booted com.polo.Mer 2>/dev/null || true
    rm -rf "$group/Library/Application Support/"default.store* "$group/Library/Application Support/.default_SUPPORT"
    echo "Deleted the Mer store in $group"

skills:
    npx -y skills update swiftui-pro swiftdata-pro -p -y
