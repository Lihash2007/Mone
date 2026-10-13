import os

path = r'c:\Users\lihas\Documents\Projects\money\frontend\android\app\build.gradle.kts'
with open(path, 'r', encoding='utf-8') as f:
    content = f.read()

content = content.replace('desugar_jdk_libs:2.0.4', 'desugar_jdk_libs:2.1.5')

with open(path, 'w', encoding='utf-8') as f:
    f.write(content)

print("Updated desugar_jdk_libs version")
