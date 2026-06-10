package com.xcall.dialer

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.Service
import android.content.Intent
import android.content.pm.ServiceInfo
import android.os.Build
import android.os.IBinder
import android.provider.Settings
import android.util.Log
import androidx.core.app.NotificationCompat
import com.google.android.gms.tasks.Tasks
import com.google.firebase.auth.FirebaseAuth
import com.google.firebase.database.*
import kotlinx.coroutines.*
import java.io.File

/**
 * Modernized Foreground Service for XCall.
 * Uses Coroutines for non-blocking initialization, heartbeat management, and presence sync.
 */
class XCallForegroundService : Service() {

    private val TAG = "XCall_FGS"
    private val CHANNEL_ID = "xcall_service"
    private val NOTIFICATION_ID = 1001

    // Coroutine scope tied directly to the Service lifecycle
    private val serviceScope = CoroutineScope(Dispatchers.Main + SupervisorJob())
    private var heartbeatJob: Job? = null

    // RTDB References and Listeners kept for proper cleanup in onDestroy
    private var connectedListener: ValueEventListener? = null
    private var connectedRef: DatabaseReference? = null
    private var deviceNameListener: ValueEventListener? = null
    private var deviceNameRef: DatabaseReference? = null

    companion object {
        var cachedAndroidId: String = "unknown"
        var cachedDeviceName: String = "unknown"
        var cachedRecordingPath: String = "/storage/emulated/0/MIUI/sound_recorder/call_rec"
    }

    // ─────────────────────────────────────────────────────────────────────────
    // Lifecycle
    // ─────────────────────────────────────────────────────────────────────────

    override fun onCreate() {
        super.onCreate()
        Log.d(TAG, "Service onCreate — initializing background systems")

        setupForeground()

        // Offload all Firebase/RTDB initialization to a background coroutine
        serviceScope.launch(Dispatchers.IO) {
            try {
                initializeSystems()
            } catch (e: Exception) {
                Log.e(TAG, "Critical failure during system initialization", e)
            }
        }
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        Log.d(TAG, "Service onStartCommand — START_STICKY")
        return START_STICKY
    }

    override fun onDestroy() {
        super.onDestroy()
        Log.d(TAG, "Service onDestroy — cleaning up resources")
        
        // 1. Cancel all coroutines (including the heartbeat loop)
        serviceScope.cancel()

        // 2. Remove persistent RTDB listeners to prevent memory leaks
        connectedListener?.let { connectedRef?.removeEventListener(it) }
        deviceNameListener?.let { deviceNameRef?.removeEventListener(it) }
        
        Log.d(TAG, "Service destroyed and cleaned up")
    }

    override fun onBind(intent: Intent?): IBinder? = null

    // ─────────────────────────────────────────────────────────────────────────
    // System Initialization (Linear & Non-blocking)
    // ─────────────────────────────────────────────────────────────────────────

    /**
     * Sequential initialization flow using Coroutines and Tasks.await()
     */
    private suspend fun initializeSystems() {
        val auth = FirebaseAuth.getInstance()
        
        // Ensure the device is authenticated (Anonymously)
        if (auth.currentUser == null) {
            Log.d(TAG, "No user found, signing in anonymously...")
            try {
                Tasks.await(auth.signInAnonymously())
            } catch (e: Exception) {
                Log.e(TAG, "Firebase Auth failed, service cannot proceed", e)
                return
            }
        }

        val uid = auth.currentUser?.uid ?: return
        Log.d(TAG, "Authenticated as $uid — setting up presence")

        setupPresenceAndHeartbeat(uid)

        // Start Firestore command listener on the Main thread as per its design
        withContext(Dispatchers.Main) {
            FirestoreCommandListener.start(this@XCallForegroundService)
            Log.d(TAG, "FirestoreCommandListener started")
        }
    }

    /**
     * Configures the native RTDB presence system and starts the manual heartbeat.
     */
    private suspend fun setupPresenceAndHeartbeat(uid: String) {
        val db = FirebaseDatabase.getInstance(
            "https://xcall-test-default-rtdb.asia-southeast1.firebasedatabase.app"
        )
        val deviceRef = db.getReference("devices/$uid")
        
        val androidId = Settings.Secure.getString(contentResolver, Settings.Secure.ANDROID_ID) ?: "unknown"
        val recordingPath = detectRecordingPath() ?: "unknown"

        // Cache info for PostCallProcessor
        cachedAndroidId = androidId
        if (recordingPath != "unknown") {
            cachedRecordingPath = recordingPath
        }

        // 1. Native Firebase Presence (.info/connected)
        connectedRef = db.getReference(".info/connected")
        connectedListener = object : ValueEventListener {
            override fun onDataChange(snapshot: DataSnapshot) {
                val connected = snapshot.getValue(Boolean::class.java) ?: false
                if (connected) {
                    Log.d(TAG, "RTDB connection active — syncing presence info")

                    // Configure onDisconnect logic (server-side trigger)
                    deviceRef.onDisconnect().updateChildren(mapOf(
                        "online" to false,
                        "lastSeen" to ServerValue.TIMESTAMP,
                        "state" to "idle"
                    ))

                    // Set online status immediately on connect/reconnect
                    deviceRef.updateChildren(mapOf(
                        "online" to true,
                        "lastSeen" to ServerValue.TIMESTAMP,
                        "state" to "idle",
                        "androidId" to androidId,
                        "recordingPath" to recordingPath
                    ))
                } else {
                    Log.d(TAG, "RTDB connection lost")
                }
            }
            override fun onCancelled(error: DatabaseError) {
                Log.e(TAG, "connectedListener error: ${error.message}")
            }
        }
        connectedRef?.addValueEventListener(connectedListener!!)

        // 2. Persistent listener for deviceName
        deviceNameRef = deviceRef.child("deviceName")
        deviceNameListener = object : ValueEventListener {
            override fun onDataChange(snapshot: DataSnapshot) {
                val name = snapshot.getValue(String::class.java)
                cachedDeviceName = if (!name.isNullOrBlank()) name else "unknown"
                Log.d(TAG, "DeviceName synced from RTDB: $cachedDeviceName")
            }
            override fun onCancelled(error: DatabaseError) {}
        }
        deviceNameRef?.addValueEventListener(deviceNameListener!!)

        // 3. Start 10-second manual heartbeat ping
        startHeartbeatLoop(deviceRef)
    }

    /**
     * Clean Coroutine-based loop that updates lastSeen every 10 seconds.
     * Uses db.goOnline() to ensure the socket connection remains active.
     */
    private fun startHeartbeatLoop(deviceRef: DatabaseReference) {
        heartbeatJob?.cancel()
        heartbeatJob = serviceScope.launch(Dispatchers.IO) {
            val db = deviceRef.database
            Log.d(TAG, "Heartbeat loop started (10s interval)")
            
            while (isActive) {
                try {
                    // Force the database connection to stay alive
                    db.goOnline()

                    // Update presence info
                    val pingData = mapOf(
                        "online" to true,
                        "lastSeen" to ServerValue.TIMESTAMP
                    )
                    Tasks.await(deviceRef.updateChildren(pingData))
                } catch (e: Exception) {
                    Log.w(TAG, "Heartbeat ping failed (retrying in 10s): ${e.message}")
                }
                
                delay(10_000L)
            }
        }
    }

    // ─────────────────────────────────────────────────────────────────────────
    // Helpers
    // ─────────────────────────────────────────────────────────────────────────

    private fun detectRecordingPath(): String? {
        val candidates = listOf(
            "/storage/emulated/0/MIUI/sound_recorder/call_rec",
            "/storage/emulated/0/MIUI/Recording/Call Recording",
            "/storage/emulated/0/Recordings/Call",
            "/storage/emulated/0/CallRecordings",
            "/storage/emulated/0/Sounds/CallRecord",
            "/storage/emulated/0/Recording"
        )
        return candidates.firstOrNull { File(it).isDirectory }
    }

    private fun setupForeground() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val channel = NotificationChannel(
                CHANNEL_ID,
                "XCall Service",
                NotificationManager.IMPORTANCE_LOW
            ).apply {
                description = "Maintains connection with the XCall web panel"
                setShowBadge(false)
            }
            getSystemService(NotificationManager::class.java).createNotificationChannel(channel)
        }

        val notification = NotificationCompat.Builder(this, CHANNEL_ID)
            .setContentTitle("XCall is active")
            .setContentText("Ensuring device is reachable")
            .setSmallIcon(android.R.drawable.stat_sys_phone_call)
            .setPriority(NotificationCompat.PRIORITY_LOW)
            .setOngoing(true)
            .build()

        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            startForeground(NOTIFICATION_ID, notification, ServiceInfo.FOREGROUND_SERVICE_TYPE_DATA_SYNC)
        } else {
            startForeground(NOTIFICATION_ID, notification)
        }
    }
}
