#!/bin/bash

# Script to build and deploy Flutter app to TestFlight
# Usage: ./build_testflight.sh [--skip-increment]

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Change to project root
cd "$(dirname "$0")/.."

echo -e "${GREEN}🚀 Starting TestFlight build process...${NC}"

# Increment build number unless --skip-increment is passed
if [ "$1" != "--skip-increment" ]; then
    echo -e "${YELLOW}📈 Incrementing build number...${NC}"
    ./scripts/increment_version.sh
fi

# Clean previous builds
echo -e "${YELLOW}🧹 Cleaning previous builds...${NC}"
flutter clean
flutter pub get

# Build iOS app
echo -e "${YELLOW}🔨 Building iOS app for release...${NC}"
flutter build ios --release --no-codesign

# Archive the app
echo -e "${YELLOW}📦 Archiving the app...${NC}"
cd ios
xcodebuild \
    -workspace Runner.xcworkspace \
    -scheme Runner \
    -configuration Release \
    -destination 'generic/platform=iOS' \
    -archivePath build/Runner.xcarchive \
    -allowProvisioningUpdates \
    archive

# Export IPA
echo -e "${YELLOW}📤 Exporting IPA for App Store...${NC}"
xcodebuild \
    -exportArchive \
    -archivePath build/Runner.xcarchive \
    -exportPath build/export \
    -exportOptionsPlist ExportOptions.plist \
    -allowProvisioningUpdates

echo -e "${GREEN}✅ Build completed successfully!${NC}"
echo -e "${GREEN}📱 IPA file located at: ios/build/export/Runner.ipa${NC}"
echo -e "${YELLOW}💡 Next steps:${NC}"
echo -e "   1. Test the IPA file on a device"
echo -e "   2. Upload to TestFlight using: ./scripts/upload_testflight.sh"
echo -e "   3. Or upload manually via App Store Connect"