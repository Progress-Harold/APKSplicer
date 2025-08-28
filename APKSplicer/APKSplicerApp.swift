//
//  APKSplicerApp.swift
//  APKSplicer - Aurora Android XAPK Player
//
//  Created by Harold Davis on 8/27/25.
//

import SwiftUI
import SwiftData

@main
struct APKSplicerApp: App {
    var sharedModelContainer: ModelContainer = {
        let schema = Schema([
            InstalledTitle.self,
        ])
        let modelConfiguration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)

        do {
            return try ModelContainer(for: schema, configurations: [modelConfiguration])
        } catch {
            fatalError("Could not create ModelContainer: \(error)")
        }
    }()
    
    @State private var jobManager = JobManager()

    var body: some Scene {
        WindowGroup {
            AuroraMainView()
                .environment(jobManager)
        }
        .modelContainer(sharedModelContainer)
        .windowResizability(.contentSize)
        .windowStyle(.titleBar)
    }
}
