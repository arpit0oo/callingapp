package com.xcall.dialer

import android.content.Context
import android.database.ContentObserver
import android.net.Uri
import android.os.Handler
import android.os.Looper
import android.os.PowerManager
import android.provider.CallLog
import android.util.Log
import com.google.android.gms.tasks.Tasks
import com.google.firebase.auth.FirebaseAuth
import com.google.firebase.firestore.FieldValue
import com.google.firebase.firestore.FirebaseFirestore
import com.google.firebase.firestore.SetOptions
import com.google.firebase.storage.FirebaseStorage
import java.io.File
import java.text.SimpleDateFormat
import java.util.Date
import java.util.Locale
import java.util.concurrent.atomic.AtomicBoolean

/**
 * PostCallProcessor handles the background processing of calls after they end.
 * Uses a ContentObserver to monitor CallLog changes, ensuring the OS has finalized
 * the call entry (duration > 0) before proceeding with upload and Firestore sync.
 */
object PostCallProcessor {

    private data class CallData(val number: String, val duration: Long, val date: Long)

    /**
     * Entry point for post-call processing.
     * Replaces the old polling loop with a ContentObserver approach.
     */
    fun process(context: Context, phoneNumber: String?, wasIncoming: Boolean) {
        Log.d("PostCallProcessor", "Starting post-call pipeline for $phoneNumber")
        
        val appContext = context.applicationContext
        val handler = Handler(Looper.getMainLooper())
        val isFinished = AtomicBoolean(false)

        val observer = object : ContentObserver(handler) {
            override fun onChange(selfChange: Boolean) {
                Log.d("PostCallProcessor", "CallLog onChange triggered")
                checkAndProceed(appContext, phoneNumber, wasIncoming, this, handler, isFinished, false)
            }
        }

        // Register ContentObserver on CallLog
        appContext.contentResolver.registerContentObserver(
            CallLog.Calls.CONTENT_URI,
            true,
            observer
        )

        // Set a maximum timeout of 30 seconds
        handler.postDelayed({
            if (isFinished.get()) return@postDelayed
            Log.d("PostCallProcessor", "Timeout (30s) reached. Proceeding with available data.")
            checkAndProceed(appContext, phoneNumber, wasIncoming, observer, handler, isFinished, true)
        }, 30000)

        // Initial check in case the log was already written
        checkAndProceed(appContext, phoneNumber, wasIncoming, observer, handler, isFinished, false)
    }

    private fun checkAndProceed(
        context: Context,
        targetNumber: String?,
        wasIncoming: Boolean,
        observer: ContentObserver,
        handler: Handler,
        isFinished: AtomicBoolean,
        isTimeout: Boolean
    ) {
        if (isFinished.get()) return

        val callData = fetchLatestCall(context, targetNumber)
        val duration = callData?.duration ?: 0L

        if (duration > 0 || isTimeout) {
            if (isFinished.compareAndSet(false, true)) {
                // Unregister and clear timeout
                context.contentResolver.unregisterContentObserver(observer)
                handler.removeCallbacksAndMessages(null)

                // Proceed with background work
                Thread {
                    try {
                        executePipelineWork(context, callData, targetNumber, wasIncoming)
                    } catch (e: Exception) {
                        Log.e("PostCallProcessor", "Pipeline execution failed", e)
                    }
                }.start()
            }
        } else {
            Log.d("PostCallProcessor", "Duration is 0, waiting for next onChange...")
        }
    }

    private fun fetchLatestCall(context: Context, targetNumber: String?): CallData? {
        return try {
            context.contentResolver.query(
                CallLog.Calls.CONTENT_URI,
                arrayOf(CallLog.Calls.NUMBER, CallLog.Calls.DURATION, CallLog.Calls.DATE),
                null, null, "${CallLog.Calls.DATE} DESC"
            )?.use { cursor ->
                if (cursor.moveToFirst()) {
                    do {
                        val number = cursor.getString(cursor.getColumnIndexOrThrow(CallLog.Calls.NUMBER))
                        val duration = cursor.getLong(cursor.getColumnIndexOrThrow(CallLog.Calls.DURATION))
                        val date = cursor.getLong(cursor.getColumnIndexOrThrow(CallLog.Calls.DATE))

                        // Match logic: check if this is the number we are processing
                        if (targetNumber == null || isSameNumber(number, targetNumber)) {
                            return@use CallData(number, duration, date)
                        }
                    } while (cursor.moveToNext())
                }
                null
            }
        } catch (e: Exception) {
            Log.e("PostCallProcessor", "Error querying CallLog", e)
            null
        }
    }

    private fun isSameNumber(n1: String, n2: String): Boolean {
        val clean1 = n1.replace("[^0-9]".toRegex(), "")
        val clean2 = n2.replace("[^0-9]".toRegex(), "")
        return if (clean1.length >= 10 && clean2.length >= 10) {
            clean1.endsWith(clean2.takeLast(10))
        } else {
            clean1 == clean2
        }
    }

    private fun executePipelineWork(
        context: Context,
        callData: CallData?,
        originalNumber: String?,
        wasIncoming: Boolean
    ) {
        // Ensure Firebase Auth is ready
        val auth = FirebaseAuth.getInstance()
        if (auth.currentUser == null) {
            try {
                Log.d("PostCallProcessor", "No user found, signing in anonymously")
                Tasks.await(auth.signInAnonymously())
            } catch (e: Exception) {
                Log.e("PostCallProcessor", "Anonymous auth failed", e)
            }
        }

        val user = auth.currentUser
        val duration = callData?.duration ?: 0L
        val finalNumber = callData?.number ?: originalNumber
        val startTimeMillis = callData?.date ?: System.currentTimeMillis()

        val docId = finalNumber?.replace("+91", "")?.replace(" ", "") ?: "unknown"
        val stopTimeMillis = startTimeMillis + (duration * 1000)

        // Search for recording (Hardware-agnostic approach)
        val possiblePaths = listOf(
            XCallForegroundService.cachedRecordingPath,
            "/storage/emulated/0/MIUI/sound_recorder/call_rec",
            "/storage/emulated/0/Call",
            "/storage/emulated/0/Recordings/Call"
        )
        
        var recordingFile: File? = null
        for (path in possiblePaths) {
            try {
                val directory = File(path)
                if (directory.exists() && directory.isDirectory) {
                    val audioFiles = directory.listFiles()?.filter { file ->
                        val n = file.name.lowercase()
                        n.endsWith(".m4a") || n.endsWith(".amr") || n.endsWith(".mp3")
                    }
                    val newestFile = audioFiles?.maxByOrNull { it.lastModified() }
                    if (newestFile != null) {
                        recordingFile = newestFile
                        Log.d("PostCallProcessor", "Found recording in: $path -> ${newestFile.name}")
                        break // immediately break once valid file is found
                    }
                }
            } catch (e: Exception) {
                Log.e("PostCallProcessor", "Failed to scan directory: $path", e)
            }
        }

        // Formatting
        val hours = duration / 3600
        val minutes = (duration % 3600) / 60
        val seconds = duration % 60
        val hms = String.format(Locale.US, "%02d:%02d:%02d", hours, minutes, seconds)
        val sdf = SimpleDateFormat("dd MMM yyyy HH:mm", Locale.US)
        val timelineDate = sdf.format(Date(startTimeMillis))

        // Build Firestore log entry
        val callEntry = mutableMapOf<String, Any?>(
            "CDuration" to hms,
            "CallStartStop" to mapOf(
                "CallStartT" to startTimeMillis,
                "CallStopT" to stopTimeMillis
            ),
            "Status" to if (wasIncoming) "Incoming" else "Outgoing",
            "Timeline" to "Called By XCall on $timelineDate Call Dur $hms",
            "LCaller" to (user?.uid ?: "anonymous"),
            "LCallon" to Date(), // FIX: Use client-side Date for arrayUnion
            "androidId" to XCallForegroundService.cachedAndroidId,
            "deviceName" to XCallForegroundService.cachedDeviceName
        )

        // Upload recording if found
        if (recordingFile != null) {
            try {
                Log.d("PostCallProcessor", "Uploading: ${recordingFile.name}")
                val storage = FirebaseStorage.getInstance()
                val storageRef = storage.getReference("recordings/$docId/${recordingFile.name}")
                
                Tasks.await(storageRef.putFile(Uri.fromFile(recordingFile)))
                val downloadUrl = Tasks.await(storageRef.downloadUrl).toString()
                
                callEntry["RecordingRef"] = downloadUrl
                callEntry["recording_status"] = "success"
                Log.d("PostCallProcessor", "Upload complete: $downloadUrl")
            } catch (e: Exception) {
                Log.e("PostCallProcessor", "Storage upload failed", e)
                callEntry["recording_status"] = "failed"
            }
        } else {
            callEntry["recording_status"] = "not_found"
        }

        // Sync to Firestore
        writeToFirestore(context, docId, callEntry)
    }

    private fun writeToFirestore(context: Context, docId: String, callEntry: Map<String, Any?>) {
        val powerManager = context.getSystemService(Context.POWER_SERVICE) as PowerManager
        val wakeLock = powerManager.newWakeLock(PowerManager.PARTIAL_WAKE_LOCK, "XCall:PostCallWrite")

        try {
            wakeLock.acquire(30000L)
            val db = FirebaseFirestore.getInstance()
            val updateData = mapOf("CallLog" to FieldValue.arrayUnion(callEntry))

            Tasks.await(
                db.collection("CNum")
                    .document(docId)
                    .set(updateData, SetOptions.merge())
            )
            Log.d("PostCallProcessor", "Firestore write successful for $docId")
        } catch (e: Exception) {
            Log.e("PostCallProcessor", "Firestore write failed: ${e.message}")
        } finally {
            if (wakeLock.isHeld) wakeLock.release()
        }
    }
}
