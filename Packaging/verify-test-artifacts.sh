#!/bin/zsh
set -euo pipefail

project_dir="${0:A:h:h}"
plist="$project_dir/Packaging/Info.plist"
dist_dir="$project_dir/dist"
version="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "$plist")"
app="$dist_dir/MacScope.app"
zip="$dist_dir/MacScope-v${version}-test.zip"
dmg="$dist_dir/MacScope-v${version}-test.dmg"
verify_root="$(mktemp -d /private/tmp/MacScope-verify.XXXXXX)"
trap 'rm -rf "$verify_root"' EXIT
verify_app="$verify_root/MacScope.app"

for artifact in "$app" "$zip" "$dmg"; do
  if [[ ! -e "$artifact" ]]; then
    echo "Missing release artifact: $artifact" >&2
    exit 1
  fi
done

ditto --norsrc "$app" "$verify_app"
xattr -cr "$verify_app"
plutil -lint "$verify_app/Contents/Info.plist"
packaged_version="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "$verify_app/Contents/Info.plist")"
packaged_identifier="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleIdentifier' "$verify_app/Contents/Info.plist")"
if [[ "$packaged_version" != "$version" || "$packaged_identifier" != "com.macscope.app" ]]; then
  echo "Packaged bundle metadata does not match the release configuration." >&2
  exit 1
fi

codesign --verify --deep --strict --verbose=2 "$verify_app"
unzip -tq "$zip"
hdiutil verify "$dmg"

echo "Verified MacScope $version test artifacts."
shasum -a 256 "$dmg" "$zip"
