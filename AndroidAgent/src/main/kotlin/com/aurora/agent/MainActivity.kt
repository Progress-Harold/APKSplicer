package com.aurora.agent

import android.accessibilityservice.AccessibilityServiceInfo
import android.content.Context
import android.content.Intent
import android.os.Bundle
import android.provider.Settings
import android.view.accessibility.AccessibilityManager
import androidx.appcompat.app.AppCompatActivity
import android.widget.Button
import android.widget.TextView
import android.widget.Toast

/**
 * Main activity for Aurora Agent
 * Provides setup interface for accessibility service and communication
 */
class MainActivity : AppCompatActivity() {
    
    private lateinit var statusText: TextView
    private lateinit var enableButton: Button
    private lateinit var testButton: Button
    
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        setContentView(R.layout.activity_main)
        
        setupViews()
        updateStatus()
    }
    
    override fun onResume() {
        super.onResume()
        updateStatus()
    }
    
    private fun setupViews() {
        statusText = findViewById(R.id.statusText)
        enableButton = findViewById(R.id.enableButton)
        testButton = findViewById(R.id.testButton)
        
        enableButton.setOnClickListener {
            openAccessibilitySettings()
        }
        
        testButton.setOnClickListener {
            testInputInjection()
        }
    }
    
    private fun updateStatus() {
        val isServiceEnabled = isAccessibilityServiceEnabled()
        val isCommunicationRunning = CommunicationService.isRunning
        
        val status = buildString {
            appendLine("Aurora Agent Status")
            appendLine("================")
            appendLine("Accessibility Service: ${if (isServiceEnabled) "✓ Enabled" else "✗ Disabled"}")
            appendLine("Communication Service: ${if (isCommunicationRunning) "✓ Running" else "✗ Stopped"}")
            appendLine()
            
            if (isServiceEnabled && isCommunicationRunning) {
                appendLine("🟢 Ready for Aurora commands")
            } else {
                appendLine("🔴 Setup required")
                if (!isServiceEnabled) {
                    appendLine("• Enable Accessibility Service")
                }
                if (!isCommunicationRunning) {
                    appendLine("• Communication service not running")
                }
            }
        }
        
        statusText.text = status
        enableButton.text = if (isServiceEnabled) "Accessibility Settings" else "Enable Accessibility"
        testButton.isEnabled = isServiceEnabled
        
        // Start communication service if accessibility is enabled
        if (isServiceEnabled && !isCommunicationRunning) {
            startCommunicationService()
        }
    }
    
    private fun isAccessibilityServiceEnabled(): Boolean {
        val accessibilityManager = getSystemService(Context.ACCESSIBILITY_SERVICE) as AccessibilityManager
        val enabledServices = accessibilityManager.getEnabledAccessibilityServiceList(AccessibilityServiceInfo.FEEDBACK_ALL_MASK)
        
        return enabledServices.any { service ->
            service.resolveInfo.serviceInfo.packageName == packageName &&
            service.resolveInfo.serviceInfo.name == InputService::class.java.name
        }
    }
    
    private fun openAccessibilitySettings() {
        val intent = Intent(Settings.ACTION_ACCESSIBILITY_SETTINGS)
        startActivity(intent)
        
        Toast.makeText(this, "Find 'Aurora Agent' and enable it", Toast.LENGTH_LONG).show()
    }
    
    private fun testInputInjection() {
        if (isAccessibilityServiceEnabled()) {
            // Send test command to InputService
            val intent = Intent(this, InputService::class.java)
            intent.action = "TEST_TAP"
            intent.putExtra("x", 500)
            intent.putExtra("y", 500)
            
            Toast.makeText(this, "Test tap sent to center of screen", Toast.LENGTH_SHORT).show()
        } else {
            Toast.makeText(this, "Accessibility service not enabled", Toast.LENGTH_SHORT).show()
        }
    }
    
    private fun startCommunicationService() {
        val intent = Intent(this, CommunicationService::class.java)
        startService(intent)
    }
}
