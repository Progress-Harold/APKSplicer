#!/usr/bin/env bash
# Aurora — repo scaffolding bootstrap
# Usage: bash bootstrap.sh
set -euo pipefail

ROOT_DIR=${1:-"aurora"}
echo "🛠  Creating Aurora repo scaffold at: ${ROOT_DIR}"
mkdir -p "$ROOT_DIR"
cd "$ROOT_DIR"

# --- Directories ------------------------------------------------------------
mkdir -p host-app/Sources/{App,UI,Core,Input,Telemetry}
mkdir -p agent-apk/app/src/main/{java/com/aurora/agent,res,xml}
mkdir -p profiles/{schemas,presets/{performance,device}}
mkdir -p images
mkdir -p scripts
mkdir -p docs

# --- .gitignore -------------------------------------------------------------
cat > .gitignore <<'EOF'
# macOS
.DS_Store

# Xcode
build/
DerivedData/
*.xcworkspace/
*.xcodeproj/xcuserdata/

# Android/Gradle
.gradle/
*.iml
local.properties
captures/
*.apk
*.aab

# Logs
logs/
Aurora.diagnostic.zip

# VM images
images/*.img
images/*.qcow2
images/*.iso
EOF

# --- README -----------------------------------------------------------------
cat > README.md <<'EOF'
# Aurora — macOS Android XAPK Player (Experimental)

Developer‑focused macOS app to install and run Android `.xapk`/`.apk` packages inside a managed Android VM. Prioritizes clean install flows, input mapping, basic device spoofing ("spiffing"), and tunable CPU/RAM/disk/resolution profiles.

**Ethics & Legal:** No Google Play Services bundled. No DRM circumvention. Only use with apps you legally own.

## Quick Start
- Create the Xcode macOS app manually (App target: `host-app` sources).
- Build the Android Agent with Android Studio from `agent-apk`.
- Provide a guest Android image under `images/` (see `images/README.md`).
- Run `scripts/install-xapk.sh <path/to/file.xapk>` once the VM is bootable.

See `docs/` and `profiles/` for details.
EOF

# --- Docs -------------------------------------------------------------------
cat > docs/COMPATIBILITY_MATRIX.md <<'EOF'
# Compatibility Matrix (Living Doc)

| Title | Android Version | Guest ABI | Profile | Status | Notes |
|------:|-----------------|-----------|---------|--------|-------|
| sample-app | 12 | arm64 | Medium | ✅ | baseline smoke test |
EOF

# --- Images README ----------------------------------------------------------
cat > images/README.md <<'EOF'
# Guest Images

Aurora does not ship proprietary images. Provide your own Android guest image:

- Preferred: **Android arm64 GSI (Android 12/13)**
- Fallback: **Android-x86** builds

Place your image as `images/guest-arm64.img` (or `guest-x86_64.img`). Update paths in `scripts/bootstrap-images.sh` accordingly.
EOF

# --- Scripts ----------------------------------------------------------------
cat > scripts/bootstrap-images.sh <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
# Placeholder: document how to fetch/convert images.
echo "Download or convert your Android guest image and place it at images/guest-arm64.img"
EOF
chmod +x scripts/bootstrap-images.sh

cat > scripts/diagnostics.sh <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
OUT="Aurora.diagnostic.zip"
LOGROOT="$HOME/Library/Logs/Aurora"
mkdir -p "$LOGROOT"
echo "Collecting logs → $OUT"
zip -r "$OUT" "$LOGROOT" profiles docs/COMPATIBILITY_MATRIX.md || true
EOF
chmod +x scripts/diagnostics.sh

cat > scripts/install-xapk.sh <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
XAPK=${1:-}
if [[ -z "$XAPK" ]]; then
  echo "Usage: $0 <file.xapk>"; exit 1; fi
WORK=$(mktemp -d)
cleanup(){ rm -rf "$WORK"; }
trap cleanup EXIT

# 1) Unpack
unzip -q "$XAPK" -d "$WORK"
# Heuristics: find base & splits
BASE=$(find "$WORK" -name "*base*.apk" -o -name "base.apk" | head -n1)
SPLITS=$(find "$WORK" -name "split*.apk" | sort || true)
PKG=$(aapt dump badging "$BASE" 2>/dev/null | awk -F\' '/package: name=/{print $2}')

# 2) OBBs (optional)
OBB_DIR=$(find "$WORK" -type d -name "Android" -o -name "obb" | head -n1 || true)
if [[ -n "$OBB_DIR" ]]; then
  echo "Pushing OBBs…"
  adb shell mkdir -p "/sdcard/Android/obb/$PKG" || true
  adb push "$OBB_DIR" "/sdcard/Android/obb/" || true
fi

# 3) Install
echo "Installing $PKG…"
adb install-multiple -r $BASE $SPLITS

# 4) Done
echo "✅ Installed: $PKG"
EOF
chmod +x scripts/install-xapk.sh

# --- Profiles: JSON Schema --------------------------------------------------
cat > profiles/schemas/profile.schema.json <<'EOF'
{
  "$schema": "https://json-schema.org/draft/2020-12/schema",
  "title": "Aurora Performance Profile",
  "type": "object",
  "required": ["name", "cpu", "ram_mb", "disk_gb", "display"],
  "properties": {
    "name": {"type": "string"},
    "cpu": {"type": "integer", "minimum": 1, "maximum": 12},
    "ram_mb": {"type": "integer", "minimum": 1024, "maximum": 32768},
    "disk_gb": {"type": "integer", "minimum": 4, "maximum": 256},
    "display": {
      "type": "object",
      "required": ["width", "height", "refresh_hz"],
      "properties": {
        "width": {"type": "integer", "minimum": 640, "maximum": 5120},
        "height": {"type": "integer", "minimum": 480, "maximum": 2880},
        "refresh_hz": {"type": "integer", "enum": [60]},
        "dpi": {"type": "integer", "minimum": 120, "maximum": 640}
      }
    },
    "overrides": {
      "type": "object",
      "properties": {
        "thermal_stepdown": {"type": "boolean"},
        "abi_preference": {"type": "string", "enum": ["arm64", "x86_64"]}
      }
    }
  }
}
EOF

# --- Profiles: Presets ------------------------------------------------------
cat > profiles/presets/performance/low.json <<'EOF'
{ "name": "Low", "cpu": 2, "ram_mb": 3072, "disk_gb": 8,
  "display": {"width": 1280, "height": 720, "refresh_hz": 60, "dpi": 240},
  "overrides": {"thermal_stepdown": true, "abi_preference": "arm64"} }
EOF

cat > profiles/presets/performance/medium.json <<'EOF'
{ "name": "Medium", "cpu": 4, "ram_mb": 6144, "disk_gb": 16,
  "display": {"width": 1920, "height": 1080, "refresh_hz": 60, "dpi": 320},
  "overrides": {"thermal_stepdown": true, "abi_preference": "arm64"} }
EOF

cat > profiles/presets/performance/high.json <<'EOF'
{ "name": "High", "cpu": 8, "ram_mb": 12288, "disk_gb": 32,
  "display": {"width": 2560, "height": 1440, "refresh_hz": 60, "dpi": 400},
  "overrides": {"thermal_stepdown": true, "abi_preference": "arm64"} }
EOF

# --- Device Preset (Spiffing) ----------------------------------------------
cat > profiles/presets/device/pixel7pro.json <<'EOF'
{
  "name": "Pixel 7 Pro",
  "props": {
    "ro.product.brand": "google",
    "ro.product.model": "Pixel 7 Pro",
    "ro.build.fingerprint": "google/panther/panther:13/TQ3A.230805.001/1234567:user/release-keys",
    "ro.product.cpu.abi": "arm64-v8a"
  },
  "sensors": { "accelerometer": true, "gyroscope": true }
}
EOF

# --- Host App (Swift) -------------------------------------------------------
cat > host-app/Sources/App/AuroraApp.swift <<'EOF'
import SwiftUI

@main
struct AuroraApp: App {
  @StateObject private var store = AppStore()
  var body: some Scene {
    WindowGroup {
      MainWindow()
        .environmentObject(store)
    }
    .windowStyle(.automatic)
  }
}

final class AppStore: ObservableObject {
  @Published var library: [TitleDescriptor] = []
  @Published var logsPath: URL = FileManager.default
    .homeDirectoryForCurrentUser
    .appending(path: "Library/Logs/Aurora", directoryHint: .isDirectory)
}
EOF

cat > host-app/Sources/UI/MainWindow.swift <<'EOF'
import SwiftUI

struct MainWindow: View {
  @EnvironmentObject private var store: AppStore
  @State private var showingInstaller: Bool = false

  var body: some View {
    VStack(alignment: .leading, spacing: 12) {
      HStack { Text("Aurora") .font(.largeTitle).bold(); Spacer() }
      LibraryGrid(titles: store.library)
      HStack {
        Button("Install .xapk / .apk") { showingInstaller = true }
        Spacer()
      }
    }
    .padding(20)
    .fileImporter(isPresented: $showingInstaller, allowedContentTypes: [.item], allowsMultipleSelection: false) { result in
      if case .success(let urls) = result, let url = urls.first {
        Task { try? await InstallerFlow.shared.handle(url: url) }
      }
    }
  }
}

struct LibraryGrid: View {
  let titles: [TitleDescriptor]
  var body: some View {
    if titles.isEmpty { EmptyState() } else { Text("TODO: Grid") }
  }
}

struct EmptyState: View {
  var body: some View {
    RoundedRectangle(cornerRadius: 12)
      .stroke(.secondary, style: StrokeStyle(lineWidth: 1, dash: [6]))
      .overlay(Text("Drop .xapk here to install").padding()).frame(height: 180)
  }
}

struct TitleDescriptor: Identifiable, Hashable { let id = UUID(); let package: String; let name: String }
EOF

cat > host-app/Sources/Core/VMProfiles.swift <<'EOF'
import Foundation

public struct DisplaySpec: Codable { public var width: Int; public var height: Int; public var refresh_hz: Int; public var dpi: Int? }
public struct PerformanceProfile: Codable { public var name: String; public var cpu: Int; public var ram_mb: Int; public var disk_gb: Int; public var display: DisplaySpec }

enum ProfileError: Error { case invalid }

enum ProfileLoader {
  static func loadPreset(named name: String) throws -> PerformanceProfile {
    let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
    let url = base.appending(path: "Aurora/profiles/presets/performance/\(name.lowercased()).json")
    let data = try Data(contentsOf: url)
    return try JSONDecoder().decode(PerformanceProfile.self, from: data)
  }
}
EOF

cat > host-app/Sources/Core/VMManager.swift <<'EOF'
import Foundation

public struct VMSpec: Codable {
  public var cpu: Int
  public var ramMB: Int
  public var diskGB: Int
  public var display: DisplaySpec
}

final class VMManager {
  static let shared = VMManager()
  private init() {}

  func create(spec: VMSpec, imageURL: URL) async throws {
    // TODO: AVF-backed VM creation and boot
  }

  func start() async throws { /* TODO */ }
  func stop() async throws { /* TODO */ }
  func reset() async throws { /* TODO */ }
}
EOF

cat > host-app/Sources/Core/ADBBridge.swift <<'EOF'
import Foundation

enum ADBError: Error { case notFound, commandFailed(String) }

enum ADB {
  @discardableResult
  static func run(_ args: [String]) throws -> String {
    let task = Process()
    let pipe = Pipe()
    task.standardOutput = pipe
    task.standardError = pipe
    task.launchPath = "/usr/bin/env"
    task.arguments = ["adb"] + args
    try task.run(); task.waitUntilExit()
    let data = pipe.fileHandleForReading.readDataToEndOfFile()
    let out = String(decoding: data, as: UTF8.self)
    guard task.terminationStatus == 0 else { throw ADBError.commandFailed(out) }
    return out
  }
}
EOF

cat > host-app/Sources/Core/XAPKInstaller.swift <<'EOF'
import Foundation

enum InstallerError: Error { case invalidArchive, baseAPKNotFound }

final class InstallerFlow {
  static let shared = InstallerFlow()
  private init() {}

  func handle(url: URL) async throws {
    if url.pathExtension.lowercased() == "xapk" { try await installXAPK(url) }
    else if url.pathExtension.lowercased() == "apk" { try await installAPK(url) }
    else { throw InstallerError.invalidArchive }
  }

  private func installAPK(_ url: URL) async throws {
    _ = try ADB.run(["install", "-r", url.path])
  }

  private func installXAPK(_ url: URL) async throws {
    let work = URL(fileURLWithPath: NSTemporaryDirectory()).appending(path: UUID().uuidString, directoryHint: .isDirectory)
    try FileManager.default.createDirectory(at: work, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: work) }
    try Shell.unzip(archive: url, to: work)
    let base = try Shell.findFirst(in: work, matching: "(base|\n)\.apk$")
    let splits = try Shell.findAll(in: work, matching: "split.*\\.apk$")
    _ = try ADB.run(["install-multiple", "-r"] + [base.path] + splits.map { $0.path })
    if let (pkg, obbDir) = try? Shell.findOBB(in: work) {
      _ = try? ADB.run(["shell", "mkdir", "-p", "/sdcard/Android/obb/\(pkg)"])
      _ = try? ADB.run(["push", obbDir.path, "/sdcard/Android/obb/"])
    }
  }
}

enum Shell {
  static func unzip(archive: URL, to dest: URL) throws {
    _ = try run(["unzip", "-q", archive.path, "-d", dest.path])
  }
  static func run(_ args: [String]) throws -> String {
    let task = Process(); let pipe = Pipe()
    task.standardOutput = pipe; task.standardError = pipe
    task.launchPath = "/usr/bin/env"; task.arguments = args
    try task.run(); task.waitUntilExit()
    let data = pipe.fileHandleForReading.readDataToEndOfFile()
    let out = String(decoding: data, as: UTF8.self)
    if task.terminationStatus != 0 { throw InstallerError.invalidArchive }
    return out
  }
  static func findFirst(in root: URL, matching regex: String) throws -> URL {
    let files = try findAll(in: root, matching: regex)
    guard let first = files.first else { throw InstallerError.baseAPKNotFound }
    return first
  }
  static func findAll(in root: URL, matching pattern: String) throws -> [URL] {
    let re = try NSRegularExpression(pattern: pattern, options: [.caseInsensitive])
    let fm = FileManager.default
    let enumerator = fm.enumerator(at: root, includingPropertiesForKeys: nil)!
    var matches: [URL] = []
    for case let url as URL in enumerator {
      let name = url.lastPathComponent
      if re.firstMatch(in: name, options: [], range: NSRange(location: 0, length: name.utf16.count)) != nil {
        matches.append(url)
      }
    }
    return matches.sorted { $0.lastPathComponent < $1.lastPathComponent }
  }
  static func findOBB(in root: URL) throws -> (String, URL) {
    // heuristic: find package from base.apk then locate Android/obb
    // Placeholder — implement with aapt/dumpsys if available
    throw InstallerError.invalidArchive
  }
}
EOF

cat > host-app/Sources/Input/InputMapper.swift <<'EOF'
import Foundation

struct InputBinding: Codable, Hashable {
  var action: String
  var key: String
  var position: (x: Double, y: Double)
}

final class InputMapper {
  func handle(key: String, down: Bool) {
    // TODO: translate to tap/hold via Agent
  }
}
EOF

cat > host-app/Sources/Telemetry/Telemetry.swift <<'EOF'
import Foundation

struct FrameStats: Codable { var fps: Double; var frameMs: Double; var cpu: Double; var gpu: Double }
final class Telemetry { static let shared = Telemetry() }
EOF

# --- Android Agent (Kotlin) -------------------------------------------------
cat > agent-apk/settings.gradle.kts <<'EOF'
rootProject.name = "AuroraAgent"
include(":app")
EOF

cat > agent-apk/build.gradle.kts <<'EOF'
buildscript {
  repositories { google(); mavenCentral() }
  dependencies { classpath("com.android.tools.build:gradle:8.5.2") }
}
allprojects { repositories { google(); mavenCentral() } }
EOF

cat > agent-apk/app/build.gradle.kts <<'EOF'
plugins { id("com.android.application") }
android {
  namespace = "com.aurora.agent"
  compileSdk = 34
  defaultConfig {
    applicationId = "com.aurora.agent"
    minSdk = 26
    targetSdk = 34
    versionCode = 1
    versionName = "1.0"
  }
  buildTypes { getByName("release") { isMinifyEnabled = false } }
}
dependencies { }
EOF

cat > agent-apk/app/src/main/AndroidManifest.xml <<'EOF'
<manifest xmlns:android="http://schemas.android.com/apk/res/android"
  package="com.aurora.agent">
  <application android:label="AuroraAgent" android:allowBackup="false">
    <service
      android:name=".InputService"
      android:exported="false"
      android:permission="android.permission.BIND_ACCESSIBILITY_SERVICE">
      <intent-filter>
        <action android:name="android.accessibilityservice.AccessibilityService" />
      </intent-filter>
      <meta-data
        android:name="android.accessibilityservice"
        android:resource="@xml/service_config" />
    </service>
  </application>
</manifest>
EOF

cat > agent-apk/app/src/main/java/com/aurora/agent/InputService.kt <<'EOF'
package com.aurora.agent

import android.accessibilityservice.AccessibilityService
import android.view.accessibility.AccessibilityEvent

class InputService : AccessibilityService() {
  override fun onAccessibilityEvent(event: AccessibilityEvent?) { /* TODO */ }
  override fun onInterrupt() { }
  fun tap(x: Int, y: Int) { /* TODO: inject via gestures API */ }
}
EOF

cat > agent-apk/app/src/main/res/xml/service_config.xml <<'EOF'
<?xml version="1.0" encoding="utf-8"?>
<accessibility-service
  xmlns:android="http://schemas.android.com/apk/res/android"
  android:accessibilityEventTypes="typeAllMask"
  android:accessibilityFeedbackType="feedbackGeneric"
  android:notificationTimeout="50"
  android:canPerformGestures="true"
  android:accessibilityFlags="flagDefault"/>
EOF

# --- Done -------------------------------------------------------------------
echo "✅ Scaffold created. Next steps:\n1) Open Xcode and create the macOS app target pointing to host-app/Sources\n2) Open agent-apk in Android Studio and build the agent APK\n3) Provide a guest image under images/, then wire up AVF in VMManager"
