//
//  AuroraError.swift
//  APKSplicer
//
//  Created by Aurora Team on 2025-01-27.
//

import Foundation

/// Structured error types for Aurora operations
enum AuroraError: Error, LocalizedError {
    // VM-related errors
    case vmConfigurationInvalid(reason: String)
    case vmBootFailed(underlying: Error)
    case vmNotRunning
    case insufficientResources(required: String, available: String)
    
    // Installation errors
    case xapkParsingFailed(reason: String)
    case apkInstallationFailed(reason: String)
    case adbNotFound
    case adbConnectionFailed
    
    // File system errors
    case diskImageCreationFailed(path: String)
    case insufficientDiskSpace(required: UInt64, available: UInt64)
    
    // Network errors
    case networkingNotAvailable
    case portForwardingFailed(port: Int)
    
    var errorDescription: String? {
        switch self {
        case .vmConfigurationInvalid(let reason):
            return "VM configuration is invalid: \(reason)"
        case .vmBootFailed(let underlying):
            return "VM failed to boot: \(underlying.localizedDescription)"
        case .vmNotRunning:
            return "VM is not currently running"
        case .insufficientResources(let required, let available):
            return "Insufficient system resources. Required: \(required), Available: \(available)"
        case .xapkParsingFailed(let reason):
            return "Failed to parse XAPK file: \(reason)"
        case .apkInstallationFailed(let reason):
            return "APK installation failed: \(reason)"
        case .adbNotFound:
            return "Android Debug Bridge (adb) not found. Please install Android Platform Tools."
        case .adbConnectionFailed:
            return "Could not connect to Android device via ADB"
        case .diskImageCreationFailed(let path):
            return "Failed to create disk image at: \(path)"
        case .insufficientDiskSpace(let required, let available):
            let requiredGB = Double(required) / 1_000_000_000
            let availableGB = Double(available) / 1_000_000_000
            return String(format: "Insufficient disk space. Required: %.1fGB, Available: %.1fGB", requiredGB, availableGB)
        case .networkingNotAvailable:
            return "VM networking is not available"
        case .portForwardingFailed(let port):
            return "Failed to set up port forwarding on port \(port)"
        }
    }
}

/// Result type alias for Aurora operations
typealias AuroraResult<T> = Result<T, AuroraError>
