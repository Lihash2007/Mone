import os

path = r'c:\Users\lihas\Documents\Projects\money\frontend\lib\main.dart'
with open(path, 'r', encoding='utf-8') as f:
    content = f.read()

# 1. Fix initialize
content = content.replace(
    'await flutterLocalNotificationsPlugin.initialize(initializationSettings);',
    'await flutterLocalNotificationsPlugin.initialize(settings: initializationSettings);'
)

# 2. Fix accName type
content = content.replace(
    "String accName = accRow['name'] ?? 'Account';",
    "String accName = accRow['name']?.toString() ?? 'Account';"
)

# 3. Fix show method arguments
old_show = """            await flutterLocalNotificationsPlugin.show(
              DateTime.now().millisecondsSinceEpoch % 100000,
              title,
              body,
              platformChannelSpecifics,
            );"""
new_show = """            await flutterLocalNotificationsPlugin.show(
              id: DateTime.now().millisecondsSinceEpoch % 100000,
              title: title,
              body: body,
              notificationDetails: platformChannelSpecifics,
            );"""
content = content.replace(old_show, new_show)

with open(path, 'w', encoding='utf-8') as f:
    f.write(content)

print("Fixed compile errors")
