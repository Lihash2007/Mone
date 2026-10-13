import os
import re

# 1. Update AndroidManifest.xml
manifest_path = r'c:\Users\lihas\Documents\Projects\money\frontend\android\app\src\main\AndroidManifest.xml'
with open(manifest_path, 'r', encoding='utf-8') as f:
    manifest_content = f.read()

if 'android.permission.POST_NOTIFICATIONS' not in manifest_content:
    manifest_content = manifest_content.replace(
        '<application',
        '<uses-permission android:name="android.permission.POST_NOTIFICATIONS" />\n    <application'
    )
    with open(manifest_path, 'w', encoding='utf-8') as f:
        f.write(manifest_content)

# 2. Update main.dart
dart_path = r'c:\Users\lihas\Documents\Projects\money\frontend\lib\main.dart'
with open(dart_path, 'r', encoding='utf-8') as f:
    dart_content = f.read()

if 'package:flutter_local_notifications' not in dart_content:
    dart_content = "import 'package:flutter_local_notifications/flutter_local_notifications.dart';\n" + dart_content

notification_logic = """          await db.update('accounts', {'balance': newBal}, where: 'id = ?', whereArgs: [matchedAccountId]);
          
          try {
            final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin = FlutterLocalNotificationsPlugin();
            const AndroidInitializationSettings initializationSettingsAndroid = AndroidInitializationSettings('@mipmap/ic_launcher');
            const InitializationSettings initializationSettings = InitializationSettings(android: initializationSettingsAndroid);
            await flutterLocalNotificationsPlugin.initialize(initializationSettings);
            
            const AndroidNotificationDetails androidPlatformChannelSpecifics = AndroidNotificationDetails(
              'mone_sync_channel', 'Mone Auto Sync',
              channelDescription: 'Notifications for auto synced transactions',
              importance: Importance.max,
              priority: Priority.high,
            );
            const NotificationDetails platformChannelSpecifics = NotificationDetails(android: androidPlatformChannelSpecifics);
            
            String accName = accRow['name'] ?? 'Account';
            String title = isIncome ? 'Income Detected!' : 'Expense Logged!';
            String body = isIncome ? 'mone securely logged +₹${amount.toStringAsFixed(0)} to $accName.' : 'mone securely logged -₹${amount.toStringAsFixed(0)} from $accName.';
            
            await flutterLocalNotificationsPlugin.show(
              DateTime.now().millisecondsSinceEpoch % 100000,
              title,
              body,
              platformChannelSpecifics,
            );
          } catch (e) {}"""

dart_content = dart_content.replace("          await db.update('accounts', {'balance': newBal}, where: 'id = ?', whereArgs: [matchedAccountId]);", notification_logic)

with open(dart_path, 'w', encoding='utf-8') as f:
    f.write(dart_content)

print("Applied notifications successfully")
