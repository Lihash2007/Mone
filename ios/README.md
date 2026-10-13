# mone (iOS Edition) 🍏

> **Autonomous Offline Personal Finance OS for iOS**  
> Tailored for Apple ecosystem with **Apple Shortcuts Automation**, **Custom URL Scheme Deep Linking**, **Face ID Security**, and **Real-Time Indian Banking Intelligence**.

---

## ☁️ Zero-Mac Cloud Build (GitHub Actions)

You don't need a Mac or a VirtualBox VM to build this iOS app! GitHub Actions builds it automatically in the cloud on Apple Silicon runners (`macos-14`):

### How to trigger a build & download the app:
1. Go to your GitHub repository: [https://github.com/Lihash2007/Mone](https://github.com/Lihash2007/Mone)
2. Click the **Actions** tab.
3. In the left sidebar, click **"Build iOS (mone)"**.
4. Click **"Run workflow"** -> Select branch `main` -> Click **"Run workflow"**.
5. Once the build completes (~3 minutes), click on the completed run.
6. Scroll down to **Artifacts** to download:
   - **`mone-ios-release-unsigned-ipa`**: Ready to install on physical iPhones via [Sideloadly](https://sideloadly.io/) or [AltStore](https://altstore.io/) (from your Windows PC over USB!).
   - **`mone-ios-simulator-app`**: Unpack and drag into any Xcode iOS Simulator.

---

## 🚀 Running on Mac & Xcode (Local)

When you clone this Git repository on a physical Mac:

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

## ⚡ Silent Background SMS Tracking (Zero Screen Opening!)

`mone` utilizes Apple's **`AppIntents` framework** (`openAppWhenRun = false`). Transactions are logged **silently in the background** without ever switching away from your current app, game, or video!

### Apple Shortcuts Silent Setup (1 Minute):
1. Open the **Shortcuts** app on your iPhone.
2. Tap the **Automation** tab at the bottom -> tap **+** (Create Personal Automation).
3. Select **Message** as the trigger.
4. Set **Message Contains**: `debited`, `credited`, `spent`, `UPI`, `ATM`.
5. Select **Run Immediately** (and turn off *"Notify When Run"*).
6. Tap **Next** -> tap **New Blank Automation** -> tap **Add Action**.
7. Search for **mone** -> select **"Log Bank SMS in mone"**.
8. Tap the **SMS Body** field -> select **Shortcut Input**.
9. Tap **Done**!

> [!NOTE]
> When your bank sends an SMS alert, iOS runs `LogBankSmsIntent` **in ~50 milliseconds in the background**. The app never opens to the foreground, anti-fraud filters reject spam/OTPs, the transaction is enqueued to local storage, and the **Dynamic Island** briefly flashes the transaction summary!

---

## 🎙️ Siri Intelligence via App Intents

`mone` integrates natively with Siri and Apple Intelligence:
- **"Hey Siri, check daily spending in mone"** -> Siri reads back your today's total spending, transaction count, and remaining balance.
- **"Hey Siri, what's my balance in mone?"** -> Siri announces your net worth across all connected accounts.

---

## 📱 Interactive Home Screen Widgets & Dynamic Island

- **Home Screen Widget**:
  - Add the **mone Balance** widget (Small or Medium) to your Home Screen.
  - Features real-time balance, today's spending, and last merchant chip.
  - **Interactive Privacy Toggle (iOS 17+)**: Tap the eye icon directly on the widget to blur or reveal your balance without opening the app!
- **Dynamic Island & Live Activities (iOS 16.1+)**:
  - When money moves, a sleek capsule pops on the Dynamic Island for 6 seconds displaying `-₹450 at Swiggy • Bal: ₹14,250`.

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
