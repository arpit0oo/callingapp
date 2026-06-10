package com.xcall.dialer

import android.Manifest
import android.content.Context
import android.content.pm.PackageManager
import android.net.Uri
import android.os.Bundle
import android.telecom.TelecomManager
import android.util.Log
import androidx.core.app.ActivityCompat
import com.google.firebase.auth.FirebaseAuth
import com.google.firebase.database.DataSnapshot
import com.google.firebase.database.DatabaseError
import com.google.firebase.database.DatabaseReference
import com.google.firebase.database.FirebaseDatabase
import com.google.firebase.database.ValueEventListener

/**
 * FirestoreCommandListener — singleton that maintains a real-time listener on
 * RTDB commands/{uid}. Watches the `action` field and acts immediately:
 *   "accept" → TelecomManager.acceptRingingCall() (requires ANSWER_PHONE_CALLS)
 *   "reject" → TelecomManager.endCall()  (incoming call — decline before answer)
 *   "end"    → TelecomManager.endCall()  (active call — hang up from web panel)
 *   "dial"   → TelecomManager.placeCall(tel:NUMBER) using the `number` field (requires CALL_PHONE)
 * After acting, clears the command by writing {action: null, number: null} to commands/{uid}
 * via updateChildren().
 *
 * Call [start] from MainActivity.onCreate() once auth is confirmed.
 * Call [stop]  from MainActivity.onDestroy() if you want to clean up explicitly.
 */
object FirestoreCommandListener {

    private const val TAG     = "XCall_CMD"
    private const val RTDB_URL = "https://xcall-test-default-rtdb.asia-southeast1.firebasedatabase.app"

    private var commandsRef:       DatabaseReference?  = null
    private var valueEventListener: ValueEventListener? = null

    // ─────────────────────────────────────────────────────────────────────────
    // Public API
    // ─────────────────────────────────────────────────────────────────────────

    fun start(context: Context) {
        val uid = FirebaseAuth.getInstance().currentUser?.uid
        if (uid == null) {
            Log.w(TAG, "start() called but no authenticated user — listener not attached")
            return
        }

        // Prevent duplicate listeners
        if (valueEventListener != null) {
            Log.d(TAG, "Listener already active for uid=$uid — skipping re-attach")
            return
        }

        Log.d(TAG, "Attaching RTDB command listener for uid=$uid")

        val ref = FirebaseDatabase.getInstance(RTDB_URL)
            .getReference("commands/$uid")
        commandsRef = ref

        val listener = object : ValueEventListener {
            override fun onDataChange(snapshot: DataSnapshot) {
                val action = snapshot.child("action").getValue(String::class.java)
                val number = snapshot.child("number").getValue(String::class.java)
                Log.d(TAG, "RTDB snapshot received — action=$action, number=$number")

                when (action) {
                    "accept"         -> handleAccept(context, uid)
                    "reject", "end"  -> handleEndCall(context, uid, action)
                    "dial"           -> handleDial(context, uid, number)
                    null, ""         -> { /* No pending command */ }
                    else             -> Log.w(TAG, "Unknown action value: $action")
                }
            }

            override fun onCancelled(error: DatabaseError) {
                Log.e(TAG, "RTDB command listener cancelled: ${error.message}", error.toException())
            }
        }

        ref.addValueEventListener(listener)
        valueEventListener = listener
    }

    fun stop() {
        val ref      = commandsRef
        val listener = valueEventListener
        if (ref != null && listener != null) {
            ref.removeEventListener(listener)
        }
        commandsRef        = null
        valueEventListener = null
        Log.d(TAG, "RTDB command listener detached")
    }

    // ─────────────────────────────────────────────────────────────────────────
    // Command handlers
    // ─────────────────────────────────────────────────────────────────────────

    private fun handleAccept(context: Context, uid: String) {
        Log.d(TAG, "Handling command: accept")

        if (ActivityCompat.checkSelfPermission(
                context,
                Manifest.permission.ANSWER_PHONE_CALLS
            ) != PackageManager.PERMISSION_GRANTED
        ) {
            Log.e(TAG, "ANSWER_PHONE_CALLS permission not granted — cannot accept call")
            clearCommand(uid)
            return
        }

        try {
            val telecomManager = context.getSystemService(Context.TELECOM_SERVICE) as TelecomManager
            telecomManager.acceptRingingCall()
            Log.d(TAG, "acceptRingingCall() invoked successfully")
        } catch (e: Exception) {
            Log.e(TAG, "acceptRingingCall() threw an exception: ${e.message}", e)
        } finally {
            clearCommand(uid)
        }
    }

    /**
     * Shared handler for both "reject" (decline ringing call) and
     * "end" (hang up an already-active call). Both map to endCall().
     */
    private fun handleEndCall(context: Context, uid: String, action: String) {
        Log.d(TAG, "Handling command: $action")

        if (ActivityCompat.checkSelfPermission(
                context,
                Manifest.permission.ANSWER_PHONE_CALLS
            ) != PackageManager.PERMISSION_GRANTED
        ) {
            Log.e(TAG, "ANSWER_PHONE_CALLS permission not granted — cannot handle '$action'")
            clearCommand(uid)
            return
        }

        try {
            val telecomManager = context.getSystemService(Context.TELECOM_SERVICE) as TelecomManager
            @Suppress("DEPRECATION")
            telecomManager.endCall()
            Log.d(TAG, "endCall() invoked successfully for action='$action'")
        } catch (e: Exception) {
            Log.e(TAG, "endCall() threw an exception for action='$action': ${e.message}", e)
        } finally {
            clearCommand(uid)
        }
    }

    private fun handleDial(context: Context, uid: String, number: String?) {
        Log.d(TAG, "Handling command: dial, number=$number")

        if (number.isNullOrBlank()) {
            Log.e(TAG, "dial command received but number is null or blank — ignoring")
            clearCommand(uid)
            return
        }

        if (ActivityCompat.checkSelfPermission(
                context,
                Manifest.permission.CALL_PHONE
            ) != PackageManager.PERMISSION_GRANTED
        ) {
            Log.e(TAG, "CALL_PHONE permission not granted — cannot place call")
            clearCommand(uid)
            return
        }

        try {
            val telecomManager = context.getSystemService(Context.TELECOM_SERVICE) as TelecomManager
            val uri    = Uri.fromParts("tel", number, null)
            val extras = Bundle()
            telecomManager.placeCall(uri, extras)
            Log.d(TAG, "placeCall fired for: $number")
        } catch (e: Exception) {
            Log.e(TAG, "Failed to place call: ${e.message}", e)
        } finally {
            clearCommand(uid)
        }
    }

    // ─────────────────────────────────────────────────────────────────────────
    // RTDB helper — clear command after handling
    // ─────────────────────────────────────────────────────────────────────────

    private fun clearCommand(uid: String) {
        Log.d(TAG, "Clearing command fields for uid=$uid")
        FirebaseDatabase.getInstance(RTDB_URL)
            .getReference("commands/$uid")
            .updateChildren(mapOf("action" to null, "number" to null))
            .addOnSuccessListener {
                Log.d(TAG, "command cleared successfully")
            }
            .addOnFailureListener { e ->
                Log.e(TAG, "Failed to clear command: ${e.message}", e)
            }
    }
}
