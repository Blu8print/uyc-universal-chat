# TestFlight Deployment Setup Guide

## Overview
Your Flutter app is now configured for TestFlight deployment. This guide will help you complete the setup and deploy your first build.

## Prerequisites

### 1. Apple Developer Account
- Ensure you have a valid Apple Developer Program membership
- Your account needs TestFlight access (included with membership)

### 2. App Store Connect Setup
1. Log in to [App Store Connect](https://appstoreconnect.apple.com/)
2. Create a new app with bundle ID: `com.app.kwaaijongens`
3. Fill in basic app information (name, category, etc.)

### 3. Certificates and Provisioning
Since your project uses automatic signing, Xcode will handle:
- Distribution certificate
- App Store provisioning profile

## Quick Start

### Step 1: Build for TestFlight
```bash
./scripts/build_testflight.sh
```

### Step 2: Upload to TestFlight
```bash
./scripts/upload_testflight.sh
```

## Configuration Files Created

### 1. `ios/Runner/Runner.entitlements`
- iOS entitlements for distribution signing
- Currently configured for production push notifications

### 2. `ios/ExportOptions.plist`
- Export configuration for App Store distribution
- Configured for automatic signing with your team ID

### 3. `scripts/increment_version.sh`
- Automatically increments build numbers
- Supports major/minor/patch version updates

### 4. `scripts/build_testflight.sh`
- Complete build process for TestFlight
- Includes cleaning, building, archiving, and exporting

### 5. `scripts/upload_testflight.sh`
- Upload IPA to TestFlight
- Supports both password and API key authentication

## API Key Setup (Recommended)

For automated uploads without manual authentication:

1. Go to [App Store Connect API](https://appstoreconnect.apple.com/access/api)
2. Create a new API key with "Developer" role
3. Download the `.p8` file
4. Update `testflight_config.json` with your API key details
5. Modify upload script to use API key instead of password

## Build Commands

### Version Management
```bash
# Increment build number only
./scripts/increment_version.sh

# Increment patch version (1.0.0 → 1.0.1)
./scripts/increment_version.sh patch

# Increment minor version (1.0.0 → 1.1.0)
./scripts/increment_version.sh minor

# Increment major version (1.0.0 → 2.0.0)
./scripts/increment_version.sh major
```

### Build Options
```bash
# Build with automatic version increment
./scripts/build_testflight.sh

# Build without incrementing version
./scripts/build_testflight.sh --skip-increment
```

## Troubleshooting

### Common Issues

1. **Code signing errors**
   - Ensure your Apple Developer account is active
   - Check team ID in project settings
   - Verify bundle ID matches App Store Connect

2. **Build failures**
   - Run `flutter clean` and `flutter pub get`
   - Check Xcode project for missing files
   - Verify iOS deployment target compatibility

3. **Upload failures**
   - Check Apple ID credentials
   - Verify app-specific password for 2FA accounts
   - Ensure IPA file exists in build directory

### Manual Upload Alternative

If automated upload fails, you can manually upload:

1. Open Xcode
2. Window → Organizer
3. Select your archive
4. Click "Distribute App"
5. Choose "App Store Connect"
6. Follow the upload wizard

## Next Steps

1. **Test the build process** with a development build
2. **Set up API key authentication** for automated uploads
3. **Configure TestFlight groups** for internal/external testing
4. **Set up CI/CD pipeline** for automated deployments
5. **Create release workflows** for different environments

## Support

For issues with:
- **Flutter build**: Check Flutter documentation
- **iOS signing**: Check Apple Developer documentation
- **TestFlight**: Check App Store Connect documentation
- **Scripts**: Check script comments and error messages

## Security Notes

- Never commit API keys or passwords to version control
- Use environment variables for sensitive data
- Regularly rotate API keys and passwords
- Review TestFlight access permissions regularly