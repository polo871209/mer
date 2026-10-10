build:
    xcodebuild -project Mer.xcodeproj -scheme Mer -destination 'generic/platform=iOS Simulator' -derivedDataPath build build CODE_SIGNING_ALLOWED=NO -quiet

format:
    swift format format --in-place --parallel --recursive Mer MerWidget

lint:
    swift format lint --strict --parallel --recursive Mer MerWidget

skills:
    npx -y skills update swiftui-pro swiftdata-pro -p -y
