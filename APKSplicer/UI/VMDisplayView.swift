//
//  VMDisplayView.swift
//  APKSplicer
//
//  Created by Aurora Team on 2025-01-27.
//

import SwiftUI
import MetalKit

#if canImport(Virtualization)
import Virtualization
#endif

/// Metal-backed view for displaying VM graphics output
struct VMDisplayView: View {
    @Bindable var vmManager: VMManager
    @State private var metalView = AuroraMetalView()
    
    var body: some View {
        ZStack {
            // Metal rendering view
            MetalDisplayView(metalView: metalView, vmManager: vmManager)
                .background(.black)
            
            // Overlay UI
            if !vmManager.isRunning {
                VMNotRunningOverlay()
            } else if vmManager.isBooting {
                VMBootingOverlay()
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .onAppear {
            vmManager.setDisplayView(metalView)
        }
    }
}

/// Metal view wrapper for SwiftUI
struct MetalDisplayView: NSViewRepresentable {
    let metalView: AuroraMetalView
    let vmManager: VMManager
    
    func makeNSView(context: Context) -> AuroraMetalView {
        return metalView
    }
    
    func updateNSView(_ nsView: AuroraMetalView, context: Context) {
        // Update view if needed
    }
}

/// Custom MTKView for VM display
class AuroraMetalView: MTKView {
    #if canImport(Virtualization)
    private var displayAttachment: Any?  // Would be VZGraphicsDisplayConfiguration
    #endif
    
    override init(frame frameRect: CGRect, device: MTLDevice?) {
        super.init(frame: frameRect, device: device ?? MTLCreateSystemDefaultDevice())
        setupMetal()
    }
    
    required init(coder: NSCoder) {
        super.init(coder: coder)
        setupMetal()
    }
    
    private func setupMetal() {
        // Configure Metal view
        self.preferredFramesPerSecond = 60
        self.enableSetNeedsDisplay = false
        self.autoResizeDrawable = true
        
        // Set clear color to black
        self.clearColor = MTLClearColorMake(0.0, 0.0, 0.0, 1.0)
        
        // Enable depth testing if needed
        self.depthStencilPixelFormat = .depth32Float
    }
    
    #if canImport(Virtualization)
    /// Configure this view to receive VM graphics output
    func configureForVM(width: Int, height: Int) {
        // This would be called when setting up the VM
        // The actual implementation depends on how VZ exposes the graphics surface
        print("Configuring Metal view for VM display: \(width)x\(height)")
    }
    #endif
    
    override func draw(_ rect: CGRect) {
        super.draw(rect)
        
        // Custom drawing logic would go here
        // For now, we'll let the clear color handle it
    }
}

/// Overlay shown when VM is not running
struct VMNotRunningOverlay: View {
    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "display")
                .font(.system(size: 48))
                .foregroundStyle(.secondary)
            
            VStack(spacing: 8) {
                Text("Android VM Not Running")
                    .font(.headline)
                    .foregroundStyle(.primary)
                
                Text("Launch a title to start the Android virtual machine")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
        }
        .frame(maxWidth: 300)
    }
}

/// Overlay shown during VM boot
struct VMBootingOverlay: View {
    var body: some View {
        VStack(spacing: 16) {
            ProgressView()
                .scaleEffect(1.2)
            
            VStack(spacing: 8) {
                Text("Booting Android VM")
                    .font(.headline)
                    .foregroundStyle(.primary)
                
                Text("Starting virtualization and loading Android kernel...")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
        }
        .frame(maxWidth: 300)
        .padding()
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))
    }
}

#Preview {
    VMDisplayView(vmManager: VMManager.shared)
        .frame(width: 800, height: 600)
}
