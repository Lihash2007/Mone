# mone (Android Edition) 🤖

> **Autonomous Offline Personal Finance OS for Android**  
> Features real-time SMS background listener, battery optimization exemptions for 24/7 capture, interactive notification actions, biometric lock, and verified Indian bank directory.

---

## 🚀 Running on Android

```bash
# 1. Navigate to the Android folder
cd android

# 2. Get packages
flutter pub get

# 3. Deploy to connected Android device
flutter run -d <device_id>
```

---

## ⚡ Key Android Features
- **Background SMS Listener**: Automatically receives incoming SMS alerts via `telephony` broadcast receiver.
- **Actionable Notification Heads-up**: Push notifications with quick action buttons (`[Confirm]`, `[Transfer]`, `[Income]`).
- **Battery Optimization Bypass**: Requests exemption from Android Doze mode for uninterrupted 24/7 background capture.
- **Offline SQLite**: Database stored safely on device.
