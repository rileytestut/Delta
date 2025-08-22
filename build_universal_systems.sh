#!/bin/bash

# Build Universal Systems Framework
# This script builds the Systems framework for both iOS device and simulator,
# then combines them into a universal framework using lipo.

set -e  # Exit on any error

echo "🔨 Building Universal Systems Framework..."
echo "======================================="

# Configuration
SYSTEMS_DIR="Systems"
SCHEME_NAME="Systems"
CONFIGURATION="Debug"
DERIVED_DATA_PATH="DerivedData/SystemsBuild"

# Clean up previous builds
echo "🧹 Cleaning previous builds..."
rm -rf "${DERIVED_DATA_PATH}"

# Create build directory
mkdir -p "${DERIVED_DATA_PATH}"

cd "${SYSTEMS_DIR}"

echo ""
echo "📱 Building for iOS Device (arm64)..."
echo "-----------------------------------"
xcodebuild \
    -workspace Systems.xcworkspace \
    -scheme "${SCHEME_NAME}" \
    -configuration "${CONFIGURATION}" \
    -destination "generic/platform=iOS" \
    -derivedDataPath "../${DERIVED_DATA_PATH}" \
    build \
    BUILD_DIR="../${DERIVED_DATA_PATH}/Build" \
    CONFIGURATION_BUILD_DIR="../${DERIVED_DATA_PATH}/Build/${CONFIGURATION}-iphoneos"

echo ""
echo "🖥️  Building for iOS Simulator (arm64, x86_64)..."
echo "------------------------------------------------"
xcodebuild \
    -workspace Systems.xcworkspace \
    -scheme "${SCHEME_NAME}" \
    -configuration "${CONFIGURATION}" \
    -destination "platform=iOS Simulator,name=iPhone 15" \
    -derivedDataPath "../${DERIVED_DATA_PATH}" \
    build \
    BUILD_DIR="../${DERIVED_DATA_PATH}/Build" \
    CONFIGURATION_BUILD_DIR="../${DERIVED_DATA_PATH}/Build/${CONFIGURATION}-iphonesimulator"

cd ..

echo ""
echo "🔗 Creating Universal Framework..."
echo "--------------------------------"

# Paths to the built frameworks
DEVICE_FRAMEWORK="${DERIVED_DATA_PATH}/Build/${CONFIGURATION}-iphoneos/Systems.framework"
SIMULATOR_FRAMEWORK="${DERIVED_DATA_PATH}/Build/${CONFIGURATION}-iphonesimulator/Systems.framework"
UNIVERSAL_FRAMEWORK="${DERIVED_DATA_PATH}/Build/Universal/Systems.framework"

# Create universal framework directory
mkdir -p "${DERIVED_DATA_PATH}/Build/Universal"
cp -R "${DEVICE_FRAMEWORK}" "${UNIVERSAL_FRAMEWORK}"

# Combine the binary files using lipo
lipo -create \
    "${DEVICE_FRAMEWORK}/Systems" \
    "${SIMULATOR_FRAMEWORK}/Systems" \
    -output "${UNIVERSAL_FRAMEWORK}/Systems"

# Copy simulator swift modules (they include both architectures)
if [ -d "${SIMULATOR_FRAMEWORK}/Modules/Systems.swiftmodule" ]; then
    echo "📦 Merging Swift modules..."
    cp -R "${SIMULATOR_FRAMEWORK}/Modules/Systems.swiftmodule/"* "${UNIVERSAL_FRAMEWORK}/Modules/Systems.swiftmodule/"
fi

echo ""
echo "✅ Universal Framework Created!"
echo "📍 Location: ${UNIVERSAL_FRAMEWORK}"
echo ""

# Verify the architectures
echo "🔍 Verifying architectures in universal framework:"
lipo -info "${UNIVERSAL_FRAMEWORK}/Systems"

echo ""
echo "🎉 Build Complete! You can now use this framework for both device and simulator."
echo ""
echo "📋 Next Steps:"
echo "1. Copy ${UNIVERSAL_FRAMEWORK} to replace your existing Systems.framework"
echo "2. Or update your build process to use this universal version"
echo "3. Test building Delta for both simulator and device"
