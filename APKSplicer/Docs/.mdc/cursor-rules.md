# Aurora macOS Android XAPK Player - Cursor Rules

## Project Overview
Aurora is a developer-focused macOS app that installs and runs Android `.xapk`/`.apk` packages inside a managed Android VM with first-class input mapping, device spoofing ("spiffing"), and tunable performance profiles.

## Key Principles
- **Ethics & Legal**: No Google Play Services bundled. No DRM circumvention. Only use with apps you legally own.
- **Developer-First**: Predictable, inspectable, and scriptable; logs and diagnostics built-in.
- **Performance**: Target 60 FPS at 1080p on M-series Macs with <60ms input latency.
- **Isolation**: VM-based isolation with per-title configurations and reset capabilities.

## Architecture Components

### Host (macOS)
- **SwiftUI Shell**: Main UI, library management, settings
- **VM Manager**: Apple Virtualization Framework (AVF) primary, QEMU fallback
- **XAPK Installer**: ZIP parsing, APK installation, OBB placement
- **ADB Bridge**: Device management, logcat viewing, shell commands
- **Input Mapper**: Keyboard/mouse/controller → touch/gesture translation
- **Device Spoof Manager**: Build.prop overlays, sensor emulation
- **Telemetry**: Performance HUD, diagnostics export

### Guest (Android)
- **Aurora Agent APK**: Input injection, sensor emulation, heartbeat monitoring
- **Android Images**: GSI arm64 (preferred), Android-x86 (fallback)

## File Structure & Organization

```
APKSplicer/
├── APKSplicer/                    # Main Xcode project
│   ├── Sources/
│   │   ├── App/                   # SwiftUI app entry point
│   │   ├── UI/                    # User interface components
│   │   ├── Core/                  # VM management, profiles, ADB
│   │   ├── Input/                 # Input mapping engine
│   │   └── Telemetry/             # Performance monitoring
│   ├── Docs/                      # Documentation and progress tracking
│   └── Resources/                 # Assets, profiles, configurations
├── Agent/                         # Android companion app (Kotlin)
├── Scripts/                       # Build tools, diagnostics, installers
└── Profiles/                      # JSON schemas and presets
```

## Coding Standards

### Swift/SwiftUI
- Use `@StateObject` for view models, `@ObservableObject` for data stores
- Prefer `async/await` for VM operations and file I/O
- Use structured concurrency with `Task` for background operations
- Follow Apple's SwiftUI patterns for navigation and data flow
- Use `Combine` for reactive data binding where appropriate

### Architecture Patterns
- **MVVM**: Clear separation between Views, ViewModels, and Models
- **Dependency Injection**: Use protocols and dependency containers
- **Error Handling**: Structured error types with user-friendly messages
- **Logging**: Comprehensive logging to `~/Library/Logs/Aurora/`

### Performance Guidelines
- **VM Resource Management**: Enforce CPU/RAM/Disk limits per profile
- **Input Latency**: Target <60ms end-to-end for input mapping
- **Frame Presentation**: Use Metal for GPU-accelerated rendering
- **Thermal Management**: Auto-step-down on sustained >80°C host temps

## Development Workflow

### Task Management
- **Always** update `aurora_progress.md` after completing tickets
- Mark completed items with `[x]` and include commit hash
- Break large features into smaller, testable components
- Use Epic → User Story → Technical Ticket hierarchy

### Testing Strategy
- **Unit Tests**: XAPK parser, profile serialization, input mapping
- **Integration Tests**: Headless VM boot + ADB install smoke tests
- **Performance Tests**: Boot times, frame pacing, input latency
- **Compatibility Matrix**: Track per-title status across Android versions

### Code Quality
- **Linting**: Use SwiftLint for consistent code style
- **Documentation**: Inline docs for public APIs
- **Error Recovery**: Graceful failure with actionable next steps
- **Privacy**: No data leaves machine unless explicitly opted-in

## Key Technologies

### Primary Stack
- **Virtualization.framework**: VM creation and management (Apple Silicon)
- **Metal/MetalKit**: GPU-accelerated frame presentation
- **GameController.framework**: Controller input support
- **IOHID/EventTaps**: Low-latency input capture
- **Swift Package Manager**: Dependency management

### Fallback Technologies
- **QEMU**: VM backend for Intel Macs
- **libarchive/minizip**: XAPK parsing if Swift libs insufficient
- **Android Platform Tools**: ADB for device management

## Security & Privacy

### Sandboxing
- macOS app is sandboxed
- VM disk images in `~/Library/Application Support/Aurora`
- No network access without explicit user permission

### Data Handling
- No analytics by default
- Opt-in crash reports with PII sanitization
- All logs stored locally unless user exports

### Legal Compliance
- Clear usage policies for user-owned apps only
- No proprietary firmware or GMS bundling
- Device spoofing for compatibility, not circumvention

## Performance Profiles

### Preset Configurations
- **Low**: 2 vCPUs, 3GB RAM, 8GB disk, 720p60
- **Medium**: 4 vCPUs, 6GB RAM, 16GB disk, 1080p60
- **High**: 6-8 vCPUs, 8-12GB RAM, 32GB disk, 1440p60
- **Custom**: User-defined within safe ranges

### Acceptance Benchmarks (M-series, Medium profile)
- Cold boot VM: <20s
- Warm boot: <5s
- 1080p stable: 55-60 FPS
- Input latency: <60ms median

## Epic Priority Order

1. **Epic A**: Host App Foundation (SwiftUI shell, library, settings)
2. **Epic B**: VM Backend (AVF boot, Metal presentation, ADB bridge)
3. **Epic C**: XAPK/APK Installer (parsing, validation, installation)
4. **Epic D**: ADB Bridge & Guest Agent (communication, input injection)
5. **Epic E**: Input Mapping (keyboard/mouse/controller → touch)
6. **Epic F**: Device Spoofing (build.prop overlays, sensor fakes)
7. **Epic G**: Resource & Resolution Manager (profile switching)
8. **Epic H**: Telemetry & Diagnostics (HUD, performance monitoring)
9. **Epic I**: UX Flows & Library (end-to-end user experience)
10. **Epic J**: Security & Privacy (policies, opt-in telemetry)

## File Naming Conventions

### Swift Files
- `*Manager.swift`: Singleton coordinators (VMManager, ADBBridge)
- `*Store.swift`: ObservableObject data stores
- `*View.swift`: SwiftUI view components
- `*Model.swift`: Data structures and business logic
- `*Error.swift`: Error type definitions

### Configuration Files
- `*.json`: Profile configurations, device presets
- `*.plist`: Xcode project settings, entitlements
- `*.md`: Documentation, progress tracking
- `*.sh`: Build scripts, diagnostic tools

## Dependencies & External Tools

### Required System Tools
- Xcode 15+ (Apple Silicon recommended)
- Android Platform Tools (adb on PATH)
- Apple Developer account (for signing if needed)

### Optional Tools
- Android Studio (for Agent APK development)
- QEMU (Intel Mac fallback)
- Test .xapk/.apk files (user-provided)

## Progress Tracking Rules

### Ticket Management
- Use format: `AUR-[Epic]-[Number]` (e.g., AUR-A-001)
- Include acceptance criteria for each ticket
- Link to Epic goals and user stories
- Update progress.md immediately after completion

### Documentation Updates
- Keep compatibility matrix current with test results
- Update architecture docs when adding new components
- Maintain glossary of project-specific terms
- Document all external dependencies and their purposes

## Common Patterns & Anti-Patterns

### ✅ Good Practices
- Use Swift concurrency for async operations
- Validate user input and provide clear error messages
- Log all VM operations for debugging
- Test with real .xapk files from the start
- Keep VM resource allocation explicit and tunable

### ❌ Anti-Patterns
- Don't bundle proprietary Android components
- Avoid blocking UI thread with VM operations
- Don't hardcode file paths or resource limits
- Never ship debugging/root access enabled by default
- Avoid platform-specific code without fallbacks

## Emergency Procedures

### VM Recovery
- Automatic VM reset on critical failures
- Diagnostic bundle generation for bug reports
- Graceful degradation when host resources are low
- Clear user messaging for failure scenarios

### Data Protection
- Automatic backup of user profiles before updates
- Safe rollback mechanisms for configuration changes
- Clear separation of user data and system files
- Export capabilities for user migration

Remember: Aurora is a developer tool first - prioritize transparency, debuggability, and user control over complexity hiding.
