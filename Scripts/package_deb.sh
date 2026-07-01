#!/bin/bash
set -e

VERSION="${1:-0.0.0-1}"
ARCH="${2:-iphoneos-arm64}"

echo "Building Debian package for $ARCH with version $VERSION"

# Create temporary directory for packaging
TEMP_DIR=$(mktemp -d)
trap "rm -rf $TEMP_DIR" EXIT

# Create directory structure for Debian package
mkdir -p "$TEMP_DIR/DEBIAN"
mkdir -p "$TEMP_DIR/usr/lib"

# Copy built binaries (adjust paths based on your build output)
if [ -d "build/Release-iphoneos" ]; then
  cp -r build/Release-iphoneos/* "$TEMP_DIR/usr/lib/" || true
fi

# Create control file
cat > "$TEMP_DIR/DEBIAN/control" << EOF
Package: flexd
Version: $VERSION
Architecture: $ARCH
Maintainer: R0GUEEE <maintainer@example.com>
Description: FLEX - A set of in-app debugging and exploration tools for iOS
EOF

# Build the .deb package
OUTPUT_FILE="fleXD_${VERSION}_${ARCH}.deb"
dpkg-deb --build "$TEMP_DIR" "$OUTPUT_FILE"

echo "Package created: $OUTPUT_FILE"
