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

# Check if IPA exists
IPA_PATH="ios/build/export/Runner.ipa"
if [ ! -f "$IPA_PATH" ]; then
    echo -e "${RED}❌ IPA file not found at $IPA_PATH${NC}"
    echo -e "${YELLOW}💡 Run ./scripts/build_testflight.sh first${NC}"
    exit 1
fi

# Check if xcrun altool is available
if ! command -v xcrun &> /dev/null; then
    echo -e "${RED}❌ Xcode command line tools not found${NC}"
    echo -e "${YELLOW}💡 Install with: xcode-select --install${NC}"
    exit 1
fi

# Upload to TestFlight
echo -e "${YELLOW}📤 Uploading to TestFlight...${NC}"
echo -e "${YELLOW}💡 You will need to enter your Apple ID credentials${NC}"

# Using altool (will be deprecated, but works for now)
xcrun altool \
    --upload-app \
    -f "$IPA_PATH" \
    -t ios \
    --username "YOUR_APPLE_ID_EMAIL" \
    --password "YOUR_APP_SPECIFIC_PASSWORD"

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