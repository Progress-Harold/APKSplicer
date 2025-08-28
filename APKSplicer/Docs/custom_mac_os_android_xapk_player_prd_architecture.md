# Project: Aurora — macOS Android XAPK Player (Experimental)

> **Purpose:** Build a developer‑focused, macOS app that can install and run Android `.xapk`/`.apk` packages inside a managed Android virtual machine, with first‑class game input mapping and optional device‑spoofing profiles. This is not a general‑purpose emulator; it’s a focused **player** for apps you legally own.

> **Scope note:** The goal is pragmatic reliability (stable GPU, sane input latency) using **Apple’s Virtualization Framework (AVF)** on Apple silicon as the primary path, and **QEMU** as a compatibility path. We avoid shipping Google Play Services. No DRM circumvention.

---

## 1) Vision & Non‑Goals

**Vision**
- One‑click install and launch of `.xapk` titles on macOS with clean UI, smooth graphics, controller support, and per‑app profiles.
- Developer‑first: predictable, inspectable, and scriptable; logs and diagnostics built‑in.

**Non‑Goals**
- Not a full Android device replacement.
- Not a Play Store client. No Google Mobile Services (GMS) bundling.
- No kernel‑level anti‑cheat bypassing or DRM circumvention.

---

## 2) User Stories

- **Install & Play**: “As a user, I can drag an `.xapk` onto Aurora to install the base/split APKs and OBBs, then launch the app.”
- **Profiles**: “As a user, I can choose a device profile (e.g., Pixel 7 Pro) to mimic typical hardware/build props.”
- **Controls**: “As a gamer, I can map keyboard/mouse/controller to touch/gestures with low latency.”
- **Stability**: “As a developer, I can capture logs, GPU stats, and crash traces to troubleshoot.”
- **Isolation**: “As a security‑minded user, I can run apps in isolated VMs and reset them per‑title.”

---

## 3) Functional Requirements (FR)

**FR‑1 XAPK Install**
- Parse `.xapk` (ZIP). Detect `base.apk`, split APKs, and OBB files.
- Use `adb install-multiple` for base+splits; place OBBs at `/sdcard/Android/obb/<package>/`.

**FR‑2 APK Install**
- Support single `.apk` sideload (with or without OBB companion directory).

**FR‑3 VM Lifecycle**
- Create, start, pause, stop, snapshot, and reset Android VMs.
- Per‑title VM option (clean state) and shared VM option (faster load).

**FR‑4 Graphics & Display**
- 60 FPS target rendering path via AVF virtio‑gpu to a Metal‑backed view.
- Fullscreen/windowed modes; resolution scaling per title.

**FR‑5 Input Mapping**
- Keyboard/mouse/controller → touch, swipe, multi‑touch combos.
- Per‑title bindings; export/import profiles (JSON).

**FR‑6 Device Spoofing**
- Select preset build props (model, manufacturer, fingerprint, ABI order) applied at boot.
- Toggle root‑like features **off by default**. Root mode is a separate, clearly marked developer switch.

**FR‑7 Networking**
- NAT networking with opt‑in port forwarding; per‑title toggles for background data.

**FR‑8 Telemetry & Logs**
- Built‑in `adb logcat` viewer, FPS/frametime HUD, CPU/GPU utilization overlay (host side), exportable diagnostics bundle.

**FR‑9 Updates**
- In‑app update for Aurora binaries; VM base images versioned and upgradable.

**FR‑10 Privacy & Safety**
- Clear privacy panel; no data exfiltration. Opt‑in crash reporting.

---

## 4) Non‑Functional Requirements (NFR)

- **Performance:** Smooth 60 FPS for mainstream mobile titles at 1080p on M‑series Macs; input latency under 60ms end‑to‑end (target).
- **Reliability:** VM boot < 20s cold start (target), < 5s warm start (target). Graceful failure & recovery.
- **Security:** VM isolation; code‑signed app; no bundled third‑party binaries with unknown provenance.
- **Compatibility:** Android 11–13 images (baseline); arm64 primary, x86_64 optional.
- **DX:** All actions scriptable via CLI; JSON profiles; deterministic logs.

---

## 5) System Architecture (High Level)

```mermaid
flowchart LR
  U[macOS App (SwiftUI)] -- controls --> VM[VM Manager]
  VM -- AVF/QEMU --> ANDROID[Android Guest OS]
  U -- ADB Bridge --> AGENT[In‑Guest Companion APK]
  U -- XAPK Parser --> INST[Installer]
  U -- Input Mapper --> AGENT
  ANDROID -- Framebuffer --> U
  U -- Profiles --> VM
```

**Host Components**
- **UI Shell (SwiftUI)**: Install wizard, library grid, per‑title settings, diagnostics.
- **VM Manager**: AVF (primary) or QEMU (fallback) orchestration; snapshots; image mgmt.
- **Display Renderer (MetalKit)**: Presents virtio‑gpu frames; v‑sync; scaling.
- **XAPK Installer**: Unzips, validates, installs via ADB; OBB placement.
- **ADB Bridge**: Lifecycle, file push/pull, port‑forward, logcat, shell.
- **Input Mapper**: Keyboard/mouse/controller → translated events; latency‑optimized.
- **Device Spoof Manager**: Applies build.prop overlays/boot args; presets library.
- **Telemetry**: HUD overlay, profiler, diagnostics exporter.

**Guest Components**
- **Aurora Agent (APK)**: Small Android app/service with:
  - Input injection (Accessibility Service or privileged `uinput` in rooted dev images).
  - Sensor emulation endpoints (accelerometer/gyro fakes from host).
  - Heartbeat & metrics channel back to host over ADB TCP port.
  - Optional per‑title bootstrap (grant storage, set window flags).

---

## 6) Technology & Languages

**Host (macOS)**
- **Swift / SwiftUI** — primary UI and orchestration.
- **Metal / MetalKit** — frame presentation & scaling.
- **Objective‑C/C** — thin shims where AVF/IOKit interop is simpler.
- **C/C++** — optional helpers (e.g., libarchive/xapk parsing if not using Swift libs).
- **Rust (optional)** — performance‑critical utilities (ADB multiplexer, profiler) if desired.

**Guest (Android)**
- **Kotlin/Java** — Aurora Agent APK.
- **Shell** — install scripts, property tweaks, service setup.

**Build/Dev**
- **Xcode** (macOS app), **Android Studio/Gradle** (Agent), **CMake** (native deps), **Cursor** for AI‑assisted coding.

---

## 7) Third‑Party Frameworks & Dependencies

**Primary Path (Apple Silicon, AVF)**
- **Virtualization.framework** (Apple) — VM creation, Virtio devices, display surface.
- **libarchive** or **minizip** — unpack `.xapk`.
- **ADB** (Android Platform Tools) — device mgmt, install, logs.
- **GameController.framework** — controller support (DualShock/Xbox/8BitDo/etc.).
- **IOHID / Quartz Event Taps** — low‑latency input capture (if needed).

**Fallback Path (Intel/Compatibility)**
- **QEMU** — VM backend with virtio‑gpu, virtio‑input, vsock; prebuilt or embedded.
- **SPICE/VNC (optional)** — debug display when GPU accel is unavailable.

**Android Images**
- **Android‑x86** and/or **Generic System Image (GSI) arm64** — base OS images.
- **microG (optional)** — user‑installed alternative to GMS (not bundled).

**Host‑Guest Comms**
- **ADB port‑forward** or **vsock** (QEMU) — control channel.

---

## 8) Device Spoofing Strategy (Anti‑Detection‑Lite)

- **Property Overlays:** Provide preset `build.prop` overlays (model, brand, fingerprint, density); applied at boot via vendor overlay or init scripts in our base image.
- **ABI Ordering:** Prefer arm64 where possible; hide x86 where feasible in x86 builds (inevitably detectable by some games).
- **Sensor Presence:** Expose plausible sensors (accelerometer/gyroscope) via Agent fakes; mark as non‑emulator in common heuristics.
- **Root Mode Off:** Default images non‑rooted; separate “Dev Image” with root & `uinput` for advanced mapping.

> Note: This does **not** guarantee bypassing emulator checks; the intent is compatibility, not circumvention.

---

## 9) UX Flows

**XAPK Install Flow**
1. Drag‑drop `.xapk` → Validate & parse.
2. Create per‑title VM (or select shared VM).
3. Boot VM → Wait for `adb` ready.
4. Install base+splits → Push OBBs.
5. Create input profile (auto map common actions) → Launch.

**First Launch Flow**
- Optional tutorial overlay for mapping keys; quick test for multi‑touch gestures.
- FPS/latency overlay toggle.

**Crash/Failure Flow**
- Auto‑collect logs + system snapshot; offer “Open Diagnostics” and “Reset VM”.

---

## 10) Security, Privacy, Legal

- **Sandboxing:** The macOS app is sandboxed; VM disk images stored under `~/Library/Application Support/Aurora`.
- **Data:** No analytics by default; opt‑in crash reports (sanitize PII).
- **Legal:** Do not ship GMS/Play; do not include proprietary firmware. Make clear: user must legally own the apps they install. No DRM bypass.

---

## 11) Testing Strategy

- **Host Unit Tests:** XAPK parser, installer orchestration, profile serialization, input mapping.
- **Integration Tests:** Headless VM boot + scripted ADB install of a test APK; smoke tests for input injection.
- **Performance Tests:** Frame pacing, input round‑trip latency, cold/warm boot timing.
- **Compatibility Matrix:** Track per‑title status across images (Android 11/12/13), device profiles, and host Macs (M1/M2/M3).

---

## 12) Release Plan (Phases)

**Phase A — MVP**
- AVF VM boot, windowed rendering.
- XAPK install pipeline (base+splits+OBB).
- Basic keyboard/mouse → single‑touch mapping.
- Library UI + per‑title configs.

**Phase B — Playability**
- Controller support; multi‑touch chords; swipe macros.
- FPS/HUD; diagnostics bundle; snapshots.
- Device spoofing presets (non‑root).

**Phase C — Polish & Compatibility**
- Optional QEMU fallback for Intel Macs.
- Sensor emulation (gyro/accelerometer) via Agent.
- Profile marketplace/export‑import.

---

## 13) Acceptance Criteria (MVP)

- Dragging a valid `.xapk` installs and launches the app successfully on an M‑series Mac.
- Title runs at stable frame rate in a resizable window with working audio.
- User can bind WASD + mouse to touch zones and save the profile.
- Diagnostics panel shows live logcat and frame timing.
- VM can be reset to a clean state and the title reinstalled without manual cleanup.

---

## 14) Open Questions & Risks

- **GPU Acceleration:** AVF virtio‑gpu performance consistency across macOS versions.
- **Anti‑Cheat/Detection:** Some online titles will still reject VMs; we won’t ship bypasses.
- **Legal/Distribution:** Ship without third‑party proprietary bits; require users to provide their own images when needed.
- **Input Injection:** Non‑root multi‑touch fidelity via Accessibility vs. rooted `uinput` tradeoffs.

---

## 15) Repo Structure (Monorepo; Cursor‑friendly)

```
/aurora
  /host-app            # Swift/SwiftUI macOS app
  /vm-backends         # AVF controller, QEMU launcher
  /xapk-installer      # Parser, validator, installer (Swift + C helpers)
  /adb-bridge          # Host ADB mgmt, logcat viewer
  /input-mapper        # Key/mouse/controller mapping engine
  /profiles            # JSON schemas, presets (device, input)
  /agent-apk           # Android (Kotlin) companion app
  /images              # Scripts to fetch/build Android images (no binaries committed)
  /docs                # PRD, tech notes, compatibility matrix
  /scripts             # CI tasks, packagers, diagnostics collectors
```

---

## 16) Implementation Notes & Tips

- Prefer **arm64 guest images** on Apple silicon for best compatibility.
- Treat x86 guest images as a fallback; some games check ABI and reject x86.
- For multi‑touch, start with an Accessibility Service + `adb shell input` fallback, then iterate toward `uinput` on a rooted **dev** image for advanced users.
- Keep device spoofing modest (common retail fingerprints). Avoid aggressive hooks that could be viewed as anti‑cheat bypass.
- Provide a CLI for power users: `aurora install <file.xapk>`, `aurora run <package>`, `aurora logs <package>`.

---

## 17) Future Ideas

- Headless mode + streaming to another Mac/iPad.
- Save states per title; quick‑resume across reboots.
- Community‑shared input/device profiles (signed manifests).
- Optional VT-X/Hypervisor parity checks and guidance.

---

**Status:** Draft v0.1 — ready for scoping and first spike tasks.

