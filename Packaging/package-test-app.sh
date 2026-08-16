#!/bin/zsh
set -euo pipefail

project_dir="${0:A:h:h}"
build_dir="$project_dir/.build"
dist_dir="$project_dir/dist"
final_app_dir="$dist_dir/MacScope.app"
marketing_version="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "$project_dir/Packaging/Info.plist")"
build_version="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleVersion' "$project_dir/Packaging/Info.plist")"
if [[ ! "$marketing_version" =~ '^[0-9]+\.[0-9]+\.[0-9]+$' || ! "$build_version" =~ '^[0-9]+$' ]]; then
  echo "Invalid bundle version metadata." >&2
  exit 1
fi
artifact_name="MacScope-v${marketing_version}-test.zip"
final_zip="$dist_dir/$artifact_name"
dmg_name="MacScope-v${marketing_version}-test.dmg"
final_dmg="$dist_dir/$dmg_name"
stage_root="$(mktemp -d /private/tmp/MacScope-package.XXXXXX)"
trap 'rm -rf "$stage_root"' EXIT
app_dir="$stage_root/MacScope.app"
contents_dir="$app_dir/Contents"
asset_catalog="$build_dir/Assets.xcassets"
iconset_dir="$asset_catalog/AppIcon.appiconset"
icon_master="$build_dir/MacScopeIcon.png"

export DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer
export CLANG_MODULE_CACHE_PATH="$build_dir/clang-module-cache"
export SWIFTPM_MODULECACHE_OVERRIDE="$build_dir/swift-module-cache"

swift build -c release --disable-sandbox --jobs 2 --cache-path "$build_dir/cache"
binary_dir="$(swift build -c release --disable-sandbox --show-bin-path --cache-path "$build_dir/cache")"

mkdir -p "$contents_dir/MacOS" "$contents_dir/Resources" "$iconset_dir"
cp "$binary_dir/MacScope" "$contents_dir/MacOS/MacScope"
cp "$project_dir/Packaging/Info.plist" "$contents_dir/Info.plist"

swift "$project_dir/Packaging/render-icon.swift" "$icon_master"
cp "$project_dir/Packaging/AppIconContents.json" "$iconset_dir/Contents.json"

for size in 16 32 128 256 512; do
  sips -z "$size" "$size" "$icon_master" --out "$iconset_dir/icon_${size}x${size}.png" >/dev/null
  double_size=$((size * 2))
  sips -z "$double_size" "$double_size" "$icon_master" --out "$iconset_dir/icon_${size}x${size}@2x.png" >/dev/null
done
xcrun actool "$asset_catalog" \
  --compile "$contents_dir/Resources" \
  --platform macosx \
  --minimum-deployment-target 14.0 \
  --app-icon AppIcon \
  --output-partial-info-plist "$build_dir/AppIconInfo.plist" \
  >/dev/null

xattr -cr "$app_dir"
codesign --force --deep --sign - "$app_dir"
codesign --verify --deep --strict --verbose=2 "$app_dir"
plutil -lint "$contents_dir/Info.plist"

stage_zip="$stage_root/$artifact_name"
ditto -c -k --keepParent "$app_dir" "$stage_zip"
stage_dmg="$stage_root/$dmg_name"
hdiutil create \
  -volname "MacScope ${marketing_version} Test" \
  -srcfolder "$app_dir" \
  -ov \
  -format UDZO \
  "$stage_dmg" \
  >/dev/null

mkdir -p "$dist_dir"
rm -rf "$final_app_dir"
ditto "$app_dir" "$final_app_dir"
cp "$stage_zip" "$final_zip"
cp "$stage_dmg" "$final_dmg"

echo "$final_app_dir"
echo "$final_zip"
echo "$final_dmg"
