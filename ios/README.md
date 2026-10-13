# mone (iOS Edition) 🍏

> **Autonomous Offline Personal Finance OS for iOS**  
> Tailored for Apple ecosystem with **Apple Shortcuts Automation**, **Custom URL Scheme Deep Linking**, **Face ID Security**, and **Real-Time Indian Banking Intelligence**.

---

## 🚀 Running on Mac & Xcode

When you clone this Git repository on your Mac:

```bash
# 1. Navigate to the iOS folder
cd ios

# 2. Install Flutter packages
flutter pub get

# 3. Install CocoaPods dependencies for iOS
cd ios
pod install
cd ..

# 4. Open in Xcode
open ios/Runner.xcworkspace

# Or run directly on an iOS Simulator or connected iPhone:
flutter run -d ios
```

---

## ⚡ How SMS Tracking Works on iOS

Because iOS sandboxes third-party apps from directly reading the Messages inbox, `mone` uses **Apple Shortcuts Personal Automation** and **Custom URL Schemes**:

### 1. Native Deep Link Scheme
- Scheme: `mone://import-sms?text=<SMS_BODY>`
- Configured in: `ios/Runner/Info.plist` (`CFBundleURLTypes`)
- Processed by: `app_links` in Flutter

### 2. Apple Shortcuts 1-Minute Automation Setup
1. Open the **Shortcuts** app on your iPhone.
2. Tap the **Automation** tab at the bottom, then tap **+** (Create Personal Automation).
3. Select **Message** as the trigger.
4. Set **Message Contains**: `debited`, `credited`, `spent`, `UPI`, `ATM`.
5. Add action: **Open URLs** and set the URL to:
   ```text
   mone://import-sms?text=[Shortcut Input]
   ```
6. Turn off **"Ask Before Running"** so it executes silently in the background.
7. Tap **Done**.

Whenever your bank sends a transaction alert, iOS Shortcuts instantly triggers `mone`, parses the exact amount, merchant, and bank account, logs it into local SQLite, updates your available balance, and displays the **Dynamic Island** alert!

### 3. Smart Clipboard Auto-Detection
- When opening `mone`, if you've copied an SMS transaction from Messages or WhatsApp, `mone` instantly recognizes it and prompts with a 1-tap **"Import Transaction"** sheet.

### 4. Direct Manual SMS Paste
- Tap **"From SMS"** or use the **"Paste Bank SMS Text"** tile in Profile to paste any SMS text. The real-time parser shows recognized amounts, merchants, and categories on the fly.

---

## 🔒 Privacy & Security
- **100% Offline SQLite**: No financial data leaves the device.
- **Biometric Security**: Native **Face ID** / **Touch ID** protection via `local_auth` and `NSFaceIDUsageDescription`.
- **Zero Third-Party Trackers**: Self-contained parsing engine (`sms_parser.dart` and `indian_banks.dart`).

---

## 📁 Key Files
- `lib/main.dart`: Core app UI, deep link router, clipboard detection, Dynamic Island heads-up.
- `lib/services/sms_parser.dart`: High-precision Indian banking SMS parser engine.
- `lib/services/indian_banks.dart`: 25+ verified Indian bank styles, logos, BINs, and card widgets.
- `lib/screens/analytics_screen.dart`: Visual breakdown, spending trends, and financial diagnostics.
- `ios/Runner/Info.plist`: URL scheme `mone`, Face ID description, and iOS configurations.
