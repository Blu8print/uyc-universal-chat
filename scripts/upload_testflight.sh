#!/bin/bash

# Script to upload IPA to TestFlight
# Requires: App Store Connect API key configured
# Usage: ./upload_testflight.sh

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Change to project root
cd "$(dirname "$0")/.."

echo -e "${GREEN}🚀 Starting TestFlight upload process...${NC}"

# Check if IPA exists (try both possible locations)
IPA_PATH="build/ios/ipa/kwaaijongens APP.ipa"
if [ ! -f "$IPA_PATH" ]; then
    IPA_PATH="ios/build/export/Runner.ipa"
    if [ ! -f "$IPA_PATH" ]; then
        echo -e "${RED}❌ IPA file not found${NC}"
        echo -e "${YELLOW}💡 Run 'flutter build ipa --release' first${NC}"
        exit 1
    fi
fi

echo -e "${YELLOW}📱 Found IPA at: $IPA_PATH${NC}"

# Check if xcrun altool is available
if ! command -v xcrun &> /dev/null; then
    echo -e "${RED}❌ Xcode command line tools not found${NC}"
    echo -e "${YELLOW}💡 Install with: xcode-select --install${NC}"
    exit 1
fi

# Upload to TestFlight
echo -e "${YELLOW}📤 Uploading to TestFlight...${NC}"

# Check if Apple ID credentials are set as environment variables
if [ -z "$APPLE_ID_EMAIL" ] || [ -z "$APPLE_APP_PASSWORD" ]; then
    echo -e "${RED}❌ Missing Apple ID credentials${NC}"
    echo -e "${YELLOW}💡 Please set environment variables:${NC}"
    echo -e "   export APPLE_ID_EMAIL='your-apple-id@email.com'"
    echo -e "   export APPLE_APP_PASSWORD='your-app-specific-password'"
    echo -e "${YELLOW}💡 Or manually edit this script to include credentials${NC}"
    exit 1
fi

echo -e "${YELLOW}💡 Using Apple ID: $APPLE_ID_EMAIL${NC}"

# Using altool (will be deprecated, but works for now)
xcrun altool \
    --upload-app \
    -f "$IPA_PATH" \
    -t ios \
    --username "$APPLE_ID_EMAIL" \
    --password "$APPLE_APP_PASSWORD"

# Alternative using newer API (requires API key setup)
# xcrun altool \
#     --upload-app \
#     -f "$IPA_PATH" \
#     -t ios \
#     --apiKey "YOUR_API_KEY_ID" \
#     --apiIssuer "YOUR_ISSUER_ID"

echo -e "${GREEN}✅ Upload completed successfully!${NC}"
echo -e "${GREEN}📱 Check App Store Connect for processing status${NC}"
echo -e "${YELLOW}💡 Next steps:${NC}"
echo -e "   1. Wait for processing to complete (usually 10-30 minutes)"
echo -e "   2. Add release notes in App Store Connect"
echo -e "   3. Submit for TestFlight review"
echo -e "   4. Share with internal/external testers"