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

version := `sed -n 's/.*MARKETING_VERSION = \(.*\);/\1/p' Mer.xcodeproj/project.pbxproj | head -1`
build_number := `sed -n 's/.*CURRENT_PROJECT_VERSION = \(.*\);/\1/p' Mer.xcodeproj/project.pbxproj | head -1`

# Sets the version and build number of both targets, for example `just set-version 1.0 3`.
set-version marketing build:
    sed -i '' -E -e 's/MARKETING_VERSION = [^;]+;/MARKETING_VERSION = {{marketing}};/' -e 's/CURRENT_PROJECT_VERSION = [^;]+;/CURRENT_PROJECT_VERSION = {{build}};/' Mer.xcodeproj/project.pbxproj

# Archives a Release build into the Xcode Organizer and checks that the app and the widget carry the project version.
archive:
    #!/usr/bin/env bash
    set -euo pipefail
    expected="{{version}} ({{build_number}})"
    archive="$HOME/Library/Developer/Xcode/Archives/$(date +%Y-%m-%d)/Mer $expected.xcarchive"
    xcodebuild archive -project Mer.xcodeproj -scheme Mer -configuration Release -destination 'generic/platform=iOS' -archivePath "$archive" -allowProvisioningUpdates -quiet
    app="$archive/Products/Applications/Mer.app"
    for plist in "$app/Info.plist" "$app/PlugIns/MerWidget.appex/Info.plist"; do
        actual="$(plutil -extract CFBundleShortVersionString raw "$plist") ($(plutil -extract CFBundleVersion raw "$plist"))"
        if [[ "$actual" != "$expected" ]]; then echo "$plist has $actual, expected $expected" >&2; exit 1; fi
    done
    echo "$archive"

# Uploads the archive of the project version to App Store Connect. `just upload export` signs it without an upload.
upload destination="upload":
    #!/usr/bin/env bash
    set -euo pipefail
    archive=$(ls -d "$HOME"/Library/Developer/Xcode/Archives/*/"Mer {{version}} ({{build_number}}).xcarchive" | tail -1)
    options=$(mktemp -d)/ExportOptions.plist
    plutil -create xml1 "$options"
    plutil -insert method -string app-store-connect "$options"
    plutil -insert destination -string "{{destination}}" "$options"
    xcodebuild -exportArchive -archivePath "$archive" -exportOptionsPlist "$options" -exportPath "$(dirname "$options")" -allowProvisioningUpdates -quiet
    echo "Exported $archive to {{destination}}: $(dirname "$options")"

# Tags HEAD with the project version and lists the commits since the previous tag.
tag:
    #!/usr/bin/env bash
    set -euo pipefail
    previous=$(git describe --tags --abbrev=0 HEAD^ 2>/dev/null || git rev-list --max-parents=0 HEAD)
    git tag -a "{{version}}" -m "Mer {{version}} ({{build_number}})" -m "Changes since $previous:" -m "$(git log --format='- %s' "$previous"..HEAD)"
    git cat-file -p "{{version}}"

# Uploads every model field to the CloudKit development environment from the connected iPhone.
cloudkit-schema:
    #!/usr/bin/env bash
    set -euo pipefail
    devices=$(mktemp)
    xcrun devicectl list devices --json-output "$devices" >/dev/null
    device=$(jq -r '[.result.devices[] | select(.hardwareProperties.reality == "physical" and .connectionProperties.tunnelState == "connected")][0].hardwareProperties.udid // empty' "$devices")
    if [[ -z "$device" ]]; then echo "Connect and unlock an iPhone first." >&2; exit 1; fi
    xcodebuild build -project Mer.xcodeproj -scheme Mer -configuration Debug -destination "id=$device" -derivedDataPath build/device -allowProvisioningUpdates -quiet
    xcrun devicectl device install app --device "$device" build/device/Build/Products/Debug-iphoneos/Mer.app >/dev/null
    output=$(xcrun devicectl device process launch --device "$device" --terminate-existing --console com.polo.Mer -- -initializeCloudKitSchema 2>&1)
    if ! grep -q "Initialized the CloudKit development schema" <<<"$output"; then echo "$output" >&2; exit 1; fi
    echo "Initialized the CloudKit development schema"

# Shows the fields that Deploy Schema Changes adds to production. Needs `xcrun cktool save-token --type management` once.
cloudkit-diff:
    #!/usr/bin/env bash
    set -euo pipefail
    team=$(sed -n 's/.*DEVELOPMENT_TEAM = \(.*\);/\1/p' Mer.xcodeproj/project.pbxproj | head -1)
    dir=$(mktemp -d)
    for environment in production development; do
        xcrun cktool export-schema --team-id "$team" --container-id iCloud.com.polo.Mer --environment "$environment" --output-file "$dir/$environment.ckdb"
    done
    if diff -u "$dir/production.ckdb" "$dir/development.ckdb"; then echo "Production matches development."; fi
