import os
import re

dart_path = r'c:\Users\lihas\Documents\Projects\money\frontend\lib\main.dart'
with open(dart_path, 'r', encoding='utf-8') as f:
    dart_content = f.read()

perm_logic = """  Future<void> _initDatabase() async {
    try {
      final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin = FlutterLocalNotificationsPlugin();
      await flutterLocalNotificationsPlugin.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()?.requestNotificationsPermission();
    } catch (_) {}
"""

dart_content = dart_content.replace("  Future<void> _initDatabase() async {", perm_logic)

with open(dart_path, 'w', encoding='utf-8') as f:
    f.write(dart_content)

print("Applied permission request")
