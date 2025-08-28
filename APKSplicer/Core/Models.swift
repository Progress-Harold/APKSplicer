//
//  Models.swift
//  APKSplicer
//
//  Created by Aurora Team on 2025-01-27.
//

import Foundation
import SwiftData

/// Display configuration for VM
struct DisplayConfiguration: Codable, Hashable {
    let width: Int
    let height: Int
    let refreshRate: Int
    let dpi: Int?
    
    static let preset720p = DisplayConfiguration(width: 1280, height: 720, refreshRate: 60, dpi: 240)
    static let preset1080p = DisplayConfiguration(width: 1920, height: 1080, refreshRate: 60, dpi: 320)
    static let preset1440p = DisplayConfiguration(width: 2560, height: 1440, refreshRate: 60, dpi: 400)
}

/// Performance profile for VM resource allocation
struct PerformanceProfile: Codable, Hashable, Identifiable {
    let id = UUID()
    let name: String
    let cpuCount: Int
    let memoryMB: Int
    let diskGB: Int
    let display: DisplayConfiguration
    let thermalStepdown: Bool
    let abiPreference: String
    
    static let low = PerformanceProfile(
        name: "Low",
        cpuCount: 2,
        memoryMB: 3072,
        diskGB: 8,
        display: .preset720p,
        thermalStepdown: true,
        abiPreference: "arm64-v8a"
    )
    
    static let medium = PerformanceProfile(
        name: "Medium",
        cpuCount: 4,
        memoryMB: 6144,
        diskGB: 16,
        display: .preset1080p,
        thermalStepdown: true,
        abiPreference: "arm64-v8a"
    )
    
    static let high = PerformanceProfile(
        name: "High",
        cpuCount: 8,
        memoryMB: 12288,
        diskGB: 32,
        display: .preset1440p,
        thermalStepdown: true,
        abiPreference: "arm64-v8a"
    )
    
    /// Validate profile against system capabilities
    func validate() -> AuroraResult<Void> {
        let physicalMemory = ProcessInfo.processInfo.physicalMemory
        let availableMemoryMB = Int(physicalMemory / 1_048_576) // Convert to MB
        
        if memoryMB > availableMemoryMB * 8 / 10 { // Don't use more than 80% of system RAM
            return .failure(.insufficientResources(
                required: "\(memoryMB)MB RAM",
                available: "\(availableMemoryMB)MB RAM"
            ))
        }
        
        let cpuCount = ProcessInfo.processInfo.processorCount
        if self.cpuCount > cpuCount {
            return .failure(.insufficientResources(
                required: "\(self.cpuCount) CPU cores",
                available: "\(cpuCount) CPU cores"
            ))
        }
        
        return .success(())
    }
}

/// VM configuration combining profile with runtime settings
struct VMConfiguration: Codable {
    let profile: PerformanceProfile
    let diskImagePath: URL
    let kernelPath: URL?
    let initrdPath: URL?
    let enableNetworking: Bool
    let adbPortForwarding: Bool
    
    var memorySize: UInt64 {
        UInt64(profile.memoryMB) * 1_048_576 // Convert to bytes
    }
}

/// Installed Android application metadata
@Model
final class InstalledTitle {
    @Attribute(.unique) var packageId: String
    var displayName: String
    var version: String
    var installDate: Date
    var lastPlayed: Date?
    var iconPath: String?
    var diskImagePath: String
    var profileName: String
    var isRunning: Bool
    
    init(packageId: String, displayName: String, version: String, diskImagePath: String, profileName: String) {
        self.packageId = packageId
        self.displayName = displayName
        self.version = version
        self.installDate = Date()
        self.diskImagePath = diskImagePath
        self.profileName = profileName
        self.isRunning = false
    }
}

/// Installation job status tracking
enum InstallationPhase: String, CaseIterable {
    case parsing = "Parsing XAPK"
    case extracting = "Extracting files"
    case validating = "Validating APKs"
    case preparingVM = "Preparing VM"
    case installing = "Installing to Android"
    case configuringOBB = "Configuring OBB files"
    case completed = "Installation complete"
    case failed = "Installation failed"
}

/// Job management for async operations
@Observable
final class JobManager {
    private(set) var activeJobs: [InstallationJob] = []
    
    func startInstallation(from url: URL, profile: PerformanceProfile) -> InstallationJob {
        let job = InstallationJob(sourceURL: url, profile: profile)
        activeJobs.append(job)
        return job
    }
    
    func removeJob(_ job: InstallationJob) {
        activeJobs.removeAll { $0.id == job.id }
    }
}

/// Individual installation job
@Observable
final class InstallationJob: Identifiable {
    let id = UUID()
    let sourceURL: URL
    let profile: PerformanceProfile
    let startTime = Date()
    
    private(set) var phase: InstallationPhase = .parsing
    private(set) var progress: Double = 0.0
    private(set) var error: AuroraError?
    
    var isCompleted: Bool {
        phase == .completed || phase == .failed
    }
    
    init(sourceURL: URL, profile: PerformanceProfile) {
        self.sourceURL = sourceURL
        self.profile = profile
    }
    
    func updateProgress(phase: InstallationPhase, progress: Double) {
        self.phase = phase
        self.progress = progress
    }
    
    func fail(with error: AuroraError) {
        self.phase = .failed
        self.error = error
    }
    
    func complete() {
        self.phase = .completed
        self.progress = 1.0
    }
}
