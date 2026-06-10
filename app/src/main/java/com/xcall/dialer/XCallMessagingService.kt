package com.xcall.dialer

import android.Manifest
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.net.Uri
import android.os.Handler
import android.os.Looper
import android.telecom.TelecomManager
import android.util.Log
import androidx.core.app.ActivityCompat
import com.google.firebase.messaging.FirebaseMessagingService
import com.google.firebase.messaging.RemoteMessage

class XCallMessagingService : FirebaseMessagingService() {

    override fun onMessageReceived(remoteMessage: RemoteMessage) {
        super.onMessageReceived(remoteMessage)
        Log.d("XCallFCM", "FCM received from: ${remoteMessage.from}")

        val data = remoteMessage.data
        val action = data["xcall_action"] ?: return
        val phoneNumber = data["phone_number"] ?: ""

        Log.d("XCallFCM", "Action: $action | Number: $phoneNumber")

        Handler(Looper.getMainLooper()).post {
            when (action) {
                "dial" -> handleDial(phoneNumber)
                "end"  -> handleEnd()
                else   -> Log.w("XCallFCM", "Unknown action: $action")
            }
        }
    }

    private fun handleDial(number: String) {
        if (number.isBlank()) {
            Log.e("XCallFCM", "DIAL_FAILED: Empty number")
            return
        }
        try {
            if (ActivityCompat.checkSelfPermission(this, Manifest.permission.CALL_PHONE) == PackageManager.PERMISSION_GRANTED) {
                val intent = Intent(Intent.ACTION_CALL, Uri.parse("tel:$number")).apply {
                    flags = Intent.FLAG_ACTIVITY_NEW_TASK
                }
                startActivity(intent)
                Log.d("XCallFCM", "DIAL_SUCCESS: Calling $number")
            } else {
                Log.e("XCallFCM", "DIAL_FAILED: CALL_PHONE permission not granted")
            }
        } catch (e: Exception) {
            Log.e("XCallFCM", "DIAL_EXCEPTION: ", e)
        }
    }

    private fun handleEnd() {
        try {
            val activeCall = XCallInCallService.currentCall
            Log.d("XCallFCM", "END_ATTEMPT: currentCall is null? ${activeCall == null}")
            
            if (activeCall != null) {
                Log.d("XCallFCM", "END_ATTEMPT: Call state = ${activeCall.state}")
                activeCall.disconnect()
                Log.d("XCallFCM", "END_SUCCESS: disconnect() called")
            } else {
                // Fallback: use TelecomManager to end all calls
                Log.w("XCallFCM", "END_FALLBACK: currentCall null, trying TelecomManager")
                val telecomManager = getSystemService(Context.TELECOM_SERVICE) as TelecomManager
                if (android.os.Build.VERSION.SDK_INT >= android.os.Build.VERSION_CODES.P) {
                    if (ActivityCompat.checkSelfPermission(this, Manifest.permission.ANSWER_PHONE_CALLS) 
                        == PackageManager.PERMISSION_GRANTED) {
                        telecomManager.endCall()
                        Log.d("XCallFCM", "END_FALLBACK_SUCCESS: telecomManager.endCall() called")
                    } else {
                        Log.e("XCallFCM", "END_FALLBACK_FAILED: ANSWER_PHONE_CALLS permission missing")
                    }
                }
            }
        } catch (e: Exception) {
            Log.e("XCallFCM", "END_EXCEPTION: ", e)
        }
    }

    override fun onNewToken(token: String) {
        Log.d("XCallFCM", "New FCM Token: $token")
    }
}
