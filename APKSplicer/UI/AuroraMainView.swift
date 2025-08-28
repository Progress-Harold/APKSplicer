//
//  AuroraMainView.swift
//  APKSplicer
//
//  Created by Aurora Team on 2025-01-27.
//

import SwiftUI
import SwiftData
import UniformTypeIdentifiers

struct AuroraMainView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(JobManager.self) private var jobManager
    @Query private var installedTitles: [InstalledTitle]
    
    @State private var showingInstaller = false
    @State private var showingSettings = false
    @State private var selectedTitle: InstalledTitle?
    @State private var vmManager = VMManager.shared
    
    var body: some View {
        NavigationSplitView {
            // Library sidebar
            LibrarySidebar(
                titles: installedTitles,
                selectedTitle: $selectedTitle,
                onInstall: { showingInstaller = true },
                onSettings: { showingSettings = true }
            )
        } detail: {
            // Main content area
            if let title = selectedTitle {
                TitleDetailView(title: title, vmManager: vmManager)
            } else {
                EmptyLibraryView {
                    showingInstaller = true
                }
            }
        }
        .navigationSplitViewStyle(.balanced)
        .fileImporter(
            isPresented: $showingInstaller,
            allowedContentTypes: [.item],
            allowsMultipleSelection: false
        ) { result in
            handleFileImport(result)
        }
        .sheet(isPresented: $showingSettings) {
            SettingsView()
        }
        .overlay(alignment: .bottomTrailing) {
            // Installation progress overlay
            if !jobManager.activeJobs.isEmpty {
                JobProgressOverlay(jobs: jobManager.activeJobs)
                    .padding()
            }
        }
    }
    
    private func handleFileImport(_ result: Result<[URL], Error>) {
        switch result {
        case .success(let urls):
            guard let url = urls.first else { return }
            
            let profile = PerformanceProfile.medium // Default profile for now
            let job = jobManager.startInstallation(from: url, profile: profile)
            
            Task {
                await performInstallation(job: job)
            }
            
        case .failure(let error):
            print("File import failed: \(error)")
        }
    }
    
    private func performInstallation(job: InstallationJob) async {
        defer {
            jobManager.removeJob(job)
        }
        
        // Simulate installation process for now
        let phases: [InstallationPhase] = [
            .parsing, .extracting, .validating, .preparingVM, .installing, .configuringOBB
        ]
        
        for (index, phase) in phases.enumerated() {
            job.updateProgress(phase: phase, progress: Double(index) / Double(phases.count))
            try? await Task.sleep(nanoseconds: 1_000_000_000) // 1 second delay
        }
        
        // Create mock installed title
        let packageId = "com.example.app"
        let title = InstalledTitle(
            packageId: packageId,
            displayName: job.sourceURL.deletingPathExtension().lastPathComponent,
            version: "1.0",
            diskImagePath: "~/Library/Application Support/Aurora/disks/\(packageId).img",
            profileName: job.profile.name
        )
        
        modelContext.insert(title)
        job.complete()
    }
}

struct LibrarySidebar: View {
    let titles: [InstalledTitle]
    @Binding var selectedTitle: InstalledTitle?
    let onInstall: () -> Void
    let onSettings: () -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Header
            HStack {
                Text("Aurora")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                Spacer()
                Button(action: onSettings) {
                    Image(systemName: "gear")
                }
                .buttonStyle(.plain)
            }
            
            // Library content
            if titles.isEmpty {
                EmptyLibraryPrompt(onInstall: onInstall)
            } else {
                TitlesList(titles: titles, selectedTitle: $selectedTitle)
            }
            
            Spacer()
            
            // Bottom actions
            VStack(spacing: 8) {
                Button("Install XAPK/APK", action: onInstall)
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
                
                HStack {
                    Text("\(titles.count) titles")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Spacer()
                }
            }
        }
        .padding()
        .frame(minWidth: 250)
        .background(.regularMaterial)
    }
}

struct EmptyLibraryPrompt: View {
    let onInstall: () -> Void
    
    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "square.and.arrow.down.on.square")
                .font(.system(size: 48))
                .foregroundStyle(.secondary)
            
            VStack(spacing: 8) {
                Text("No Apps Installed")
                    .font(.headline)
                
                Text("Drag and drop XAPK or APK files to get started")
                    .font(.caption)
                    .multilineTextAlignment(.center)
                    .foregroundStyle(.secondary)
            }
            
            Button("Choose Files", action: onInstall)
                .buttonStyle(.bordered)
        }
        .padding(.vertical, 32)
    }
}

struct TitlesList: View {
    let titles: [InstalledTitle]
    @Binding var selectedTitle: InstalledTitle?
    
    var body: some View {
        List(titles, selection: $selectedTitle) { title in
            TitleRow(title: title)
                .tag(title)
        }
        .listStyle(.sidebar)
    }
}

struct TitleRow: View {
    let title: InstalledTitle
    
    var body: some View {
        HStack {
            // App icon placeholder
            RoundedRectangle(cornerRadius: 8)
                .fill(.blue.gradient)
                .frame(width: 40, height: 40)
                .overlay {
                    Image(systemName: "app")
                        .foregroundStyle(.white)
                }
            
            VStack(alignment: .leading, spacing: 2) {
                Text(title.displayName)
                    .font(.headline)
                    .lineLimit(1)
                
                Text(title.packageId)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            
            Spacer()
            
            if title.isRunning {
                Circle()
                    .fill(.green)
                    .frame(width: 8, height: 8)
            }
        }
        .padding(.vertical, 4)
    }
}

struct EmptyLibraryView: View {
    let onInstall: () -> Void
    
    var body: some View {
        VStack(spacing: 24) {
            Image(systemName: "tray.and.arrow.down")
                .font(.system(size: 64))
                .foregroundStyle(.secondary)
            
            VStack(spacing: 12) {
                Text("Select an App")
                    .font(.title2)
                    .fontWeight(.semibold)
                
                Text("Choose an installed title from the sidebar, or install a new XAPK/APK file to get started.")
                    .font(.body)
                    .multilineTextAlignment(.center)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: 400)
            }
            
            Button("Install XAPK/APK", action: onInstall)
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(.regularMaterial)
    }
}

struct TitleDetailView: View {
    let title: InstalledTitle
    @Bindable var vmManager: VMManager
    
    var body: some View {
        VStack(spacing: 0) {
            // Title header
            TitleHeader(title: title, vmManager: vmManager)
                .padding()
                .background(.regularMaterial)
            
            // VM display area
            VMDisplayView(vmManager: vmManager)
        }
    }
}

struct TitleHeader: View {
    let title: InstalledTitle
    @Bindable var vmManager: VMManager
    
    var body: some View {
        HStack {
            // App info
            VStack(alignment: .leading, spacing: 4) {
                Text(title.displayName)
                    .font(.title2)
                    .fontWeight(.semibold)
                
                Text(title.packageId)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            
            Spacer()
            
            // Controls
            HStack(spacing: 12) {
                if vmManager.isBooting {
                    ProgressView()
                        .scaleEffect(0.8)
                    Text("Booting...")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                } else if vmManager.isRunning && vmManager.currentTitle?.packageId == title.packageId {
                    Button("Stop") {
                        Task {
                            await vmManager.stopVM()
                        }
                    }
                    .buttonStyle(.bordered)
                    
                    Button("Reset") {
                        Task {
                            _ = await vmManager.resetVM()
                        }
                    }
                    .buttonStyle(.bordered)
                } else {
                    Button("Launch") {
                        Task {
                            _ = await vmManager.startVM(for: title, profile: .medium)
                        }
                    }
                    .buttonStyle(.borderedProminent)
                }
            }
        }
    }
}

struct VMDisplayView: View {
    @Bindable var vmManager: VMManager
    
    var body: some View {
        ZStack {
            // VM display placeholder
            Rectangle()
                .fill(.black)
                .overlay {
                    if vmManager.isRunning {
                        Text("Android VM Display\n(Metal rendering will go here)")
                            .foregroundStyle(.white)
                            .multilineTextAlignment(.center)
                    } else {
                        VStack(spacing: 16) {
                            Image(systemName: "display")
                                .font(.system(size: 48))
                                .foregroundStyle(.secondary)
                            
                            Text("VM Not Running")
                                .font(.headline)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

struct JobProgressOverlay: View {
    let jobs: [InstallationJob]
    
    var body: some View {
        VStack(alignment: .trailing, spacing: 8) {
            ForEach(jobs) { job in
                JobProgressCard(job: job)
            }
        }
    }
}

struct JobProgressCard: View {
    @Bindable var job: InstallationJob
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(job.sourceURL.lastPathComponent)
                    .font(.headline)
                    .lineLimit(1)
                Spacer()
                if job.isCompleted {
                    Image(systemName: job.phase == .completed ? "checkmark.circle.fill" : "xmark.circle.fill")
                        .foregroundStyle(job.phase == .completed ? .green : .red)
                }
            }
            
            Text(job.phase.rawValue)
                .font(.caption)
                .foregroundStyle(.secondary)
            
            if !job.isCompleted {
                ProgressView(value: job.progress)
                    .progressViewStyle(.linear)
            }
        }
        .padding()
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))
        .frame(width: 280)
    }
}

struct SettingsView: View {
    var body: some View {
        VStack {
            Text("Settings")
                .font(.title)
                .padding()
            
            Text("Settings panel will be implemented in Epic A-003")
                .foregroundStyle(.secondary)
            
            Spacer()
        }
        .frame(width: 500, height: 400)
    }
}

#Preview {
    AuroraMainView()
        .modelContainer(for: InstalledTitle.self, inMemory: true)
        .environment(JobManager())
}
