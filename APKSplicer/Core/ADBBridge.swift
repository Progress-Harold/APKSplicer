//
//  ADBBridge.swift
//  APKSplicer
//
//  Created by Aurora Team on 2025-01-27.
//

import Foundation
import Combine
import os.log

/// Manages ADB (Android Debug Bridge) communication with Android VMs
@Observable
final class ADBBridge {
    static let shared = ADBBridge()
    
    // MARK: - Properties
    
    private let logger = Logger(subsystem: "com.aurora.apksplicer", category: "ADBBridge")
    private let defaultPort = 5555
    private let connectTimeout: TimeInterval = 10.0
    
    private(set) var isConnected = false
    private(set) var connectedDevice: String?
    private(set) var adbPath: String = "/usr/local/bin/adb"
    
    // MARK: - Initialization
    
    private init() {
        detectADBPath()
        
        // Check for existing connections on startup
        Task {
            _ = await checkExistingConnections()
        }
    }
    
    // MARK: - Public Interface
    
    /// Check if ADB is available and get version info
    func checkADBAvailability() async -> AuroraResult<String> {
        logger.info("Checking ADB availability at: \(self.adbPath)")
        
        do {
            let output = try await executeADBCommand(["version"])
            logger.info("ADB version check successful")
            return .success(output)
        } catch {
            logger.error("ADB not available: \(error.localizedDescription)")
            return .failure(.adbNotFound)
        }
    }
    
    /// Check for existing ADB connections and update connection status
    func checkExistingConnections() async -> AuroraResult<Void> {
        logger.info("Checking for existing ADB connections")
        
        do {
            let output = try await executeADBCommand(["devices"])
            let devices = parseDeviceList(output)
            
            // Find any connected device
            if let connectedDevice = devices.first(where: { $0.status == .device }) {
                self.isConnected = true
                self.connectedDevice = connectedDevice.identifier
                logger.info("Found existing ADB connection: \(connectedDevice.identifier)")
                return .success(())
            } else {
                self.isConnected = false
                self.connectedDevice = nil
                logger.info("No connected ADB devices found")
                return .failure(.adbConnectionFailed)
            }
        } catch {
            logger.error("Failed to check ADB connections: \(error.localizedDescription)")
            return .failure(.adbConnectionFailed)
        }
    }
    
    /// Connect to an Android device/VM on specified port
    func connect(to host: String = "localhost", port: Int = 5555) async -> AuroraResult<Void> {
        let target = "\(host):\(port)"
        logger.info("Connecting to Android device: \(target)")
        
        // First check if we already have a connection
        if case .success = await checkExistingConnections() {
            logger.info("Using existing ADB connection")
            return .success(())
        }
        
        do {
            // First disconnect any existing connections
            _ = try? await executeADBCommand(["disconnect"])
            
            // Connect to the target
            let output = try await executeADBCommand(["connect", target])
            
            if output.contains("connected") || output.contains("already connected") {
                self.isConnected = true
                self.connectedDevice = target
                logger.info("Successfully connected to \(target)")
                return .success(())
            } else {
                logger.error("ADB connection failed: \(output)")
                return .failure(.adbConnectionFailed)
            }
        } catch {
            logger.error("ADB connection error: \(error.localizedDescription)")
            return .failure(.adbConnectionFailed)
        }
    }
    
    /// Disconnect from current device
    func disconnect() async {
        guard isConnected else { return }
        
        logger.info("Disconnecting from ADB device")
        
        do {
            _ = try await executeADBCommand(["disconnect"])
        } catch {
            logger.error("Error during ADB disconnect: \(error.localizedDescription)")
        }
        
        isConnected = false
        connectedDevice = nil
    }
    
    /// List connected devices
    func listDevices() async -> AuroraResult<[ADBDevice]> {
        logger.info("Listing ADB devices")
        
        do {
            let output = try await executeADBCommand(["devices"])
            let devices = parseDeviceList(output)
            return .success(devices)
        } catch {
            logger.error("Failed to list ADB devices: \(error.localizedDescription)")
            return .failure(.adbConnectionFailed)
        }
    }
    
    /// Install an APK file
    func installAPK(at path: URL, options: APKInstallOptions = .default) async -> AuroraResult<Void> {
        logger.info("Installing APK: \(path.lastPathComponent)")
        
        guard isConnected else {
            return .failure(.adbConnectionFailed)
        }
        
        var args = ["install"]
        
        // Add install options
        if options.replaceExisting {
            args.append("-r")
        }
        if options.allowDowngrade {
            args.append("-d")
        }
        if options.grantPermissions {
            args.append("-g")
        }
        
        args.append(path.path)
        
        do {
            let output = try await executeADBCommand(args)
            
            if output.contains("Success") {
                logger.info("APK installation successful")
                return .success(())
            } else {
                logger.error("APK installation failed: \(output)")
                return .failure(.apkInstallationFailed(reason: output))
            }
        } catch {
            logger.error("APK installation error: \(error.localizedDescription)")
            return .failure(.apkInstallationFailed(reason: error.localizedDescription))
        }
    }
    
    /// Install multiple APKs (for split APKs/XAPK)
    func installMultipleAPKs(at paths: [URL], options: APKInstallOptions = .default) async -> AuroraResult<Void> {
        logger.info("Installing multiple APKs: \(paths.count) files")
        
        guard isConnected else {
            return .failure(.adbConnectionFailed)
        }
        
        var args = ["install-multiple"]
        
        if options.replaceExisting {
            args.append("-r")
        }
        if options.allowDowngrade {
            args.append("-d")
        }
        if options.grantPermissions {
            args.append("-g")
        }
        
        args.append(contentsOf: paths.map { $0.path })
        
        do {
            let output = try await executeADBCommand(args)
            
            if output.contains("Success") {
                logger.info("Multiple APK installation successful")
                return .success(())
            } else {
                logger.error("Multiple APK installation failed: \(output)")
                return .failure(.apkInstallationFailed(reason: output))
            }
        } catch {
            logger.error("Multiple APK installation error: \(error.localizedDescription)")
            return .failure(.apkInstallationFailed(reason: error.localizedDescription))
        }
    }
    
    /// Push file to Android device
    func pushFile(from localPath: URL, to remotePath: String) async -> AuroraResult<Void> {
        logger.info("Pushing file: \(localPath.lastPathComponent) -> \(remotePath)")
        
        guard isConnected else {
            return .failure(.adbConnectionFailed)
        }
        
        do {
            let output = try await executeADBCommand(["push", localPath.path, remotePath])
            
            if output.contains("pushed") || output.contains("file(s) pushed") {
                logger.info("File push successful")
                return .success(())
            } else {
                logger.error("File push failed: \(output)")
                return .failure(.adbConnectionFailed)
            }
        } catch {
            logger.error("File push error: \(error.localizedDescription)")
            return .failure(.adbConnectionFailed)
        }
    }
    
    /// Execute shell command on Android device
    func executeShellCommand(_ command: String) async -> AuroraResult<String> {
        logger.info("Executing shell command: \(command)")
        
        guard isConnected else {
            return .failure(.adbConnectionFailed)
        }
        
        do {
            let output = try await executeADBCommand(["shell", command])
            return .success(output)
        } catch {
            logger.error("Shell command failed: \(error.localizedDescription)")
            return .failure(.adbConnectionFailed)
        }
    }
    
    /// Uninstall an APK package
    func uninstallAPK(packageId: String, keepData: Bool = false) async -> AuroraResult<Void> {
        logger.info("Uninstalling APK: \(packageId)")
        
        guard isConnected else {
            return .failure(.adbConnectionFailed)
        }
        
        var args = ["uninstall"]
        
        // Add options
        if keepData {
            args.append("-k") // Keep data and cache directories
        }
        
        args.append(packageId)
        
        do {
            let output = try await executeADBCommand(args)
            
            if output.contains("Success") {
                logger.info("APK uninstallation successful: \(packageId)")
                return .success(())
            } else {
                logger.error("APK uninstallation failed: \(output)")
                return .failure(.apkUninstallationFailed(reason: output))
            }
        } catch {
            logger.error("APK uninstallation error: \(error.localizedDescription)")
            return .failure(.apkUninstallationFailed(reason: error.localizedDescription))
        }
    }
    
    /// List installed packages
    func listInstalledPackages(includeSystem: Bool = false) async -> AuroraResult<[InstalledPackage]> {
        logger.info("Listing installed packages")
        
        guard isConnected else {
            return .failure(.adbConnectionFailed)
        }
        
        var args = ["shell", "pm", "list", "packages"]
        
        if !includeSystem {
            args.append("-3") // Only show third-party packages
        }
        
        do {
            let output = try await executeADBCommand(args)
            let packages = parseInstalledPackages(output)
            return .success(packages)
        } catch {
            logger.error("Failed to list installed packages: \(error.localizedDescription)")
            return .failure(.adbConnectionFailed)
        }
    }
    
    /// Get package information
    func getPackageInfo(packageId: String) async -> AuroraResult<PackageInfo> {
        logger.info("Getting package info for: \(packageId)")
        
        guard isConnected else {
            return .failure(.adbConnectionFailed)
        }
        
        do {
            // Get package info
            let infoOutput = try await executeADBCommand(["shell", "dumpsys", "package", packageId])
            
            // Get package path
            let pathOutput = try await executeADBCommand(["shell", "pm", "path", packageId])
            
            let packageInfo = parsePackageInfo(packageId: packageId, dumpsysOutput: infoOutput, pathOutput: pathOutput)
            return .success(packageInfo)
        } catch {
            logger.error("Failed to get package info: \(error.localizedDescription)")
            return .failure(.adbConnectionFailed)
        }
    }
    
    /// Clear package data
    func clearPackageData(packageId: String) async -> AuroraResult<Void> {
        logger.info("Clearing data for package: \(packageId)")
        
        guard isConnected else {
            return .failure(.adbConnectionFailed)
        }
        
        do {
            let output = try await executeADBCommand(["shell", "pm", "clear", packageId])
            
            if output.contains("Success") {
                logger.info("Package data cleared successfully: \(packageId)")
                return .success(())
            } else {
                logger.error("Failed to clear package data: \(output)")
                return .failure(.adbConnectionFailed)
            }
        } catch {
            logger.error("Clear package data error: \(error.localizedDescription)")
            return .failure(.adbConnectionFailed)
        }
    }
    
    /// Get logcat output
    func getLogcat(filter: String? = nil, lines: Int = 100) async -> AuroraResult<String> {
        logger.info("Getting logcat output")
        
        guard isConnected else {
            return .failure(.adbConnectionFailed)
        }
        
        var args = ["logcat", "-d", "-t", "\(lines)"]
        
        if let filter = filter {
            args.append(filter)
        }
        
        do {
            let output = try await executeADBCommand(args)
            return .success(output)
        } catch {
            logger.error("Logcat failed: \(error.localizedDescription)")
            return .failure(.adbConnectionFailed)
        }
    }
    
    /// Check if Android system is ready
    func waitForDevice(timeout: TimeInterval = 30.0) async -> AuroraResult<Void> {
        logger.info("Waiting for Android device to be ready")
        
        let startTime = Date()
        
        while Date().timeIntervalSince(startTime) < timeout {
            do {
                let output = try await executeADBCommand(["shell", "getprop", "sys.boot_completed"])
                
                if output.trimmingCharacters(in: .whitespacesAndNewlines) == "1" {
                    logger.info("Android device is ready")
                    return .success(())
                }
                
                // Wait a bit before checking again
                try await Task.sleep(nanoseconds: 2_000_000_000) // 2 seconds
            } catch {
                // Continue waiting if command fails
                try? await Task.sleep(nanoseconds: 1_000_000_000) // 1 second
            }
        }
        
        logger.error("Timeout waiting for Android device")
        return .failure(.adbConnectionFailed)
    }
    
    // MARK: - Private Methods
    
    private func detectADBPath() {
        let possiblePaths = [
            "/usr/local/bin/adb",
            "/opt/homebrew/bin/adb",
            "/usr/bin/adb",
            "adb" // Let shell find it
        ]
        
        for path in possiblePaths {
            if path == "adb" {
                // For 'adb' without path, we'll test if it works
                self.adbPath = path
                logger.info("ADB path set to: \(path) (will test execution)")
                return
            } else if FileManager.default.fileExists(atPath: path) {
                // Check if the file is executable
                if FileManager.default.isExecutableFile(atPath: path) {
                    self.adbPath = path
                    logger.info("ADB path detected: \(path)")
                    return
                } else {
                    logger.warning("ADB found at \(path) but not executable")
                }
            }
        }
        
        logger.warning("ADB not found in standard locations")
    }
    
    private func executeADBCommand(_ arguments: [String]) async throws -> String {
        return try await withCheckedThrowingContinuation { continuation in
            let process = Process()
            let outputPipe = Pipe()
            let errorPipe = Pipe()
            
            // Use shell to execute ADB to avoid sandboxing issues
            process.executableURL = URL(fileURLWithPath: "/bin/bash")
            let adbCommand = "\(adbPath) " + arguments.map { "\"\($0)\"" }.joined(separator: " ")
            process.arguments = ["-c", adbCommand]
            process.standardOutput = outputPipe
            process.standardError = errorPipe
            
            // Set environment to include PATH
            var environment = ProcessInfo.processInfo.environment
            environment["PATH"] = "/usr/local/bin:/usr/bin:/bin:/opt/homebrew/bin"
            process.environment = environment
            
            process.terminationHandler = { _ in
                let outputData = outputPipe.fileHandleForReading.readDataToEndOfFile()
                let errorData = errorPipe.fileHandleForReading.readDataToEndOfFile()
                
                let output = String(data: outputData, encoding: .utf8) ?? ""
                let error = String(data: errorData, encoding: .utf8) ?? ""
                
                if process.terminationStatus == 0 {
                    continuation.resume(returning: output)
                } else {
                    self.logger.error("ADB command failed: \(error)")
                    let _ = error.isEmpty ? "ADB command failed with exit code \(process.terminationStatus)" : error
                    continuation.resume(throwing: AuroraError.adbConnectionFailed)
                }
            }
            
            do {
                try process.run()
            } catch {
                self.logger.error("Failed to execute ADB command via shell: \(error.localizedDescription)")
                continuation.resume(throwing: AuroraError.adbNotFound)
            }
        }
    }
    
    private func parseDeviceList(_ output: String) -> [ADBDevice] {
        let lines = output.components(separatedBy: .newlines)
        var devices: [ADBDevice] = []
        
        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
            
            // Skip empty lines and header
            if trimmed.isEmpty || trimmed.contains("List of devices") {
                continue
            }
            
            let components = trimmed.components(separatedBy: .whitespaces)
            if components.count >= 2 {
                let identifier = components[0]
                let status = components[1]
                
                devices.append(ADBDevice(
                    identifier: identifier,
                    status: ADBDeviceStatus(rawValue: status) ?? .unknown
                ))
            }
        }
        
        return devices
    }
    
    private func parseInstalledPackages(_ output: String) -> [InstalledPackage] {
        let lines = output.components(separatedBy: .newlines)
        var packages: [InstalledPackage] = []
        
        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
            
            // Lines are in format "package:com.example.app"
            if trimmed.hasPrefix("package:") {
                let packageId = String(trimmed.dropFirst(8)) // Remove "package:" prefix
                
                packages.append(InstalledPackage(
                    packageId: packageId,
                    isSystemApp: false // We filtered for third-party only
                ))
            }
        }
        
        return packages
    }
    
    private func parsePackageInfo(packageId: String, dumpsysOutput: String, pathOutput: String) -> PackageInfo {
        var versionName = "Unknown"
        var versionCode = 0
        var installLocation = "Unknown"
        
        // Parse dumpsys output for version info
        let lines = dumpsysOutput.components(separatedBy: .newlines)
        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
            
            if trimmed.contains("versionName=") {
                if let range = trimmed.range(of: "versionName=") {
                    let remaining = String(trimmed[range.upperBound...])
                    versionName = remaining.components(separatedBy: .whitespaces).first ?? "Unknown"
                }
            }
            
            if trimmed.contains("versionCode=") {
                if let range = trimmed.range(of: "versionCode=") {
                    let remaining = String(trimmed[range.upperBound...])
                    if let code = Int(remaining.components(separatedBy: .whitespaces).first ?? "0") {
                        versionCode = code
                    }
                }
            }
        }
        
        // Parse path output
        let pathLines = pathOutput.components(separatedBy: .newlines)
        for line in pathLines {
            let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
            if trimmed.hasPrefix("package:") {
                installLocation = String(trimmed.dropFirst(8))
                break
            }
        }
        
        return PackageInfo(
            packageId: packageId,
            versionName: versionName,
            versionCode: versionCode,
            installLocation: installLocation,
            isSystemApp: installLocation.contains("/system/")
        )
    }
}

// MARK: - Supporting Types

/// ADB device information
struct ADBDevice: Identifiable, Hashable {
    let id = UUID()
    let identifier: String
    let status: ADBDeviceStatus
}

/// ADB device status
enum ADBDeviceStatus: String, CaseIterable {
    case device = "device"
    case offline = "offline"
    case unauthorized = "unauthorized"
    case unknown = "unknown"
    
    var description: String {
        switch self {
        case .device:
            return "Connected"
        case .offline:
            return "Offline"
        case .unauthorized:
            return "Unauthorized"
        case .unknown:
            return "Unknown"
        }
    }
}

/// APK installation options
struct APKInstallOptions {
    let replaceExisting: Bool
    let allowDowngrade: Bool
    let grantPermissions: Bool
    
    static let `default` = APKInstallOptions(
        replaceExisting: true,
        allowDowngrade: false,
        grantPermissions: true
    )
    
    static let conservative = APKInstallOptions(
        replaceExisting: false,
        allowDowngrade: false,
        grantPermissions: false
    )
}

/// Installed package information
struct InstalledPackage: Identifiable, Hashable {
    let id = UUID()
    let packageId: String
    let isSystemApp: Bool
}

/// Detailed package information
struct PackageInfo {
    let packageId: String
    let versionName: String
    let versionCode: Int
    let installLocation: String
    let isSystemApp: Bool
}
