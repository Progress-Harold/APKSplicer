//
//  XAPKInstaller.swift
//  APKSplicer
//
//  Created by Aurora Team on 2025-01-27.
//

import Foundation
import Compression
import os.log

/// Handles parsing and installation of XAPK and APK files
@Observable
final class XAPKInstaller {
    static let shared = XAPKInstaller()
    
    // MARK: - Properties
    
    private let logger = Logger(subsystem: "com.aurora.apksplicer", category: "XAPKInstaller")
    private let adbBridge = ADBBridge.shared
    private let fileManager = FileManager.default
    
    // MARK: - Public Interface
    
    /// Install an XAPK or APK file
    func installPackage(from url: URL, job: InstallationJob) async -> AuroraResult<InstalledApp> {
        logger.info("Starting installation: \(url.lastPathComponent)")
        
        // Update job status
        job.updateProgress(phase: .parsing, progress: 0.1)
        
        // Determine file type and install accordingly
        let fileExtension = url.pathExtension.lowercased()
        
        switch fileExtension {
        case "xapk":
            return await installXAPK(from: url, job: job)
        case "apk":
            return await installAPK(from: url, job: job)
        default:
            job.fail(with: .xapkParsingFailed(reason: "Unsupported file type: \(fileExtension)"))
            return .failure(.xapkParsingFailed(reason: "Unsupported file type: \(fileExtension)"))
        }
    }
    
    // MARK: - XAPK Installation
    
    private func installXAPK(from url: URL, job: InstallationJob) async -> AuroraResult<InstalledApp> {
        logger.info("Installing XAPK: \(url.lastPathComponent)")
        
        // Create temporary directory
        let tempDir = createTemporaryDirectory()
        defer { cleanupTemporaryDirectory(tempDir) }
        
        do {
            // Parse XAPK
            job.updateProgress(phase: .extracting, progress: 0.2)
            let xapkInfo = try await parseXAPK(url: url, tempDir: tempDir)
            
            // Validate and select APKs
            job.updateProgress(phase: .validating, progress: 0.4)
            let selectedAPKs = try selectCompatibleAPKs(from: xapkInfo.apkFiles)
            
            // Prepare VM (ensure Android is ready)
            job.updateProgress(phase: .preparingVM, progress: 0.5)
            switch await adbBridge.waitForDevice() {
            case .failure(let error):
                job.fail(with: error)
                return .failure(error)
            case .success:
                break
            }
            
            // Install APKs
            job.updateProgress(phase: .installing, progress: 0.6)
            switch await adbBridge.installMultipleAPKs(at: selectedAPKs) {
            case .failure(let error):
                job.fail(with: error)
                return .failure(error)
            case .success:
                break
            }
            
            // Install OBB files if present
            job.updateProgress(phase: .configuringOBB, progress: 0.8)
            if !xapkInfo.obbFiles.isEmpty {
                switch await installOBBFiles(xapkInfo.obbFiles, packageId: xapkInfo.packageId) {
                case .failure(let error):
                    logger.warning("OBB installation failed: \(error)")
                    // Continue anyway - some apps work without OBB
                case .success:
                    break
                }
            }
            
            // Create installed app record
            let installedApp = InstalledApp(
                packageId: xapkInfo.packageId,
                displayName: xapkInfo.appName ?? url.deletingPathExtension().lastPathComponent,
                version: xapkInfo.versionName ?? "Unknown",
                iconData: xapkInfo.iconData
            )
            
            job.updateProgress(phase: .completed, progress: 1.0)
            logger.info("XAPK installation completed: \(xapkInfo.packageId)")
            
            return .success(installedApp)
            
        } catch {
            let auroraError = error as? AuroraError ?? .xapkParsingFailed(reason: error.localizedDescription)
            job.fail(with: auroraError)
            return .failure(auroraError)
        }
    }
    
    // MARK: - APK Installation
    
    private func installAPK(from url: URL, job: InstallationJob) async -> AuroraResult<InstalledApp> {
        logger.info("Installing APK: \(url.lastPathComponent)")
        
        do {
            // Parse APK metadata
            job.updateProgress(phase: .parsing, progress: 0.2)
            let apkInfo = try await parseAPK(url: url)
            
            // Prepare VM
            job.updateProgress(phase: .preparingVM, progress: 0.4)
            switch await adbBridge.waitForDevice() {
            case .failure(let error):
                job.fail(with: error)
                return .failure(error)
            case .success:
                break
            }
            
            // Install APK
            job.updateProgress(phase: .installing, progress: 0.6)
            switch await adbBridge.installAPK(at: url) {
            case .failure(let error):
                job.fail(with: error)
                return .failure(error)
            case .success:
                break
            }
            
            // Create installed app record
            let installedApp = InstalledApp(
                packageId: apkInfo.packageId,
                displayName: apkInfo.appName ?? url.deletingPathExtension().lastPathComponent,
                version: apkInfo.versionName ?? "Unknown",
                iconData: apkInfo.iconData
            )
            
            job.updateProgress(phase: .completed, progress: 1.0)
            logger.info("APK installation completed: \(apkInfo.packageId)")
            
            return .success(installedApp)
            
        } catch {
            let auroraError = error as? AuroraError ?? .apkInstallationFailed(reason: error.localizedDescription)
            job.fail(with: auroraError)
            return .failure(auroraError)
        }
    }
    
    // MARK: - XAPK Parsing
    
    private func parseXAPK(url: URL, tempDir: URL) async throws -> XAPKInfo {
        logger.info("Parsing XAPK file")
        
        // Extract XAPK (ZIP) contents
        try await extractZIP(from: url, to: tempDir)
        
        // Parse manifest.json
        let manifestURL = tempDir.appendingPathComponent("manifest.json")
        guard fileManager.fileExists(atPath: manifestURL.path) else {
            throw AuroraError.xapkParsingFailed(reason: "manifest.json not found in XAPK")
        }
        
        let manifestData = try Data(contentsOf: manifestURL)
        let manifest = try JSONDecoder().decode(XAPKManifest.self, from: manifestData)
        
        // Find APK files
        let apkFiles = try findAPKFiles(in: tempDir)
        guard !apkFiles.isEmpty else {
            throw AuroraError.xapkParsingFailed(reason: "No APK files found in XAPK")
        }
        
        // Find OBB files
        let obbFiles = try findOBBFiles(in: tempDir)
        
        // Extract icon if available
        let iconData = extractIcon(from: tempDir)
        
        return XAPKInfo(
            packageId: manifest.packageName,
            appName: manifest.name,
            versionName: manifest.versionName,
            versionCode: manifest.versionCode,
            apkFiles: apkFiles,
            obbFiles: obbFiles,
            iconData: iconData
        )
    }
    
    // MARK: - APK Parsing
    
    private func parseAPK(url: URL) async throws -> APKInfo {
        logger.info("Parsing APK file")
        
        // For now, we'll use a simplified approach
        // In a full implementation, you'd use aapt or a proper APK parser
        
        let fileName = url.deletingPathExtension().lastPathComponent
        
        // Try to extract basic info using a simple heuristic
        // This would be replaced with proper APK parsing
        let packageId = "com.unknown.\(fileName.lowercased())"
        
        return APKInfo(
            packageId: packageId,
            appName: fileName,
            versionName: "1.0",
            versionCode: 1,
            iconData: nil
        )
    }
    
    // MARK: - File Operations
    
    private func extractZIP(from source: URL, to destination: URL) async throws {
        logger.info("Extracting ZIP file")
        
        // Create destination directory
        try fileManager.createDirectory(at: destination, withIntermediateDirectories: true)
        
        // Use async process execution to avoid hanging
        return try await withCheckedThrowingContinuation { continuation in
            let process = Process()
            let outputPipe = Pipe()
            let errorPipe = Pipe()
            
            process.executableURL = URL(fileURLWithPath: "/usr/bin/unzip")
            process.arguments = ["-q", "-o", source.path, "-d", destination.path]
            process.standardOutput = outputPipe
            process.standardError = errorPipe
            
            process.terminationHandler = { _ in
                let errorData = errorPipe.fileHandleForReading.readDataToEndOfFile()
                let errorMessage = String(data: errorData, encoding: .utf8) ?? ""
                
                if process.terminationStatus == 0 {
                    self.logger.info("ZIP extraction completed successfully")
                    continuation.resume()
                } else {
                    self.logger.error("ZIP extraction failed with status \(process.terminationStatus): \(errorMessage)")
                    continuation.resume(throwing: AuroraError.xapkParsingFailed(reason: "Failed to extract XAPK: \(errorMessage)"))
                }
            }
            
            do {
                try process.run()
            } catch {
                self.logger.error("Failed to start unzip process: \(error.localizedDescription)")
                continuation.resume(throwing: AuroraError.xapkParsingFailed(reason: "Failed to start unzip: \(error.localizedDescription)"))
            }
        }
    }
    
    private func findAPKFiles(in directory: URL) throws -> [URL] {
        let contents = try fileManager.contentsOfDirectory(at: directory, includingPropertiesForKeys: nil)
        return contents.filter { $0.pathExtension.lowercased() == "apk" }
    }
    
    private func findOBBFiles(in directory: URL) throws -> [OBBFile] {
        var obbFiles: [OBBFile] = []
        
        // Look for Android/obb directory structure
        let androidDir = directory.appendingPathComponent("Android")
        let obbDir = androidDir.appendingPathComponent("obb")
        
        if fileManager.fileExists(atPath: obbDir.path) {
            let contents = try fileManager.contentsOfDirectory(at: obbDir, includingPropertiesForKeys: nil, options: .skipsHiddenFiles)
            
            for item in contents {
                if item.hasDirectoryPath {
                    // Package-specific OBB directory
                    let packageOBBs = try fileManager.contentsOfDirectory(at: item, includingPropertiesForKeys: nil)
                    
                    for obbFile in packageOBBs where obbFile.pathExtension.lowercased() == "obb" {
                        obbFiles.append(OBBFile(
                            localPath: obbFile,
                            packageId: item.lastPathComponent,
                            fileName: obbFile.lastPathComponent
                        ))
                    }
                }
            }
        }
        
        return obbFiles
    }
    
    private func extractIcon(from directory: URL) -> Data? {
        // Look for common icon files
        let iconNames = ["icon.png", "app_icon.png", "launcher_icon.png"]
        
        for iconName in iconNames {
            let iconURL = directory.appendingPathComponent(iconName)
            if fileManager.fileExists(atPath: iconURL.path) {
                return try? Data(contentsOf: iconURL)
            }
        }
        
        return nil
    }
    
    private func selectCompatibleAPKs(from apkFiles: [URL]) throws -> [URL] {
        // For now, include all APKs
        // In production, you'd filter by architecture, DPI, language, etc.
        
        // Ensure we have a base APK
        let baseAPK = apkFiles.first { url in
            let name = url.lastPathComponent.lowercased()
            return name.contains("base") || !name.contains("split")
        }
        
        guard baseAPK != nil else {
            throw AuroraError.xapkParsingFailed(reason: "No base APK found")
        }
        
        return apkFiles.sorted { $0.lastPathComponent < $1.lastPathComponent }
    }
    
    private func installOBBFiles(_ obbFiles: [OBBFile], packageId: String) async -> AuroraResult<Void> {
        logger.info("Installing \(obbFiles.count) OBB files for \(packageId)")
        
        for obbFile in obbFiles {
            let remotePath = "/sdcard/Android/obb/\(packageId)/\(obbFile.fileName)"
            
            // Create OBB directory
            switch await adbBridge.executeShellCommand("mkdir -p /sdcard/Android/obb/\(packageId)") {
            case .failure(let error):
                return .failure(error)
            case .success:
                break
            }
            
            // Push OBB file
            switch await adbBridge.pushFile(from: obbFile.localPath, to: remotePath) {
            case .failure(let error):
                return .failure(error)
            case .success:
                break
            }
        }
        
        return .success(())
    }
    
    // MARK: - Utilities
    
    private func createTemporaryDirectory() -> URL {
        let tempDir = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("Aurora-\(UUID().uuidString)")
        
        try? fileManager.createDirectory(at: tempDir, withIntermediateDirectories: true)
        return tempDir
    }
    
    private func cleanupTemporaryDirectory(_ tempDir: URL) {
        try? fileManager.removeItem(at: tempDir)
    }
    

    
    // MARK: - Uninstallation & Management
    
    /// Uninstall an installed package
    func uninstallPackage(packageId: String, keepData: Bool = false) async -> AuroraResult<Void> {
        logger.info("Uninstalling package: \(packageId)")
        
        // Use ADB bridge to uninstall the package
        return await adbBridge.uninstallAPK(packageId: packageId, keepData: keepData)
    }
    
    /// Clear package data without uninstalling
    func clearPackageData(packageId: String) async -> AuroraResult<Void> {
        logger.info("Clearing data for package: \(packageId)")
        
        return await adbBridge.clearPackageData(packageId: packageId)
    }
    
    /// Get list of installed packages
    func getInstalledPackages(includeSystem: Bool = false) async -> AuroraResult<[InstalledPackage]> {
        logger.info("Getting installed packages list")
        
        return await adbBridge.listInstalledPackages(includeSystem: includeSystem)
    }
}

// MARK: - Supporting Types

/// XAPK manifest structure
struct XAPKManifest: Codable {
    let packageName: String
    let name: String?
    let versionName: String?
    let versionCode: Int?
    
    enum CodingKeys: String, CodingKey {
        case packageName = "package_name"
        case name
        case versionName = "version_name"
        case versionCode = "version_code"
    }
}

/// Parsed XAPK information
struct XAPKInfo {
    let packageId: String
    let appName: String?
    let versionName: String?
    let versionCode: Int?
    let apkFiles: [URL]
    let obbFiles: [OBBFile]
    let iconData: Data?
}

/// Parsed APK information
struct APKInfo {
    let packageId: String
    let appName: String?
    let versionName: String?
    let versionCode: Int?
    let iconData: Data?
}

/// OBB file information
struct OBBFile {
    let localPath: URL
    let packageId: String
    let fileName: String
}

/// Installed application information
struct InstalledApp {
    let packageId: String
    let displayName: String
    let version: String
    let iconData: Data?
    let installDate = Date()
}
