#!/bin/bash
set -euo pipefail

task_root="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$task_root"
if [[ "$(uname -s)" != "Darwin" ]]; then
  echo "This build requires a macOS runner with Xcode; it cannot compile on Windows."
  exit 1
fi

task_output="$task_root/build-output"
task_derived="$task_root/build/DerivedData"
mkdir -p "$task_output"

xcodebuild -version > "$task_output/build-environment.txt"
xcrun --sdk iphoneos --show-sdk-version >> "$task_output/build-environment.txt"
plutil -lint ForestAccounts/Info.plist ForestAccounts.xcodeproj/project.pbxproj

# Only compile. No tests, Apple credentials, certificates, or provisioning profiles.
xcodebuild \
  -project ForestAccounts.xcodeproj \
  -scheme ForestAccounts \
  -configuration Release \
  -sdk iphoneos \
  -destination 'generic/platform=iOS' \
  -derivedDataPath "$task_derived" \
  CODE_SIGNING_ALLOWED=NO \
  CODE_SIGNING_REQUIRED=NO \
  CODE_SIGN_IDENTITY='' \
  DEVELOPMENT_TEAM='' \
  build 2>&1 | tee "$task_output/build.log"

python3 scripts/package-ipa.py "$task_derived/Build/Products/Release-iphoneos/ForestAccounts.app" "$task_output"
echo "Unsigned IPA prepared. Sign it locally on your own Windows computer before installation."
