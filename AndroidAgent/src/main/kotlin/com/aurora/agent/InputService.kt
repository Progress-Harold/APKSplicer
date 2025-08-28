package com.aurora.agent

import android.accessibilityservice.AccessibilityService
import android.accessibilityservice.GestureDescription
import android.graphics.Path
import android.util.Log
import android.view.accessibility.AccessibilityEvent
import kotlinx.coroutines.*

/**
 * Aurora Input Service
 * Provides input injection capabilities for Aurora host
 */
class InputService : AccessibilityService() {
    
    companion object {
        private const val TAG = "AuroraInputService"
        var instance: InputService? = null
            private set
    }
    
    private val serviceScope = CoroutineScope(Dispatchers.Main + SupervisorJob())
    
    override fun onCreate() {
        super.onCreate()
        instance = this
        Log.i(TAG, "Aurora Input Service created")
    }
    
    override fun onDestroy() {
        super.onDestroy()
        instance = null
        serviceScope.cancel()
        Log.i(TAG, "Aurora Input Service destroyed")
    }
    
    override fun onServiceConnected() {
        super.onServiceConnected()
        Log.i(TAG, "Aurora Input Service connected")
        
        // Start communication service
        CommunicationService.startService(this)
    }
    
    override fun onAccessibilityEvent(event: AccessibilityEvent?) {
        // We don't need to handle accessibility events for input injection
        // This service is primarily for gesture dispatch capabilities
    }
    
    override fun onInterrupt() {
        Log.w(TAG, "Aurora Input Service interrupted")
    }
    
    /**
     * Inject a tap at the specified coordinates
     */
    fun injectTap(x: Int, y: Int, duration: Long = 100): Boolean {
        Log.d(TAG, "Injecting tap at ($x, $y)")
        
        val path = Path().apply {
            moveTo(x.toFloat(), y.toFloat())
        }
        
        val gesture = GestureDescription.Builder()
            .addStroke(GestureDescription.StrokeDescription(path, 0, duration))
            .build()
        
        return dispatchGesture(gesture, object : GestureResultCallback() {
            override fun onCompleted(gestureDescription: GestureDescription?) {
                Log.d(TAG, "Tap gesture completed")
            }
            
            override fun onCancelled(gestureDescription: GestureDescription?) {
                Log.w(TAG, "Tap gesture cancelled")
            }
        }, null)
    }
    
    /**
     * Inject a swipe gesture
     */
    fun injectSwipe(startX: Int, startY: Int, endX: Int, endY: Int, duration: Long = 300): Boolean {
        Log.d(TAG, "Injecting swipe from ($startX, $startY) to ($endX, $endY)")
        
        val path = Path().apply {
            moveTo(startX.toFloat(), startY.toFloat())
            lineTo(endX.toFloat(), endY.toFloat())
        }
        
        val gesture = GestureDescription.Builder()
            .addStroke(GestureDescription.StrokeDescription(path, 0, duration))
            .build()
        
        return dispatchGesture(gesture, object : GestureResultCallback() {
            override fun onCompleted(gestureDescription: GestureDescription?) {
                Log.d(TAG, "Swipe gesture completed")
            }
            
            override fun onCancelled(gestureDescription: GestureDescription?) {
                Log.w(TAG, "Swipe gesture cancelled")
            }
        }, null)
    }
    
    /**
     * Inject multi-touch gesture
     */
    fun injectMultiTouch(touches: List<TouchPoint>, duration: Long = 100): Boolean {
        Log.d(TAG, "Injecting multi-touch with ${touches.size} points")
        
        val builder = GestureDescription.Builder()
        
        touches.forEachIndexed { index, touch ->
            val path = Path().apply {
                moveTo(touch.x.toFloat(), touch.y.toFloat())
            }
            
            builder.addStroke(
                GestureDescription.StrokeDescription(path, index * 10L, duration)
            )
        }
        
        val gesture = builder.build()
        
        return dispatchGesture(gesture, object : GestureResultCallback() {
            override fun onCompleted(gestureDescription: GestureDescription?) {
                Log.d(TAG, "Multi-touch gesture completed")
            }
            
            override fun onCancelled(gestureDescription: GestureDescription?) {
                Log.w(TAG, "Multi-touch gesture cancelled")
            }
        }, null)
    }
    
    /**
     * Handle command from Aurora host
     */
    fun handleCommand(command: InputCommand): Boolean {
        return when (command.type) {
            InputCommand.Type.TAP -> {
                injectTap(command.x, command.y, command.duration)
            }
            InputCommand.Type.SWIPE -> {
                injectSwipe(command.x, command.y, command.endX ?: 0, command.endY ?: 0, command.duration)
            }
            InputCommand.Type.MULTI_TOUCH -> {
                injectMultiTouch(command.touches ?: emptyList(), command.duration)
            }
        }
    }
}

/**
 * Input command data structure
 */
data class InputCommand(
    val type: Type,
    val x: Int,
    val y: Int,
    val endX: Int? = null,
    val endY: Int? = null,
    val duration: Long = 100,
    val touches: List<TouchPoint>? = null
) {
    enum class Type {
        TAP, SWIPE, MULTI_TOUCH
    }
}

/**
 * Touch point for multi-touch gestures
 */
data class TouchPoint(
    val x: Int,
    val y: Int,
    val pressure: Float = 1.0f
)
