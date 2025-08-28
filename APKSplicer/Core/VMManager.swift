//
//  VMManager.swift
//  APKSplicer
//
//  Created by Aurora Team on 2025-01-27.
//

import Foundation
import Combine
import os.log

// Temporarily conditionally import Virtualization to allow building without entitlements
#if canImport(Virtualization)
import Virtualization
#endif

/// Manages virtual machine lifecycle and configuration
@Observable
final class VMManager {
    static let shared = VMManager()
    
    // MARK: - Properties
    
    #if canImport(Virtualization)
    private var virtualMachine: VZVirtualMachine?
    #endif
    private var vmConfiguration: VMConfiguration?
    private var displayView: AuroraMetalView?
    private let logger = Logger(subsystem: "com.aurora.apksplicer", category: "VMManager")
    
    private(set) var isRunning = false
    private(set) var isBooting = false
    private(set) var currentTitle: InstalledTitle?
    
    // MARK: - Initialization
    
    private init() {
        setupApplicationSupportDirectory()
    }
    
    // MARK: - Public Interface
    
    /// Set the Metal display view for VM output
    func setDisplayView(_ view: AuroraMetalView) {
        self.displayView = view
        logger.info("Display view configured for VM output")
    }
    
    /// Create and start a VM for the specified title
    func startVM(for title: InstalledTitle, profile: PerformanceProfile) async -> AuroraResult<Void> {
        logger.info("Starting VM for title: \(title.packageId)")
        
        #if canImport(Virtualization)
        // Validate profile
        switch profile.validate() {
        case .failure(let error):
            return .failure(error)
        case .success:
            break
        }
        
        // Stop existing VM if running
        if isRunning {
            await stopVM()
        }
        
        isBooting = true
        defer { isBooting = false }
        
        do {
            // Create VM configuration
            let config = try await createVMConfiguration(profile: profile, diskImagePath: URL(fileURLWithPath: title.diskImagePath))
            
            // Create VM instance
            let vm = VZVirtualMachine(configuration: config.vzConfiguration)
            
            // Start VM
            try await vm.start()
            
            // Update state
            self.virtualMachine = vm
            self.vmConfiguration = VMConfiguration(
                profile: profile,
                diskImagePath: URL(fileURLWithPath: title.diskImagePath),
                kernelPath: nil, // Will be set when we have Android kernel
                initrdPath: nil,
                enableNetworking: true,
                adbPortForwarding: true
            )
            self.currentTitle = title
            self.isRunning = true
            
            logger.info("VM started successfully for title: \(title.packageId)")
            return .success(())
            
        } catch {
            logger.error("Failed to start VM: \(error.localizedDescription)")
            return .failure(.vmBootFailed(underlying: error))
        }
        #else
        // Mock implementation for development without entitlements
        logger.info("Mock VM start for title: \(title.packageId) (Virtualization framework not available)")
        
        isBooting = true
        
        // Simulate boot delay
        try? await Task.sleep(nanoseconds: 2_000_000_000) // 2 seconds
        
        // Update state
        self.vmConfiguration = VMConfiguration(
            profile: profile,
            diskImagePath: URL(fileURLWithPath: title.diskImagePath),
            kernelPath: nil,
            initrdPath: nil,
            enableNetworking: true,
            adbPortForwarding: true
        )
        self.currentTitle = title
        self.isRunning = true
        self.isBooting = false
        
        logger.info("Mock VM started for title: \(title.packageId)")
        return .success(())
        #endif
    }
    
    /// Stop the currently running VM
    func stopVM() async {
        #if canImport(Virtualization)
        guard let vm = virtualMachine, isRunning else { return }
        
        logger.info("Stopping VM...")
        
        do {
            try await vm.stop()
            cleanup()
            logger.info("VM stopped successfully")
        } catch {
            logger.error("Error stopping VM: \(error.localizedDescription)")
            cleanup()
        }
        #else
        // Mock implementation
        guard isRunning else { return }
        
        logger.info("Mock VM stop")
        cleanup()
        #endif
    }
    
    /// Reset the VM to a clean state
    func resetVM() async -> AuroraResult<Void> {
        guard currentTitle != nil else {
            return .failure(.vmNotRunning)
        }
        
        await stopVM()
        
        // TODO: Restore from clean disk snapshot
        // For now, we'll just prepare for restart
        
        return .success(())
    }
    
    // MARK: - Private Methods
    
    private func cleanup() {
        #if canImport(Virtualization)
        virtualMachine = nil
        #endif
        vmConfiguration = nil
        currentTitle = nil
        isRunning = false
    }
    
    private func setupApplicationSupportDirectory() {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let auroraDir = appSupport.appendingPathComponent("Aurora")
        
        let directories = [
            auroraDir.appendingPathComponent("disks"),
            auroraDir.appendingPathComponent("profiles"),
            auroraDir.appendingPathComponent("cache"),
            auroraDir.appendingPathComponent("logs")
        ]
        
        for directory in directories {
            try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        }
    }
    
    #if canImport(Virtualization)
    private func createVMConfiguration(profile: PerformanceProfile, diskImagePath: URL) async throws -> VZConfiguration {
        let config = VZVirtualMachineConfiguration()
        
        // CPU configuration
        config.cpuCount = profile.cpuCount
        
        // Memory configuration
        config.memorySize = UInt64(profile.memoryMB) * 1_048_576 // Convert to bytes
        
        // Platform configuration (required for ARM64)
        let platform = VZGenericPlatformConfiguration()
        config.platform = platform
        
        // Boot loader configuration with Android kernel
        let kernelURL = getAndroidKernelURL()
        let bootLoader = VZLinuxBootLoader(kernelURL: kernelURL)
        
        // Set Android-specific boot arguments
        bootLoader.commandLine = "androidboot.hardware=android_x86_64 androidboot.console=ttyS0 quiet"
        
        // Check for initrd
        let initrdURL = kernelURL.deletingLastPathComponent().appendingPathComponent("android-initrd.img")
        if FileManager.default.fileExists(atPath: initrdURL.path) {
            bootLoader.initialRamdiskURL = initrdURL
        }
        
        config.bootLoader = bootLoader
        
        // Storage configuration
        try await setupStorageDevices(config: config, diskImagePath: diskImagePath, profile: profile)
        
        // Graphics configuration
        setupGraphicsDevices(config: config, display: profile.display)
        
        // Network configuration
        if vmConfiguration?.enableNetworking ?? true {
            setupNetworkDevices(config: config)
        }
        
        // Audio configuration
        setupAudioDevices(config: config)
        
        // Validate configuration
        try config.validate()
        
        return VZConfiguration(vzConfig: config)
    }
    #endif
    
    private func getAndroidKernelURL() -> URL {
        // Check for kernel in project Images directory first (development)
        let projectRoot = getProjectRoot()
        let projectKernel = projectRoot.appendingPathComponent("Images/kernels/android-kernel")
        
        if FileManager.default.fileExists(atPath: projectKernel.path) {
            return projectKernel
        }
        
        // Fallback to app support directory
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        return appSupport.appendingPathComponent("Aurora/kernels/android-kernel")
    }
    
    private func getProjectRoot() -> URL {
        // Find project root by looking for APKSplicer.xcodeproj
        var current = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
        
        while current.path != "/" {
            let xcodeproj = current.appendingPathComponent("APKSplicer.xcodeproj")
            if FileManager.default.fileExists(atPath: xcodeproj.path) {
                return current
            }
            current = current.deletingLastPathComponent()
        }
        
        // Fallback to current directory
        return URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
    }
    
    private func setupStorageDevices(config: VZVirtualMachineConfiguration, diskImagePath: URL, profile: PerformanceProfile) async throws {
        // Create disk image if it doesn't exist
        if !FileManager.default.fileExists(atPath: diskImagePath.path) {
            try createDiskImage(at: diskImagePath, sizeGB: profile.diskGB)
        }
        
        // Create storage device attachment
        guard let diskAttachment = try? VZDiskImageStorageDeviceAttachment(url: diskImagePath, readOnly: false) else {
            throw AuroraError.diskImageCreationFailed(path: diskImagePath.path)
        }
        
        // Create virtio block device
        let storageDevice = VZVirtioBlockDeviceConfiguration(attachment: diskAttachment)
        config.storageDevices = [storageDevice]
    }
    
    private func createDiskImage(at url: URL, sizeGB: Int) throws {
        let sizeBytes = Int64(sizeGB) * 1_073_741_824 // Convert GB to bytes
        
        // Create parent directory if needed
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        
        // Create sparse disk image
        let fd = open(url.path, O_CREAT | O_TRUNC | O_WRONLY, 0644)
        guard fd != -1 else {
            throw AuroraError.diskImageCreationFailed(path: url.path)
        }
        
        defer { close(fd) }
        
        // Use ftruncate to create sparse file
        guard ftruncate(fd, sizeBytes) == 0 else {
            throw AuroraError.diskImageCreationFailed(path: url.path)
        }
    }
    
    private func setupGraphicsDevices(config: VZVirtualMachineConfiguration, display: DisplayConfiguration) {
        let graphicsDevice = VZVirtioGraphicsDeviceConfiguration()
        graphicsDevice.scanouts = [
            VZVirtioGraphicsScanoutConfiguration(
                widthInPixels: display.width,
                heightInPixels: display.height
            )
        ]
        config.graphicsDevices = [graphicsDevice]
    }
    
    private func setupNetworkDevices(config: VZVirtualMachineConfiguration) {
        let networkDevice = VZVirtioNetworkDeviceConfiguration()
        networkDevice.attachment = VZNATNetworkDeviceAttachment()
        config.networkDevices = [networkDevice]
    }
    
    private func setupAudioDevices(config: VZVirtualMachineConfiguration) {
        let audioDevice = VZVirtioSoundDeviceConfiguration()
        let inputStream = VZVirtioSoundDeviceInputStreamConfiguration()
        inputStream.source = VZHostAudioInputStreamSource()
        let outputStream = VZVirtioSoundDeviceOutputStreamConfiguration()
        outputStream.sink = VZHostAudioOutputStreamSink()
        audioDevice.streams = [inputStream, outputStream]
        config.audioDevices = [audioDevice]
    }
}

// MARK: - Supporting Types

#if canImport(Virtualization)
/// Wrapper around VZVirtualMachineConfiguration for type safety
struct VZConfiguration {
    let vzConfig: VZVirtualMachineConfiguration
    
    var vzConfiguration: VZVirtualMachineConfiguration {
        vzConfig
    }
}
#endif
