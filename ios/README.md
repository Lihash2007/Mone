# mone (iOS Edition) 🍏

> **Autonomous Offline Personal Finance OS for iOS 17.0+**  
> Tailored specifically for modern iPhones (iPhone 14 Pro, iPhone 15 series, iPhone 16 series) with **Headless AppIntents**, **Dynamic Island & Live Activities**, **Interactive Home Screen Widgets**, **Interactive Action Notifications**, and **Siri Intelligence**.

---

## ☁️ Zero-Mac Cloud Build (GitHub Actions)

You don't need a Mac or a VirtualBox VM to build this iOS app. GitHub Actions compiles it automatically in the cloud on Apple Silicon runners (`macos-14`):

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

## 🏝️ Dynamic Island & Live Activities (How to Use)

`mone` utilizes Apple's **`ActivityKit`** to provide an instant, ambient heads-up whenever money moves, without ever opening the app.

### 1. Enabling Live Activities on iPhone:
- On your iPhone, open **Settings** -> scroll down to **mone**.
- Tap **Live Activities** and ensure **Allow Live Activities** and **More Frequent Updates** are toggled **ON**.

### 2. How It Appears on Your Screen:
Whenever a transaction is logged (via background SMS, Siri, or manually):
- **Compact Island (Top Pill)**:
  - Left side: `[↓ ₹450]` (in crimson red for debits or emerald green for credits)
  - Right side: `[Swiggy]` or merchant name
- **Expanded Island (Long-Press on Dynamic Island)**:
  - **Left**: Bank chip icon + Bank name (`HDFC Bank`) + Merchant (`Swiggy`)
  - **Right**: Large formatted amount (`-₹450.00`) + Available balance (`Bal: ₹14,250`)
  - **Bottom**: Subtle status indicator (`mone Autonomous Ledger • Updated in background`)
- **Lock Screen / StandBy Mode**:
  - Displays a high-contrast dark glass card with direction badge, merchant, bank name, and remaining balance.
- **Auto-Dismissal**:
  - The Dynamic Island pill automatically dismisses itself after **6 seconds** so your screen stays clean and uncluttered.

---

## 🔔 Interactive Action Notifications (Confirm, Transfer, Income)

When a bank transaction alert arrives, `mone` fires an instant interactive notification banner:

### How to Use the Action Buttons:
1. When the notification arrives (`⚡ ₹450 Spent • HDFC Bank (Swiggy)`):
2. **Press and hold (Haptic Touch)** or **pull down** on the notification banner.
3. The notification expands with 3 native action buttons:
   - **`[✓ Confirm]`**: Marks the transaction as verified and clears the review flag.
   - **`[⇄ Transfer]`**: Reclassifies the expense as an internal account transfer.
   - **`[+ Income]`**: Reclassifies it as salary or incoming deposit.
4. **Zero Screen Switching**: Tapping any of these actions updates your local SQLite database **silently in the background** without switching away from your current game, video, or chat.

---

## 📱 Interactive Home Screen Widgets (iOS 17+)

`mone` provides interactive widgets designed with modern dark-glass aesthetics (`#09090B` with neon indigo accents):

### How to Add the Widget:
1. Long-press any empty space on your iPhone Home Screen until the apps jiggle.
2. Tap the **+** button in the top-left corner.
3. Search for **mone**.
4. Choose your preferred size:
   - **Small (2x2)**: Live Total Net Worth + Today's Spending badge.
   - **Medium (4x2)**: Live Total Net Worth + Recent Transaction chip (`HDFC Bank • Swiggy -₹350`) + Today's Spend total.
5. Tap **Add Widget**.

### Interactive Privacy Toggle:
- Tap the **eye icon** (`👁️`) directly on the widget to instantly blur (`••••••`) or unblur your sensitive financial balance without opening the app.

---

## ⚡ Silent Background SMS Tracking (Zero Screen Opening!)

`mone` utilizes Apple's **`AppIntents` framework** (`openAppWhenRun = false`). Transactions are logged **silently in the background** without ever switching away from whatever you're doing.

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
> When your bank sends an SMS alert, iOS executes `LogBankSmsIntent` in **~50 milliseconds in the background**. The app never opens to the foreground, anti-fraud filters reject spam/OTPs, the transaction is enqueued to local storage, and the **Dynamic Island** briefly flashes the transaction summary!

---

## 🎙️ Siri Intelligence via App Intents

`mone` integrates natively with Siri and Apple Intelligence:
- **"Hey Siri, check daily spending in mone"** (or *"How much did I spend today on mone?"*)  
  → Siri responds: *"You have spent ₹450 today across 2 transactions. Remaining balance is ₹34,500."*
- **"Hey Siri, what's my balance in mone?"**  
  → Siri announces your net worth across all connected accounts.

---

## 📋 Smart Clipboard Auto-Detection & Manual Paste

- **Clipboard Auto-Detection**: If you copy a bank SMS from WhatsApp, Telegram, or Messages, opening `mone` detects it on launch and presents an instant 1-tap **"Import Transaction"** card.
- **Manual SMS Paste**: Tap **"From SMS"** or use the **"Paste Bank SMS Text"** tile in Profile to paste any raw message text. The real-time parser shows recognized amounts, merchants, and categories on the fly.

---

## 🔒 Privacy & Security

- **100% Offline SQLite**: No financial data ever leaves your device.
- **Biometric Security**: Native **Face ID** / **Touch ID** protection via `local_auth` and `NSFaceIDUsageDescription`.
- **Zero Third-Party Trackers**: Self-contained parsing engine (`sms_parser.dart` and `indian_banks.dart`).

---

## 📁 Key Files

- `lib/main.dart`: Core app UI, background notification action listener, App Group data synchronization.
- `ios/Runner/AppIntents.swift`: Headless `LogBankSmsIntent`, Siri intents (`CheckDailySpendingIntent`, `GetBalanceIntent`), and Siri Shortcuts provider.
- `ios/Runner/LiveActivities.swift`: ActivityKit Live Activity controller & Dynamic Island attributes.
- `ios/Runner/MoneWidgets.swift`: SwiftUI Home Screen Widgets with iOS 17 interactive privacy toggle & Dynamic Island layouts.
- `lib/services/sms_parser.dart`: High-precision Indian banking SMS parser engine.
- `lib/services/indian_banks.dart`: 25+ verified Indian bank styles, logos, BINs, and card widgets.
- `ios/Runner/Info.plist`: URL schemes, Face ID description, and Live Activities enablement.
