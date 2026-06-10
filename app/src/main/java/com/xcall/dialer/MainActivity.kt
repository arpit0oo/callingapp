package com.xcall.dialer

import android.Manifest
import android.companion.AssociationRequest
import android.companion.BluetoothDeviceFilter
import android.companion.CompanionDeviceManager
import android.content.Context
import android.content.Intent
import android.content.IntentSender
import android.content.pm.PackageManager
import android.net.Uri
import android.os.Build
import android.os.Bundle
import android.os.Environment
import android.provider.Settings
import android.telecom.TelecomManager
import android.util.Log
import android.widget.Button
import android.widget.EditText
import android.widget.Toast
import androidx.appcompat.app.AppCompatActivity
import androidx.core.app.ActivityCompat
import androidx.core.content.ContextCompat
import com.google.firebase.auth.FirebaseAuth
import com.google.firebase.messaging.FirebaseMessaging

class MainActivity : AppCompatActivity() {

    private val REQUIRED_PERMISSIONS = arrayOf(
        Manifest.permission.CALL_PHONE,
        Manifest.permission.READ_PHONE_STATE,
        Manifest.permission.READ_CALL_LOG,
        Manifest.permission.READ_EXTERNAL_STORAGE,
        Manifest.permission.INTERNET,
        Manifest.permission.ANSWER_PHONE_CALLS
    )

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        setContentView(R.layout.activity_main)

        Log.d("XCall", "MainActivity onCreate - Version 2.1")

        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) {
            if (!Environment.isExternalStorageManager()) {
                Log.w("XCall", "MANAGE_EXTERNAL_STORAGE not granted - redirecting to settings")
                val intent = Intent(Settings.ACTION_MANAGE_APP_ALL_FILES_ACCESS_PERMISSION)
                intent.data = Uri.parse("package:${packageName}")
                startActivity(intent)
            } else {
                Log.d("XCall", "MANAGE_EXTERNAL_STORAGE granted OK")
            }
        }

        com.google.firebase.messaging.FirebaseMessaging.getInstance().token
            .addOnSuccessListener { token ->
                Log.d("XCall_FCM", "Current FCM Token: $token")
            }

        // Start Firestore command listener — sign in anonymously if needed
        val auth = FirebaseAuth.getInstance()
        if (auth.currentUser != null) {
            Log.d("XCall", "Auth confirmed (uid=${auth.currentUser!!.uid}) — starting FirestoreCommandListener")
            FirestoreCommandListener.start(this)
        } else {
            Log.d("XCall", "No current user — attempting anonymous sign-in")
            auth.signInAnonymously()
                .addOnSuccessListener { result ->
                    val uid = result.user?.uid
                    Log.d("XCall", "Anonymous sign-in OK uid=$uid — starting FirestoreCommandListener")
                    FirestoreCommandListener.start(this)
                }
                .addOnFailureListener { e ->
                    Log.e("XCall", "Anonymous sign-in FAILED: ${e.message}", e)
                }
        }

        if (!allPermissionsGranted()) {
            ActivityCompat.requestPermissions(this, REQUIRED_PERMISSIONS, 10)
        }

        // Start persistent foreground service
        ContextCompat.startForegroundService(
            this,
            Intent(this, XCallForegroundService::class.java)
        )

        checkAndRequestDefaultDialer()

        val etPhoneNumber = findViewById<EditText>(R.id.etPhoneNumber)

        findViewById<Button>(R.id.btnSetDefaultDialer).setOnClickListener {
            requestDefaultDialer()
        }

        findViewById<Button>(R.id.btnMakeCall).setOnClickListener {
            val phoneNumber = etPhoneNumber.text.toString().trim()
            if (phoneNumber.isEmpty()) {
                Toast.makeText(this, "Enter a number first", Toast.LENGTH_SHORT).show()
            } else {
                val intent = Intent(Intent.ACTION_CALL)
                intent.data = Uri.parse("tel:$phoneNumber")
                startActivity(intent)
            }
        }

        findViewById<Button>(R.id.btnEndCall).setOnClickListener {
            try {
                val activeCall = XCallInCallService.currentCall
                if (activeCall != null) {
                    activeCall.disconnect()
                    Toast.makeText(this, "Call ended via InCallService", Toast.LENGTH_SHORT).show()
                } else {
                    val telecomManager = getSystemService(Context.TELECOM_SERVICE) as TelecomManager
                    if (ActivityCompat.checkSelfPermission(this, Manifest.permission.ANSWER_PHONE_CALLS) == PackageManager.PERMISSION_GRANTED) {
                        val result = telecomManager.endCall()
                        Toast.makeText(this, if (result) "Call ended via TelecomManager" else "No active call", Toast.LENGTH_SHORT).show()
                    } else {
                        Toast.makeText(this, "Permission not granted", Toast.LENGTH_SHORT).show()
                    }
                }
            } catch (e: Exception) {
                Toast.makeText(this, "Error: ${e.message}", Toast.LENGTH_SHORT).show()
            }
        }

        findViewById<Button>(R.id.btnPairDevice).setOnClickListener {
            try {
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
                    val deviceManager = getSystemService(CompanionDeviceManager::class.java)
                    val request = AssociationRequest.Builder()
                        .addDeviceFilter(BluetoothDeviceFilter.Builder().build())
                        .build()
                    deviceManager.associate(request, object : CompanionDeviceManager.Callback() {
                        override fun onDeviceFound(chooserLauncher: IntentSender) {
                            startIntentSenderForResult(chooserLauncher, 1001, null, 0, 0, 0)
                        }
                        override fun onFailure(error: CharSequence?) {
                            Toast.makeText(this@MainActivity, "Pairing failed: $error", Toast.LENGTH_SHORT).show()
                        }
                    }, null)
                } else {
                    Toast.makeText(this, "Pairing requires Android 12 (API 31) or higher", Toast.LENGTH_SHORT).show()
                }
            } catch (e: Exception) {
                Log.e("XCall_Pair", "Pairing crash", e)
                Toast.makeText(this@MainActivity, "Error: ${e.message}", Toast.LENGTH_SHORT).show()
            }
        }
    }

    private fun checkAndRequestDefaultDialer() {
        val telecomManager = getSystemService(Context.TELECOM_SERVICE) as TelecomManager
        val isDefault = telecomManager.defaultDialerPackage == packageName
        if (!isDefault) {
            Log.w("XCall", "App is NOT the default dialer. InCallService will not work.")
            requestDefaultDialer()
        } else {
            Log.d("XCall", "App is the default dialer.")
        }
    }

    private fun requestDefaultDialer() {
        val intent = Intent(TelecomManager.ACTION_CHANGE_DEFAULT_DIALER).apply {
            putExtra(TelecomManager.EXTRA_CHANGE_DEFAULT_DIALER_PACKAGE_NAME, packageName)
        }
        startActivity(intent)
    }

    private fun allPermissionsGranted() = REQUIRED_PERMISSIONS.all {
        ContextCompat.checkSelfPermission(baseContext, it) == PackageManager.PERMISSION_GRANTED
    }

    override fun onRequestPermissionsResult(
        requestCode: Int, permissions: Array<String>, grantResults: IntArray
    ) {
        super.onRequestPermissionsResult(requestCode, permissions, grantResults)
        if (requestCode == 10) {
            if (allPermissionsGranted()) {
                Toast.makeText(this, "Permissions granted", Toast.LENGTH_SHORT).show()
            } else {
                Toast.makeText(this, "Permissions not granted by the user.", Toast.LENGTH_SHORT).show()
            }
        }
    }
}
