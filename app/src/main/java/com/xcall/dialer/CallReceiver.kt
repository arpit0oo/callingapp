package com.xcall.dialer

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.os.Handler
import android.os.Looper
import android.provider.CallLog
import android.telephony.TelephonyManager
import android.util.Log
import com.google.firebase.auth.FirebaseAuth
import com.google.firebase.database.FirebaseDatabase
import com.google.firebase.database.ServerValue
import java.util.Date

/**
 * CallReceiver monitors system call broadcasts to sync device state (ringing, active, idle)
 * with the Firebase Realtime Database.
 */
class CallReceiver : BroadcastReceiver() {

    override fun onReceive(context: Context, intent: Intent) {
        // Handle Outgoing Call Intent (captures number before OFFHOOK on older APIs)
        if (intent.action == Intent.ACTION_NEW_OUTGOING_CALL) {
            val outNumber = intent.getStringExtra(Intent.EXTRA_PHONE_NUMBER)
            if (outNumber != null) {
                savedNumber = outNumber.replace(Regex("[^0-9+]"), "")
            }
            Log.d(TAG, "ACTION_NEW_OUTGOING_CALL captured: $savedNumber")
            return
        }

        if (intent.action != TelephonyManager.ACTION_PHONE_STATE_CHANGED) return

        val stateStr = intent.getStringExtra(TelephonyManager.EXTRA_STATE)
        val state = when (stateStr) {
            TelephonyManager.EXTRA_STATE_IDLE     -> TelephonyManager.CALL_STATE_IDLE
            TelephonyManager.EXTRA_STATE_OFFHOOK  -> TelephonyManager.CALL_STATE_OFFHOOK
            TelephonyManager.EXTRA_STATE_RINGING  -> TelephonyManager.CALL_STATE_RINGING
            else                                  -> return
        }

        @Suppress("DEPRECATION")
        val rawNumber = intent.getStringExtra(TelephonyManager.EXTRA_INCOMING_NUMBER)

        if (state == TelephonyManager.CALL_STATE_RINGING) {
            Log.d(TAG, "RINGING broadcast — EXTRA_INCOMING_NUMBER: «$rawNumber»")
        }

        val number = if (state == TelephonyManager.CALL_STATE_RINGING) {
            rawNumber?.replace(Regex("[^0-9+]"), "")
                ?.takeIf { it.length >= 10 }
        } else {
            rawNumber
        }

        onCallStateChanged(context, state, number)
    }

    private fun onCallStateChanged(context: Context, state: Int, number: String?) {
        if (lastState == state && state != TelephonyManager.CALL_STATE_RINGING) return

        when (state) {
            TelephonyManager.CALL_STATE_RINGING -> {
                isIncoming  = true
                if (number != null) savedNumber = number
                Log.d(TAG, "RINGING: savedNumber = $savedNumber")

                writeDeviceState(
                    mapOf(
                        "state"          to "ringing",
                        "incomingNumber" to (savedNumber ?: "unknown"),
                        "lastSeen"       to ServerValue.TIMESTAMP
                    )
                )

                // Delayed re-check for MIUI/Samsung compatibility
                Handler(Looper.getMainLooper()).postDelayed({
                    if (lastState != TelephonyManager.CALL_STATE_RINGING) return@postDelayed

                    val finalNumber = savedNumber ?: run {
                        @Suppress("DEPRECATION", "MissingPermission")
                        val line1 = try {
                            val tm = context.getSystemService(Context.TELEPHONY_SERVICE) as TelephonyManager
                            tm.line1Number?.takeIf { it.length >= 6 }
                        } catch (e: Exception) {
                            Log.w(TAG, "getLine1Number() failed: ${e.message}")
                            null
                        }
                        line1
                    }

                    if (finalNumber != null && finalNumber != savedNumber) {
                        savedNumber = finalNumber
                    }

                    writeDeviceState(
                        mapOf(
                            "state"          to "ringing",
                            "incomingNumber" to (finalNumber ?: "unknown"),
                            "lastSeen"       to ServerValue.TIMESTAMP
                        )
                    )
                }, 1000L)
            }

            TelephonyManager.CALL_STATE_OFFHOOK -> {
                if (lastState == TelephonyManager.CALL_STATE_IDLE) {
                    // Outgoing call started
                    isIncoming    = false
                    callStartTime = Date()
                    Log.d(TAG, "OFFHOOK: Outgoing call started")
                } else if (lastState == TelephonyManager.CALL_STATE_RINGING) {
                    // Incoming call answered
                    isIncoming    = true
                    callStartTime = Date()
                    Log.d(TAG, "OFFHOOK: Incoming call answered")
                }

                // Aggressive fetch with delay to support modern Android/Samsung (API 29+)
                // This bypasses the potentially failing ACTION_NEW_OUTGOING_CALL broadcast
                Handler(Looper.getMainLooper()).postDelayed({
                    // Only proceed if still in offhook state
                    if (lastState != TelephonyManager.CALL_STATE_OFFHOOK) return@postDelayed

                    if (!isIncoming && savedNumber == null) {
                        savedNumber = getOutgoingNumber(context)
                        Log.d(TAG, "OFFHOOK Delay: Aggressively fetched outgoing number: $savedNumber")
                    }

                    val onCallNumber = savedNumber
                    Log.d(TAG, "OFFHOOK: writing onCall=$onCallNumber to RTDB")
                    writeDeviceState(
                        mapOf(
                            "state"          to "active",
                            "incomingNumber" to null,
                            "onCall"         to onCallNumber,
                            "lastSeen"       to ServerValue.TIMESTAMP
                        )
                    )
                }, 1500)
            }

            TelephonyManager.CALL_STATE_IDLE -> {
                val wasIncoming    = isIncoming
                val snapshotNumber = if (wasIncoming) savedNumber else null

                Log.d(TAG, "IDLE: Call ended. wasIncoming=$wasIncoming, number=$snapshotNumber")

                writeDeviceState(
                    mapOf(
                        "state"          to "idle",
                        "incomingNumber" to null,
                        "onCall"         to null,
                        "lastSeen"       to ServerValue.TIMESTAMP
                    )
                )

                Handler(Looper.getMainLooper()).postDelayed({
                    val finalNumber = if (wasIncoming) snapshotNumber else getOutgoingNumber(context)
                    Log.d(TAG, "Executing PostCallProcessor for: $finalNumber")
                    PostCallProcessor.process(context, finalNumber, wasIncoming)
                }, 4000)

                isIncoming  = false
                savedNumber = null
            }
        }
        lastState = state
    }

    private fun writeDeviceState(data: Map<String, Any?>) {
        val uid = FirebaseAuth.getInstance().currentUser?.uid ?: return

        FirebaseDatabase.getInstance(
            "https://xcall-test-default-rtdb.asia-southeast1.firebasedatabase.app"
        )
            .getReference("devices/$uid")
            .updateChildren(data)
            .addOnSuccessListener {
                Log.d("XCall_RTDB", "devices/$uid write OK → ${data["state"]}")
            }
            .addOnFailureListener { e ->
                Log.e("XCall_RTDB", "devices/$uid write FAILED: ${e.message}", e)
            }
    }

    private fun getOutgoingNumber(context: Context): String? {
        return try {
            val cursor = context.contentResolver.query(
                CallLog.Calls.CONTENT_URI,
                arrayOf(CallLog.Calls.NUMBER),
                "${CallLog.Calls.TYPE} = ?",
                arrayOf(CallLog.Calls.OUTGOING_TYPE.toString()),
                "${CallLog.Calls.DATE} DESC"
            )
            cursor?.use {
                val index = it.getColumnIndex(CallLog.Calls.NUMBER)
                if (index != -1 && it.moveToFirst()) it.getString(index) else null
            }
        } catch (e: SecurityException) {
            Log.e(TAG, "Missing READ_CALL_LOG permission", e)
            null
        } catch (e: Exception) {
            Log.e(TAG, "Error querying CallLog", e)
            null
        }
    }

    companion object {
        private const val TAG = "CallReceiver"
        private var lastState     = TelephonyManager.CALL_STATE_IDLE
        private var isIncoming    = false
        private var savedNumber: String? = null
        private var callStartTime: Date? = null
    }
}
