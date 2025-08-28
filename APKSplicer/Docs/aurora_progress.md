# Aurora — Progress.md (MVP Execution Plan)

> **Project**: Aurora — macOS Android XAPK Player (Experimental)
>
> **Purpose**: A developer‑focused Mac app that installs and runs Android `.xapk`/`.apk` packages inside a managed Android VM with first‑class input mapping, device spoofing ("spiffing"), and tunable performance profiles.
>
> **Style reference**: Structure inspired by prior Progress docs. See reference in repo docs. (Style ref: fileciteturn0file0)

---

## Project Status
- **Started**: 2025‑01‑27
- **Target MVP Cut**: 2025‑03‑15 (7 weeks)
- **Current Phase**: Phase A — Foundation
- **Overall Progress**: 25% (Foundation architecture complete)

### Current Implementation Status
- ✅ Basic Xcode project structure created
- ✅ SwiftUI app entry point with SwiftData integration
- ✅ Documentation structure established
- ✅ Cursor rules and project guidelines defined
- ⏳ Need to implement Aurora-specific architecture

## Required Access & Resources
- [x] Xcode 15+ (Apple Silicon host recommended) — ✅ Available
- [ ] Apple Developer account (for signing + entitlements if needed)
- [ ] Android Platform Tools (`adb`) on PATH — Install via: `brew install android-platform-tools`
- [ ] Android guest images (Android 12/13 arm64 GSI or Android‑x86 9/11/12)
  - **Recommended**: [Android 13 GSI arm64](https://ci.android.com/builds/branches/aosp-android13-gsi/grid) 
  - **Intel fallback**: [Android-x86 12.1](https://www.android-x86.org/releases/releasenote-12-1-r5.html)
- [ ] Apple **Virtualization.framework** entitlement (com.apple.vm.networking for network access)
- [ ] Test `.xapk` and `.apk` packages we legally own
  - Suggest: F-Droid apps for initial testing (e.g., Simple Gallery, VLC)
  - Game testing: APKs from itch.io or direct developer sources

---

## Performance & Resource Profiles (Critical)
**Goal:** Make CPU core allocation, RAM, disk, and display resolution explicit, repeatable, and per‑title tunable.

### Preset Profiles
- **Low**  
  **CPU**: 2 vCPUs  
  **RAM**: 3 GB  
  **Disk**: 8 GB expandable sparse  
  **Resolution**: 1280×720 (720p), 60 Hz  
  **Use**: Visual novels, light 2D, utilities

- **Medium**  
  **CPU**: 4 vCPUs  
  **RAM**: 6 GB  
  **Disk**: 16 GB expandable sparse  
  **Resolution**: 1920×1080 (1080p), 60 Hz  
  **Use**: Most 3D titles, balanced latency

- **High**  
  **CPU**: 6–8 vCPUs (cap to host)  
  **RAM**: 8–12 GB  
  **Disk**: 32 GB expandable sparse  
  **Resolution**: 2560×1440 (1440p) or 1920×1080 upscaled, 60 Hz  
  **Use**: Demanding 3D titles; priority on smoothness

### Custom Resolution / Per‑Title Overrides
- **Custom**: User may set width/height, DPI, refresh rate (clamped to safe ranges).  
- **Per‑Title Profile**: Each title stores chosen profile + overrides in `profiles/<package>.json`.
- **Thermal Guardrails**: Drop to Medium if host ≥ 80°C sustained or frame pacing > 33 ms for > 45 s.

**Acceptance Benchmarks** (M‑series baseline, Medium profile):
- Cold boot VM < 20 s; Warm boot < 5 s
- 1080p stable 55–60 FPS on mainstream titles
- Input round‑trip latency < 60 ms median

---

## Epics, User Stories, and Tickets

### Epic A — Host App Foundation (SwiftUI Shell)
**Goal:** Create the macOS app shell, library, settings, and job queue.

**User Stories**
- **US‑A1**: As a user, I can open Aurora and see an empty library and an **Install** CTA.
- **US‑A2**: As a user, I can drag‑drop an `.xapk`/`.apk` to begin install.
- **US‑A3**: As a user, I can view Settings (General, Profiles, Diagnostics).

**Technical Tickets**
- [x] **AUR‑A‑001** App scaffold (SwiftUI app, MV pattern, modular targets) — ✅ Basic scaffold in place
- [ ] **AUR‑A‑002** Library grid + detail sidesheet (title metadata stub)
  - Replace default SwiftData `Item` model with `InstalledTitle` model
  - Create grid layout with app icons, names, install status
  - Add detail sidesheet with title info, profiles, and controls
- [ ] **AUR‑A‑003** Settings screens (General, Profiles, Diagnostics)
  - **General**: ADB path, default profile, theme preferences
  - **Profiles**: Performance preset editor, device spoofing profiles
  - **Diagnostics**: Log level, export location, crash reporting opt-in
- [ ] **AUR‑A‑004** Async job runner & toasts (install/build/launch states)
  - Implement `@ObservableObject JobManager` with `TaskPhase` enum
  - Use SwiftUI `.toast()` modifier for status updates
  - Progress indicators for install/boot/launch operations
- [ ] **AUR‑A‑005** File association + drag‑drop handler
  - Register for `.xapk` and `.apk` file types in `Info.plist`
  - Implement `DropDelegate` for drag-and-drop installation
  - File picker as fallback for manual selection

**Acceptance Criteria**
- [ ] App launches, navigates without errors; drag‑drop opens installer flow.
  - **Success metric**: Drag .xapk file shows installer dialog within 2 seconds

---

### Epic B — VM Backend (AVF Primary)
**Goal:** Boot Android guest via Apple Virtualization Framework; present frames via Metal.

**User Stories**
- **US‑B1**: As a user, I can create a VM with a chosen **Performance Profile** (Low/Medium/High).
- **US‑B2**: As a user, I can start/stop/reset the VM; Aurora remembers my settings per title.
- **US‑B3**: As a user, I can set **Custom Resolution**.

**Technical Tickets**
- [ ] **AUR‑B‑001** VMManager: define spec (CPU/RAM/Disk/Display) structs
  - Create `VMConfiguration` struct with performance profile mapping
  - Define `VirtualMachine` wrapper around `VZVirtualMachine`
  - Resource validation (ensure host has sufficient CPU/RAM)
- [ ] **AUR‑B‑002** AVF boot of Android arm64 GSI (document image source)
  - `VZLinuxBootLoader` configuration for Android kernel
  - Kernel command line: `androidboot.hardware=ranchu androidboot.console=ttyAMA0`
  - Initial ramdisk setup for Android boot sequence
- [ ] **AUR‑B‑003** Sparse disk creation + expansion (per‑title)
  - Use `VZDiskImageStorageDeviceAttachment` with expandable images
  - Per-title disk images: `~/Library/Application Support/Aurora/disks/<package_id>.img`
  - Automatic expansion based on profile disk limits
- [ ] **AUR‑B‑004** Virtio‑gpu surface → **MetalKit** view; v‑sync & scaling
  - `VZVirtioGraphicsDeviceConfiguration` with Metal surface
  - Custom `MTKView` subclass for frame presentation
  - Aspect ratio preservation with letterboxing/pillarboxing
- [ ] **AUR‑B‑005** NAT networking; port‑forward ADB
  - `VZNATNetworkDeviceAttachment` for guest internet access
  - Port forwarding: host:5555 → guest:5555 for ADB
  - Optional: Restrict network access per-title
- [ ] **AUR‑B‑006** Snapshot/Reset; warm boot path
  - VM state persistence using `VZVirtualMachine.saveMachineState`
  - Quick reset: restore from clean disk snapshot
  - Warm boot: resume from saved state (<5s target)
- [ ] **AUR‑B‑007** Resolution manager (720p/1080p/1440p/custom)
  - Dynamic resolution switching via virtio-gpu
  - DPI scaling coordination with Android display metrics
  - Per-title resolution persistence

**Acceptance Criteria**
- [ ] VM cold boot < 20 s (Medium profile); frame presented in window; ADB reachable.
  - **Success metrics**: 
    - Android boot animation visible in Metal view
    - `adb devices` shows connected VM
    - No kernel panics or graphics corruption

---

### Epic C — XAPK/APK Installer
**Goal:** Robust parsing and installation of `.xapk` and `.apk` with OBB placement.

**User Stories**
- **US‑C1**: As a user, I can drop an `.xapk` and have Aurora install base+split APKs and OBBs.
- **US‑C2**: As a user, I can drop a single `.apk` and install it with minimal steps.

**Technical Tickets**
- [ ] **AUR‑C‑001** XAPK parser (ZIP walk, manifest detection)
  - Use `Compression` framework for ZIP extraction
  - Parse `manifest.json` for package metadata and split info
  - Validate file integrity with checksums if available
- [ ] **AUR‑C‑002** Validate splits (arch/dpi/lang) and choose correct set
  - Detect host device capabilities (arm64, screen density)
  - Filter splits by ABI compatibility (`arm64-v8a` preferred)
  - Language split selection based on system locale
- [ ] **AUR‑C‑003** OBB placement to `/sdcard/Android/obb/<package>/`
  - Extract OBB files from XAPK to temp directory
  - Use `adb push` with progress monitoring
  - Verify OBB placement with `adb shell ls -la`
- [ ] **AUR‑C‑004** `adb install-multiple` + retry/backoff
  - Implement exponential backoff for failed installs
  - Parse install errors and provide user-friendly messages
  - Handle insufficient storage, signature conflicts
- [ ] **AUR‑C‑005** Install logs + failure diagnostics bundle
  - Capture full `adb install` output and logcat during install
  - Package failure artifacts: XAPK metadata, error logs, system info
  - Export as timestamped ZIP for debugging

**Acceptance Criteria**
- [ ] Known good `.xapk` installs in < 90 s with clear logs; app appears in guest launcher and runs.
  - **Success metrics**:
    - Install progress visible with accurate time estimates
    - App icon appears in Android launcher
    - App launches without immediate crashes

---

### Epic D — ADB Bridge & Guest Agent (APK)
**Goal:** Reliable host↔guest comms for install, input, metrics.

**User Stories**
- **US‑D1**: As a dev, I can view `logcat` and export diagnostics.
- **US‑D2**: As a user, Aurora can inject basic taps/swipes without root.

**Technical Tickets**
- [ ] **AUR‑D‑001** Host ADB abstraction; port‑forward; shell exec
- [ ] **AUR‑D‑002** Guest Agent APK (Kotlin) with Accessibility Service
- [ ] **AUR‑D‑003** Secure control channel (ADB TCP; auth token)
- [ ] **AUR‑D‑004** Logcat stream + save; artifact bundling
- [ ] **AUR‑D‑005** Health/heartbeat; readiness probe for installer

**Acceptance Criteria**
- [ ] Agent installs and starts automatically; tap/swipe commands move UI in guest reliably.

---

### Epic E — Input Mapping (Keyboard/Mouse/Controller)
**Goal:** Low‑latency mapping of host input to guest touch/gestures; per‑title profiles.

**User Stories**
- **US‑E1**: As a gamer, I can map WASD + mouse to touch zones.
- **US‑E2**: As a user, I can save/load mappings per title.

**Technical Tickets**
- [ ] **AUR‑E‑001** Input capture (IOHID/EventTaps) + GameController.framework
- [ ] **AUR‑E‑002** Mapping schema + UI editor; JSON store
- [ ] **AUR‑E‑003** Multi‑touch chords; swipe macros
- [ ] **AUR‑E‑004** Latency budgeter (queue tuning; coalescing)

**Acceptance Criteria**
- [ ] Median input round‑trip < 60 ms at 1080p (Medium profile).

---

### Epic F — Device Spoofing ("Spiffing")
**Goal:** Provide realistic device/build props and sensor presence to improve compatibility (not DRM bypass).

**User Stories**
- **US‑F1**: As a user, I can pick a device profile (e.g., Pixel 7 Pro) per title.
- **US‑F2**: As a dev, I can toggle root **only** on a dedicated Dev image.

**Technical Tickets**
- [ ] **AUR‑F‑001** Build.prop overlay system; preset profiles
- [ ] **AUR‑F‑002** ABI preference flags (favor arm64)
- [ ] **AUR‑F‑003** Sensor fakes endpoint (gyro/accel via Agent)
- [ ] **AUR‑F‑004** Rooted Dev image pipeline (separate download)

**Acceptance Criteria**
- [ ] Titles that reject obvious emulators proceed to login/menus with standard profiles (best‑effort; no guarantees).

---

### Epic G — Resource & Resolution Manager
**Goal:** First‑class controls for CPU/RAM/Disk/Resolution presets and per‑title overrides.

**User Stories**
- **US‑G1**: As a user, I can pick **Low/Medium/High** performance profiles.
- **US‑G2**: As a user, I can override **Custom Resolution**.

**Technical Tickets**
- [ ] **AUR‑G‑001** Profile presets module (structs + persistence)
- [ ] **AUR‑G‑002** Disk allocator (sparse image resize; warnings)
- [ ] **AUR‑G‑003** Thermal/latency guardrail auto‑step‑down
- [ ] **AUR‑G‑004** Per‑title profile switch at launch

**Acceptance Criteria**
- [ ] Switching profiles applies on next boot; resolution changes apply live or next boot (document behavior).

---

### Epic H — Telemetry, HUD, Diagnostics
**Goal:** Visibility into performance and easy issue reporting.

**User Stories**
- **US‑H1**: As a user, I can toggle an FPS/frametime HUD.
- **US‑H2**: As a dev, I can export a diagnostics bundle (config + logs + timings).

**Technical Tickets**
- [ ] **AUR‑H‑001** HUD overlay (FPS, frametime, CPU/GPU est., thermal)
- [ ] **AUR‑H‑002** Diagnostics exporter (.zip)
- [ ] **AUR‑H‑003** Crash catcher & recovery prompts

**Acceptance Criteria**
- [ ] One‑click diagnostics export; HUD cost < 3% perf impact.

---

### Epic I — UX Flows & Library
**Goal:** End‑to‑end installer → playable flow; clean failure paths.

**User Stories**
- **US‑I1**: As a user, I can install and launch in < 5 steps.
- **US‑I2**: As a user, I can reset a broken title and reinstall quickly.

**Technical Tickets**
- [ ] **AUR‑I‑001** Install wizard (drag‑drop → confirm → progress)
- [ ] **AUR‑I‑002** Title card details (package id, profile, last played)
- [ ] **AUR‑I‑003** Failure dialog with actionable next steps

**Acceptance Criteria**
- [ ] E2E happy‑path install → play succeeds on a test title.

---

### Epic J — Security, Privacy, Legal
**Goal:** Ship an ethical developer tool.

**User Stories**
- **US‑J1**: As a user, I can read clear legal/usage policies.
- **US‑J2**: As a privacy‑minded user, I can opt‑in to diagnostics.

**Technical Tickets**
- [ ] **AUR‑J‑001** Privacy & Policy page (in‑app + docs)
- [ ] **AUR‑J‑002** Opt‑in crash reporting (off by default)
- [ ] **AUR‑J‑003** Sandbox config; safe storage paths

**Acceptance Criteria**
- [ ] No data leaves machine unless explicitly opted‑in.

---

### Epic K — QEMU Fallback (Intel/Compatibility)
**Goal:** Provide a non‑AVF path for broader compatibility (Phase C).

**User Stories**
- **US‑K1**: As a user on Intel Mac, I can still boot a guest and test apps.

**Technical Tickets**
- [ ] **AUR‑K‑001** QEMU launcher + config generator
- [ ] **AUR‑K‑002** vsock/ADB bridging; display fallback (SPICE/VNC) for debug

**Acceptance Criteria**
- [ ] Title boots and is controllable on Intel with caveats documented.

---

### Epic L — Testing & CI
**Goal:** Automated checks for parser, VM orchestration, and performance.

**User Stories**
- **US‑L1**: As a dev, I can run headless smoke tests that boot VM and install a small test APK.

**Technical Tickets**
- [ ] **AUR‑L‑001** Unit tests: parser, profiles, persistence
- [ ] **AUR‑L‑002** Integration: headless boot + `adb install` smoke test
- [ ] **AUR‑L‑003** Perf tests: boot time, input latency harness

**Acceptance Criteria**
- [ ] CI runs on each PR; fails if boot > thresholds or parser regresses.

---

## Implementation Order (A → Z)

### Phase A — Foundation (Weeks 1–2) — **IN PROGRESS**
1. [x] **AUR‑A‑001** App scaffold — ✅ 2025-01-27
2. [x] **AUR‑B‑001** VM spec structs — ✅ 2025-01-27 (VMManager, PerformanceProfile, VMConfiguration)
3. [ ] **AUR‑B‑002** AVF boot (hello world frame) — **NEXT** (needs Android kernel)
4. [ ] **AUR‑B‑005** ADB port‑forward; reachability check
5. [x] **AUR‑A‑005** Drag‑drop handler → install flow stub — ✅ 2025-01-27 (basic file import)

**Phase A Priority**: Get basic VM boot working with display output before moving to installer.

### Recent Progress (2025-01-27)
- ✅ Added Virtualization.framework entitlements (vm.networking, vm.device-access)
- ✅ Implemented comprehensive error handling with AuroraError enum
- ✅ Created domain models: InstalledTitle, PerformanceProfile, VMConfiguration
- ✅ Built VMManager with AVF integration (ready for Android kernel)
- ✅ Replaced default SwiftUI/SwiftData app with Aurora-specific UI
- ✅ Added job management system for install progress tracking
- ✅ Created modern macOS app interface with sidebar and detail views

### Phase B — Install & Play (Weeks 2–4)
6. **AUR‑C‑001..005** XAPK installer pipeline
7. **AUR‑D‑001..005** ADB bridge + Guest Agent (taps/swipes)
8. **AUR‑E‑001..004** Input mapping v1 (keyboard/mouse; JSON profiles)

### Phase C — Performance & Profiles (Weeks 4–6)
9. **AUR‑G‑001..004** Resource & Resolution Manager (Low/Med/High + Custom)
10. **AUR‑B‑003..004** Disk expansion + Metal presentation polish
11. **AUR‑H‑001..003** HUD + Diagnostics bundle

### Phase D — Compatibility & UX Polish (Weeks 6–8)
12. **AUR‑F‑001..004** Device Spoofing (spiffing) presets
13. **AUR‑I‑001..003** Install wizard + failure flows + library details
14. **AUR‑J‑001..003** Privacy/Policy + sandboxing + opt‑in crash reports

### Phase E — Fallback & Test Matrix (Weeks 8–10)
15. **AUR‑K‑001..002** QEMU path (Intel)
16. **AUR‑L‑001..003** CI & perf harness; baseline matrix

**MVP Exit Criteria**
- [ ] A known test `.xapk` installs and runs at **1080p/60 Hz** on **Medium** profile with median input latency **< 60 ms**.
- [ ] Per‑title profiles persist; reset/reinstall works cleanly.
- [ ] Diagnostics export produces actionable bundle.

---

## Testing Requirements
- [ ] **E2E**: Drag‑drop `.xapk` → install → launch → map inputs → play → quit → relaunch
- [ ] **Perf**: Boot times, steady FPS, latency percentiles (P50/P95)
- [ ] **Failure**: Corrupt `.xapk`, missing OBB, ADB drop, low disk
- [ ] **Profiles**: Switch Low/Med/High; apply Custom Resolution; thermal step‑down

---

## Notes for Cursor Execution
1. Always update this file after each ticket: mark `[x]` with short commit hash.
2. Keep module boundaries strict: **VM**, **Installer**, **Agent**, **Input**, **Profiles**.
3. Add env guardrails: warn when host free disk < 10 GB, RAM pressure high, or CPU saturated.
4. Log everything to `~/Library/Logs/Aurora/` with per‑title subfolders.
5. Scripts live under `/scripts`; no binaries checked‑in under `/images`.

### Implementation Guidelines
- **Swift Package Structure**: Use SPM for modular architecture (Core, VM, Installer, etc.)
- **Error Handling**: Use `Result<T, AuroraError>` for all async operations
- **Logging**: Structured logging with `os_log` for production and `print()` for debug
- **Testing**: Write unit tests for parsers and business logic; integration tests for VM operations
- **Performance**: Profile with Instruments; measure boot times and frame rates regularly
- **Documentation**: Update cursor rules when adding new architectural patterns

### Current Technical Debt
- Replace SwiftData `Item` model with Aurora domain models
- Implement proper error types instead of generic errors
- Add entitlements for Virtualization.framework
- Create proper module structure instead of single-file architecture

### Technical Architecture Details

#### Apple Virtualization Framework Integration
```swift
// Core VM Configuration Pattern
struct VMConfiguration {
    let cpuCount: Int
    let memorySize: UInt64  // in bytes
    let diskImage: URL
    let display: DisplayConfiguration
}

// Required AVF Components:
// - VZVirtualMachineConfiguration
// - VZLinuxBootLoader (Android kernel)
// - VZVirtioGraphicsDeviceConfiguration (GPU)
// - VZVirtioBlockDeviceConfiguration (Storage)
// - VZVirtioNetworkDeviceConfiguration (Network)
```

#### Metal Rendering Pipeline
```swift
// Frame presentation chain:
// VZVirtioGraphicsDevice → VZGraphicsDisplay → MTKView
// Target: 60fps with <16.67ms frame time
// Scaling: Aspect-fit with letterboxing for resolution mismatches
```

#### ADB Communication Architecture
```
Host Process → ADB TCP (localhost:5555) → VM NAT → Guest ADB Daemon
              ↓
        Aurora Agent APK (Accessibility Service)
              ↓
        Input Events → Android Input Subsystem
```

#### File System Layout
```
~/Library/Application Support/Aurora/
├── disks/                     # Per-title VM disks
│   ├── com.example.app.img   # Sparse disk images
│   └── templates/            # Clean disk snapshots
├── profiles/                 # Performance & device configs
│   ├── performance/          # CPU/RAM/Disk presets
│   └── devices/             # Build.prop spoofing
├── cache/                   # Temporary install files
└── logs/                    # Per-title debug logs
```

---

## Dependencies to Request
- Android guest image sources (documented URLs)
- Optional rooted Dev image (separate download channel)
- Apple Dev account for signing (if needed)
- Test `.xapk` samples owned by us

---

## Glossary
- **XAPK**: Zip bundle with base+split APKs and OBB assets
- **AVF**: Apple Virtualization Framework
- **Spiffing**: Project term for *device spoofing* (build props/sensors)
- **Profile**: Preset of CPU/RAM/Disk/Resolution for a VM

---

**End of MVP Execution Plan**

