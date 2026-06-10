package com.xcall.dialer

import android.content.Intent
import android.os.IBinder
import android.telecom.Call
import android.telecom.InCallService
import android.util.Log

class XCallInCallService : InCallService() {

    override fun onBind(intent: Intent?): IBinder? {
        Log.d("XCallInCall", "onBind: Service bound by system")
        return super.onBind(intent)
    }

    override fun onCallAdded(call: Call) {
        super.onCallAdded(call)
        currentCall = call
        Log.d("XCallInCall", "onCallAdded fired, currentCall set: ${call.details?.handle}")
        
        call.registerCallback(object : Call.Callback() {
            override fun onStateChanged(call: Call, state: Int) {
                super.onStateChanged(call, state)
                Log.d("XCallInCall", "Call State Changed: $state")
            }
        })
    }

    override fun onCallRemoved(call: Call) {
        super.onCallRemoved(call)
        currentCall = null
        Log.d("XCallInCall", "onCallRemoved fired, currentCall cleared")
    }

    companion object {
        var currentCall: Call? = null
    }
}
