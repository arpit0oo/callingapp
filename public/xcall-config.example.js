// ─────────────────────────────────────────────────────────────────────────────
// xcall-config.example.js  —  TEMPLATE  —  SAFE TO COMMIT
// Duplicate this file as xcall-config.js and replace all placeholder values.
// ─────────────────────────────────────────────────────────────────────────────

// Firebase Web client config (from Firebase Console → Project Settings → Your apps)
const XCALL_FIREBASE_CONFIG = {
  apiKey:            "YOUR_WEB_API_KEY",
  authDomain:        "YOUR_PROJECT_ID.firebaseapp.com",
  projectId:         "YOUR_PROJECT_ID",
  storageBucket:     "YOUR_PROJECT_ID.firebasestorage.app",
  messagingSenderId: "YOUR_SENDER_ID",
  appId:             "YOUR_APP_ID"
};

// Firebase Admin service account (from Firebase Console → Project Settings → Service Accounts)
// Used by server-side calls (e.g. FCM v1 API via fetch from the web page).
const XCALL_SERVICE_ACCOUNT = {
  type:                        "service_account",
  project_id:                  "YOUR_PROJECT_ID",
  private_key_id:              "YOUR_PRIVATE_KEY_ID",
  private_key:                 "-----BEGIN RSA PRIVATE KEY-----\nYOUR_PRIVATE_KEY\n-----END RSA PRIVATE KEY-----\n",
  client_email:                "firebase-adminsdk-XXXXX@YOUR_PROJECT_ID.iam.gserviceaccount.com",
  client_id:                   "YOUR_CLIENT_ID",
  auth_uri:                    "https://accounts.google.com/o/oauth2/auth",
  token_uri:                   "https://oauth2.googleapis.com/token",
  auth_provider_x509_cert_url: "https://www.googleapis.com/oauth2/v1/certs",
  client_x509_cert_url:        "https://www.googleapis.com/robot/v1/metadata/x509/firebase-adminsdk-XXXXX%40YOUR_PROJECT_ID.iam.gserviceaccount.com"
};

// FCM registration token of the target Android device.
// Retrieve this from the XCall app logs (tag: XCall_FCM) after first launch.
const XCALL_FCM_DEVICE_TOKEN = "YOUR_FCM_REGISTRATION_TOKEN";
