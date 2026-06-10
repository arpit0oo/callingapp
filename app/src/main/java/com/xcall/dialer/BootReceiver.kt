package com.xcall.dialer

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.util.Log
import androidx.core.content.ContextCompat

class BootReceiver : BroadcastReceiver() {

    private val TAG = "XCall_Boot"

    override fun onReceive(context: Context, intent: Intent) {
        if (intent.action == Intent.ACTION_BOOT_COMPLETED) {
            Log.d(TAG, "BOOT_COMPLETED received — starting XCallForegroundService")
            val serviceIntent = Intent(context, XCallForegroundService::class.java)
            ContextCompat.startForegroundService(context, serviceIntent)
        }
    }
}
