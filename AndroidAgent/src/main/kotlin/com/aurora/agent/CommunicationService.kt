package com.aurora.agent

import android.app.Service
import android.content.Context
import android.content.Intent
import android.os.IBinder
import android.util.Log
import kotlinx.coroutines.*
import org.json.JSONObject
import java.io.*
import java.net.ServerSocket
import java.net.Socket
import java.net.SocketTimeoutException

/**
 * Communication service for Aurora Agent
 * Handles TCP communication with Aurora host via ADB port forwarding
 */
class CommunicationService : Service() {
    
    companion object {
        private const val TAG = "AuroraCommunication"
        private const val PORT = 8888
        private const val SOCKET_TIMEOUT = 5000
        
        var isRunning = false
            private set
            
        fun startService(context: Context) {
            val intent = Intent(context, CommunicationService::class.java)
            context.startService(intent)
        }
    }
    
    private val serviceScope = CoroutineScope(Dispatchers.IO + SupervisorJob())
    private var serverSocket: ServerSocket? = null
    private var clientSockets = mutableListOf<Socket>()
    
    override fun onCreate() {
        super.onCreate()
        Log.i(TAG, "Aurora Communication Service created")
    }
    
    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        if (!isRunning) {
            startCommunicationServer()
        }
        return START_STICKY
    }
    
    override fun onDestroy() {
        super.onDestroy()
        stopCommunicationServer()
        serviceScope.cancel()
        Log.i(TAG, "Aurora Communication Service destroyed")
    }
    
    override fun onBind(intent: Intent?): IBinder? = null
    
    private fun startCommunicationServer() {
        serviceScope.launch {
            try {
                serverSocket = ServerSocket(PORT)
                isRunning = true
                Log.i(TAG, "Server started on port $PORT")
                
                while (isActive && !serverSocket!!.isClosed) {
                    try {
                        val clientSocket = serverSocket!!.accept()
                        clientSocket.soTimeout = SOCKET_TIMEOUT
                        
                        synchronized(clientSockets) {
                            clientSockets.add(clientSocket)
                        }
                        
                        Log.i(TAG, "Client connected: ${clientSocket.remoteSocketAddress}")
                        
                        // Handle client in separate coroutine
                        launch {
                            handleClient(clientSocket)
                        }
                        
                    } catch (e: SocketTimeoutException) {
                        // Continue listening
                    } catch (e: Exception) {
                        if (isActive) {
                            Log.e(TAG, "Error accepting connections", e)
                        }
                        break
                    }
                }
                
            } catch (e: Exception) {
                Log.e(TAG, "Server error", e)
            } finally {
                isRunning = false
            }
        }
    }
    
    private fun stopCommunicationServer() {
        isRunning = false
        
        synchronized(clientSockets) {
            clientSockets.forEach { socket ->
                try {
                    socket.close()
                } catch (e: Exception) {
                    Log.w(TAG, "Error closing client socket", e)
                }
            }
            clientSockets.clear()
        }
        
        serverSocket?.let { server ->
            try {
                server.close()
            } catch (e: Exception) {
                Log.w(TAG, "Error closing server socket", e)
            }
        }
        
        Log.i(TAG, "Communication server stopped")
    }
    
    private suspend fun handleClient(socket: Socket) {
        try {
            val reader = BufferedReader(InputStreamReader(socket.getInputStream()))
            val writer = PrintWriter(socket.getOutputStream(), true)
            
            // Send welcome message
            val welcomeMessage = JSONObject().apply {
                put("type", "welcome")
                put("message", "Aurora Agent ready")
                put("version", "1.0")
            }
            writer.println(welcomeMessage.toString())
            
            while (isActive && !socket.isClosed) {
                val line = withTimeoutOrNull(SOCKET_TIMEOUT.toLong()) {
                    reader.readLine()
                }
                
                if (line == null) {
                    continue
                }
                
                Log.d(TAG, "Received: $line")
                
                try {
                    val command = JSONObject(line)
                    val response = handleCommand(command)
                    writer.println(response.toString())
                } catch (e: Exception) {
                    Log.e(TAG, "Error processing command: $line", e)
                    val errorResponse = JSONObject().apply {
                        put("type", "error")
                        put("message", e.message ?: "Unknown error")
                    }
                    writer.println(errorResponse.toString())
                }
            }
            
        } catch (e: Exception) {
            Log.e(TAG, "Client handler error", e)
        } finally {
            synchronized(clientSockets) {
                clientSockets.remove(socket)
            }
            
            try {
                socket.close()
            } catch (e: Exception) {
                Log.w(TAG, "Error closing client socket", e)
            }
            
            Log.i(TAG, "Client disconnected")
        }
    }
    
    private fun handleCommand(command: JSONObject): JSONObject {
        val type = command.getString("type")
        
        return when (type) {
            "ping" -> {
                JSONObject().apply {
                    put("type", "pong")
                    put("timestamp", System.currentTimeMillis())
                }
            }
            
            "tap" -> {
                val x = command.getInt("x")
                val y = command.getInt("y")
                val duration = command.optLong("duration", 100)
                
                val inputService = InputService.instance
                val success = inputService?.injectTap(x, y, duration) ?: false
                
                JSONObject().apply {
                    put("type", "tap_response")
                    put("success", success)
                    put("x", x)
                    put("y", y)
                }
            }
            
            "swipe" -> {
                val startX = command.getInt("startX")
                val startY = command.getInt("startY")
                val endX = command.getInt("endX")
                val endY = command.getInt("endY")
                val duration = command.optLong("duration", 300)
                
                val inputService = InputService.instance
                val success = inputService?.injectSwipe(startX, startY, endX, endY, duration) ?: false
                
                JSONObject().apply {
                    put("type", "swipe_response")
                    put("success", success)
                    put("startX", startX)
                    put("startY", startY)
                    put("endX", endX)
                    put("endY", endY)
                }
            }
            
            "status" -> {
                JSONObject().apply {
                    put("type", "status_response")
                    put("inputServiceReady", InputService.instance != null)
                    put("serverRunning", isRunning)
                    put("connectedClients", clientSockets.size)
                }
            }
            
            else -> {
                JSONObject().apply {
                    put("type", "error")
                    put("message", "Unknown command type: $type")
                }
            }
        }
    }
}
