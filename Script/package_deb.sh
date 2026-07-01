#!/usr/bin/env bash
set -euo pipefail

# Usage:
#   Scripts/package_deb.sh <version> <arch> [tweak_name] [bundle_filter_comma_separated]
#
# Examples:
#   Scripts/package_deb.sh "1.0.0-1" "iphoneos-arm64"
#   Scripts/package_deb.sh "1.0.0-1" "iphoneos-arm64" "MyTweak" "com.apple.springboard,com.example.app"
#
VERSION="${1:-0.0.0-1}"
ARCH="${2:-iphoneos-arm64}"
TWEAK_NAME="${3:-}"                       # optional: name of the dylib without .dylib
FILTER_BUNDLES_CSV="${4:-com.apple.springboard}"

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
BUILD_DIR="$REPO_ROOT/build/Release-iphoneos"
OUT_DEB="$REPO_ROOT/${TWEAK_NAME:-fleXD}_${VERSION}_${ARCH}.deb"
TMPDIR="$(mktemp -d)"
PKG_DIR="$TMPDIR/package"

# Find dylib if name not provided
if [ -z "$TWEAK_NAME" ]; then
  mapfile -t dylibs < <(printf '%s\n' "$BUILD_DIR"/*.dylib 2>/dev/null || true)
  if [ ${#dylibs[@]} -eq 0 ]; then
    echo "No .dylib found in $BUILD_DIR. Provide the tweak name as the 3rd argument."
    exit 1
  elif [ ${#dylibs[@]} -gt 1 ]; then
    echo "Multiple .dylib files found in $BUILD_DIR. Please specify the tweak name as the 3rd argument."
    printf '%s\n' "${dylibs[@]}"
    exit 1
  else
    dylib_path="${dylibs[0]}"
    TWEAK_NAME="$(basename "$dylib_path" .dylib)"
  fi
else
  dylib_path="$BUILD_DIR/${TWEAK_NAME}.dylib"
  if [ ! -f "$dylib_path" ]; then
    echo "Expected dylib not found: $dylib_path"
    echo "Make sure you built the tweak target and that the filename matches."
    exit 1
  fi
fi

echo "Packaging tweak: $TWEAK_NAME"
echo "Found dylib: $dylib_path"

# Prepare package tree
mkdir -p "$PKG_DIR/DEBIAN"
mkdir -p "$PKG_DIR/Library/MobileSubstrate/DynamicLibraries"

# Copy dylib
cp -a "$dylib_path" "$PKG_DIR/Library/MobileSubstrate/DynamicLibraries/${TWEAK_NAME}.dylib"

# Create plist for MobileSubstrate
IFS=',' read -r -a FILTER_BUNDLES <<< "$FILTER_BUNDLES_CSV"
plist_path="$PKG_DIR/Library/MobileSubstrate/DynamicLibraries/${TWEAK_NAME}.plist"

cat > "$plist_path" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>Filter</key>
  <dict>
    <key>Bundles</key>
    <array>
EOF

for b in "${FILTER_BUNDLES[@]}"; do
  echo "      <string>${b}</string>" >> "$plist_path"
done

cat >> "$plist_path" <<EOF
    </array>
  </dict>
  <key>Executable</key>
  <string>${TWEAK_NAME}</string>
  <key>Library</key>
  <string>/Library/MobileSubstrate/DynamicLibraries/${TWEAK_NAME}.dylib</string>
  <key>Enabled</key>
  <true/>
</dict>
</plist>
EOF

# Create DEBIAN/control
PKG_NAME="com.rogueee.${TWEAK_NAME,,}"
cat > "$PKG_DIR/DEBIAN/control" <<EOF
Package: $PKG_NAME
Name: $TWEAK_NAME
Version: $VERSION
Architecture: $ARCH
Maintainer: R0GUEEE <you@example.com>
Depends: mobilesubstrate
Section: tweaks
Priority: optional
Description: $TWEAK_NAME - MobileSubstrate tweak packaged from repository.
EOF

# Optional postinst: set ownership/permissions and (optionally) respring
cat > "$PKG_DIR/DEBIAN/postinst" <<'EOF'
#!/bin/bash
set -e

TWEAK_DYLIB_PATH="/Library/MobileSubstrate/DynamicLibraries/'"${TWEAK_NAME}"'.dylib"
TWEAK_PLIST_PATH="/Library/MobileSubstrate/DynamicLibraries/'"${TWEAK_NAME}"'.plist"

# Correct ownership and permissions
if [ -f "$TWEAK_DYLIB_PATH" ]; then
  chown root:wheel "$TWEAK_DYLIB_PATH" || true
  chmod 0755 "$TWEAK_DYLIB_PATH" || true
fi

if [ -f "$TWEAK_PLIST_PATH" ]; then
  chown root:wheel "$TWEAK_PLIST_PATH" || true
  chmod 0644 "$TWEAK_PLIST_PATH" || true
fi

# Optional: trigger uicache for preference bundles/icons if needed
if command -v uicache &>/dev/null; then
  uicache -p /Library/MobileSubstrate/DynamicLibraries || true
fi

# Optional: automatic respring (commented out by default)
# killall -9 SpringBoard || true

exit 0
EOF

# Replace placeholder TWEAK_NAME in postinst (basic expansion)
sed -i.bak "s/'\"${TWEAK_NAME}\"'/${TWEAK_NAME}/g" "$PKG_DIR/DEBIAN/postinst" || true
rm -f "$PKG_DIR/DEBIAN/postinst.bak"

# Fix perms
chmod 0755 "$PKG_DIR/DEBIAN/postinst"
chmod 0644 "$PKG_DIR/DEBIAN/control"
chmod 0755 "$PKG_DIR/Library/MobileSubstrate/DynamicLibraries/${TWEAK_NAME}.dylib"
chmod 0644 "$plist_path"

# Build deb
if command -v fakeroot >/dev/null; then
  fakeroot dpkg-deb -Zgzip -b "$PKG_DIR" "$OUT_DEB"
else
  dpkg-deb -Zgzip -b "$PKG_DIR" "$OUT_DEB"
fi

echo "Created $OUT_DEB"
rm -rf "$TMPDIR"
