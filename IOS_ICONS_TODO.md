# iOS App Icons - Migration Notes

## Current Status

✅ **App Store Icon (1024x1024):** Updated with UYC branding
⚠️ **Other iOS Icon Sizes:** Still using old Kwaaijongens icons

## Completed
- `Icon-App-1024x1024@1x.png` - Replaced with 1024.png from ic_launcher.zip
- Backup created: `Icon-App-1024x1024@1x_OLD.png`

## Remaining iOS Icon Sizes

The following icon files in `ios/Runner/Assets.xcassets/AppIcon.appiconset/` still need to be updated with UYC branding:

### iPhone Icons
- `Icon-App-20x20@2x.png` (40x40 pixels)
- `Icon-App-20x20@3x.png` (60x60 pixels)
- `Icon-App-29x29@2x.png` (58x58 pixels)
- `Icon-App-29x29@3x.png` (87x87 pixels)
- `Icon-App-40x40@2x.png` (80x80 pixels)
- `Icon-App-40x40@3x.png` (120x120 pixels)
- `Icon-App-60x60@2x.png` (120x120 pixels)
- `Icon-App-60x60@3x.png` (180x180 pixels)

### iPad Icons
- `Icon-App-20x20@1x.png` (20x20 pixels)
- `Icon-App-29x29@1x.png` (29x29 pixels)
- `Icon-App-40x40@1x.png` (40x40 pixels)
- `Icon-App-76x76@1x.png` (76x76 pixels)
- `Icon-App-76x76@2x.png` (152x152 pixels)
- `Icon-App-83.5x83.5@2x.png` (167x167 pixels)

## Recommended Approach

### Option 1: Use Icon Generator Tool (Recommended)
Use a Flutter icon generator package or online tool:

```bash
# Install flutter_launcher_icons package
flutter pub add --dev flutter_launcher_icons

# Add to pubspec.yaml:
# flutter_icons:
#   android: false
#   ios: true
#   image_path: "1024.png"

# Generate icons
flutter pub run flutter_launcher_icons
```

### Option 2: Manual Design Tool
Use Figma, Sketch, or Adobe Illustrator to:
1. Open the 1024.png source file
2. Export at all required sizes listed above
3. Replace files in `ios/Runner/Assets.xcassets/AppIcon.appiconset/`

### Option 3: Online Icon Generator
Upload 1024.png to services like:
- [App Icon Generator](https://appicon.co/)
- [MakeAppIcon](https://makeappicon.com/)
- [Icon Kitchen](https://icon.kitchen/)

These tools automatically generate all iOS icon sizes from a single high-resolution source.

## Testing iOS Icons

After updating icons:

```bash
# Clean and rebuild
flutter clean
flutter pub get

# Run on iOS simulator (macOS only)
flutter run -d ios

# Or build for iOS
flutter build ios
```

Check that:
- App icon displays correctly on home screen (all sizes)
- App Store icon (1024x1024) shows in TestFlight/App Store Connect
- No missing icon warnings in Xcode

## Important Notes

- iOS requires all icon sizes to be provided (no automatic scaling)
- Icons must have **no transparency** (use solid backgrounds)
- Icons must be **square** (no rounded corners - iOS handles that)
- File format: PNG, RGB color space
- The 1024x1024 icon is used for App Store display only

---

**Source Files Available:**
- `1024.png` - High resolution source (2.7MB)
- `play_store_512.png` - Android Play Store graphic (653KB)
- `UYC-logo.png` - App logo (2.2MB)

**Last Updated:** February 16, 2026
