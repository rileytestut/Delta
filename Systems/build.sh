#!/bin/bash

# Fail if error occurs
set -e

SCHEME="Systems"
PLATFORM="iOS Simulator"

BUILD_DIR=".build"

case $PLATFORM in
"iOS")
CONFIG_FOLDER="${CONFIGURATION}-iphoneos"
;;
"iOS Simulator")
CONFIG_FOLDER="${CONFIGURATION}-iphonesimulator"
;;
esac

OUTPUT_DIR="$BUILD_DIR/Build/Products/$CONFIG_FOLDER"

xcodebuild -workspace Systems.xcworkspace -scheme $SCHEME -configuration ${CONFIGURATION} -destination "generic/platform=$PLATFORM" -derivedDataPath $BUILD_DIR BITCODE_GENERATION_MODE=bitcode
        
cp -Rf "$OUTPUT_DIR/Systems.framework" "${BUILT_PRODUCTS_DIR}/"
