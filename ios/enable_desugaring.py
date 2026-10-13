import os
import re

path = r'c:\Users\lihas\Documents\Projects\money\frontend\android\app\build.gradle'
with open(path, 'r', encoding='utf-8') as f:
    content = f.read()

# Enable coreLibraryDesugaring in compileOptions
if 'coreLibraryDesugaringEnabled true' not in content:
    content = re.sub(
        r'(compileOptions\s*\{)',
        r'\1\n        coreLibraryDesugaringEnabled true',
        content
    )

# Add dependency for desugar_jdk_libs
if 'coreLibraryDesugaring' not in content:
    dependencies_block = """dependencies {
    coreLibraryDesugaring 'com.android.tools:desugar_jdk_libs:2.0.3'"""
    
    if 'dependencies {' in content:
        content = content.replace('dependencies {', dependencies_block)
    else:
        content += "\n" + dependencies_block + "\n}\n"

with open(path, 'w', encoding='utf-8') as f:
    f.write(content)

print("Enabled core library desugaring")
