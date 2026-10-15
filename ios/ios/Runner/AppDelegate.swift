import Flutter
import UIKit
import UserNotifications
import WidgetKit

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    UNUserNotificationCenter.current().delegate = self
    registerMoneNotificationCategories()
    UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { granted, error in
      if let error = error {
        print("Notification authorization error: \(error)")
      }
    }
    
    let result = super.application(application, didFinishLaunchingWithOptions: launchOptions)
    
    if let controller = window?.rootViewController as? FlutterViewController {
      setupNativeMethodChannel(messenger: controller.binaryMessenger)
    }

    return result
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)
  }

  private func setupNativeMethodChannel(messenger: FlutterBinaryMessenger) {
    let channel = FlutterMethodChannel(name: "com.personalmoneyos.mone/native_sync", binaryMessenger: messenger)
    channel.setMethodCallHandler { (call, result) in
      if call.method == "getPendingTransactions" {
        let storage = UserDefaults(suiteName: "group.com.personalmoneyos.frontend") ?? UserDefaults.standard
        let json = storage.string(forKey: "pending_transactions_json") ?? "[]"
        result(json)
      } else if call.method == "clearPendingTransactions" {
        let storage = UserDefaults(suiteName: "group.com.personalmoneyos.frontend") ?? UserDefaults.standard
        storage.removeObject(forKey: "pending_transactions_json")
        storage.synchronize()
        result(true)
      } else if call.method == "syncBalanceToWidget" {
        if let args = call.arguments as? [String: Any] {
          let storage = UserDefaults(suiteName: "group.com.personalmoneyos.frontend") ?? UserDefaults.standard
          if let balance = args["balance"] as? Double {
            storage.set(balance, forKey: "raw_balance")
            storage.set(String(format: "₹ %.0f", balance), forKey: "balance")
          }
          if let todaySpent = args["todaySpent"] as? Double {
            storage.set(todaySpent, forKey: "raw_today_spent")
            storage.set(String(format: "₹ %.0f", todaySpent), forKey: "today_spent")
          }
          storage.synchronize()
          if #available(iOS 14.0, *) {
            WidgetCenter.shared.reloadAllTimelines()
          }
        }
        result(true)
      } else if call.method == "testNotification" {
        let text = (call.arguments as? [String: Any])?["text"] as? String ?? "HDFC Bank: Rs 450 debited at Swiggy on 13-Oct-26. Avl bal: Rs 34,500"
        let parsed = MoneSmsParser.parse(text: text)
        let notifId = UUID().uuidString
        let isoDate = ISO8601DateFormatter().string(from: Date())
        MoneSharedStorage.enqueuePendingTransaction([
            "id": notifId,
            "rawBody": text,
            "sender": "TEST-HDFCBK",
            "amount": parsed.amount,
            "merchant": parsed.merchant,
            "type": parsed.isDebit ? "EXPENSE" : "INCOME",
            "bankName": parsed.bankName,
            "accountMask": parsed.accountMask,
            "availableBalance": parsed.availableBalance ?? 0.0,
            "timestamp": isoDate,
            "confirmed": false
        ])
        registerMoneNotificationCategories()
        let center = UNUserNotificationCenter.current()
        let notifContent = UNMutableNotificationContent()
        notifContent.title = parsed.isDebit ? "₹\(String(format: "%.0f", parsed.amount)) Spent" : "₹\(String(format: "%.0f", parsed.amount)) Received"
        var bodyStr = "\(parsed.merchant) • \(parsed.bankName)"
        if let bal = parsed.availableBalance {
            bodyStr += " • Avl: ₹\(String(format: "%.0f", bal))"
        }
        bodyStr += "\nHold banner to Confirm or Transfer."
        notifContent.body = bodyStr
        notifContent.sound = .default
        notifContent.categoryIdentifier = "transaction_actions"
        notifContent.userInfo = [
            "id": notifId,
            "amount": parsed.amount,
            "merchant": parsed.merchant,
            "type": parsed.isDebit ? "EXPENSE" : "INCOME",
            "bankName": parsed.bankName
        ]
        let notifTrigger = UNTimeIntervalNotificationTrigger(timeInterval: 0.1, repeats: false)
        let notifRequest = UNNotificationRequest(identifier: notifId, content: notifContent, trigger: notifTrigger)
        center.add(notifRequest) { error in
            if let error = error {
                print("Failed to schedule test notification: \(error)")
            }
        }
        result(true)
      } else if call.method == "openUrl" {
        if let args = call.arguments as? [String: Any], let urlStr = args["url"] as? String, let url = URL(string: urlStr) {
          UIApplication.shared.open(url, options: [:]) { success in
            result(success)
          }
        } else {
          result(false)
        }
      } else {
        result(FlutterMethodNotImplemented)
      }
    }
  }

  override func userNotificationCenter(
    _ center: UNUserNotificationCenter,
    willPresent notification: UNNotification,
    withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
  ) {
    if #available(iOS 14.0, *) {
      completionHandler([.banner, .sound, .badge, .list])
    } else {
      completionHandler([.alert, .sound, .badge])
    }
  }

  override func userNotificationCenter(
    _ center: UNUserNotificationCenter,
    didReceive response: UNNotificationResponse,
    withCompletionHandler completionHandler: @escaping () -> Void
  ) {
    let actionId = response.actionIdentifier
    let notifId = response.notification.request.identifier
    if actionId == "confirm_ok" || actionId == "change_transfer" || actionId == "change_income" {
      MoneSharedStorage.updatePendingTransaction(id: notifId, actionId: actionId)
    }
    super.userNotificationCenter(center, didReceive: response, withCompletionHandler: completionHandler)
  }
}
