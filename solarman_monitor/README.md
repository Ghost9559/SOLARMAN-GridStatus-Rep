# Solarman Grid Monitor — Flutter App

Replaces the MacroDroid setup with a proper Android app.
Polls Solarman API, detects grid outages, sends ONE alert (no duplicates), resets when power returns.

---

## What the app does

- Fetches live wire_power, solar, battery %, home load from your inverter
- Checks every X minutes (configurable: 5 / 10 / 15 / 30 min)
- Sends notification ONCE when grid goes down (state flag = no duplicates)
- Sends notification when grid is restored (resets flag)
- Auto-login + auto token refresh (handles expiry for you)
- Auto-detects your station + device (no manual ID needed)

---

## Build Instructions

### Prerequisites
1. Install Flutter: https://docs.flutter.dev/get-started/install
2. Install Android Studio (for Android SDK + device connection)
3. Connect your phone via USB (enable Developer Options + USB Debugging)

### Build steps

```bash
# 1. Go into the project folder
cd solarman_monitor

# 2. Get dependencies
flutter pub get

# 3. Build APK
flutter build apk --release

# Output: build/app/outputs/flutter-apk/app-release.apk
```

### Install on phone

**Option A — USB:**
```bash
flutter install
```

**Option B — Manual sideload:**
Copy `app-release.apk` to your Vivo.
Open Files app → tap the APK → Install.
Enable "Install from unknown sources" if prompted.

---

## First-time setup in app

1. Open app → tap **Setup Now**
2. Enter:
   - App ID (from Solarman developer portal)
   - App Secret
   - Your Solarman account email
   - Your Solarman account password
3. Tap **Save & Connect** — app auto-finds your station and device
4. Dashboard loads. Done.

---

## How to get API credentials

1. Go to https://home.solarmanpv.com
2. Login → Profile → API Management
3. Create an app → get App ID + App Secret

---

## Solarman API Keys (wire_power field)

The app tries `W_totalGridPower` by default. If your inverter uses a different key,
look at the raw data in `solarman_service.dart` and change the key name.
Common variants: `pG`, `gridPower`, `totalGridPower`

---

## Troubleshooting

| Problem | Fix |
|---|---|
| Auth failed | Double-check App ID, App Secret, email/password |
| No stations found | Verify account has a registered station |
| Wire power always 0 | Change API key in solarman_service.dart |
| Notifications not showing | Go to Android Settings → Apps → Solar Monitor → Notifications → Enable |
| App stops polling | Android battery optimization is killing the app — add it to battery optimization whitelist |

---

## Battery Optimization (IMPORTANT)

Android will kill background apps. To keep polling working:

1. Settings → Battery → Battery Optimization
2. Find "Solar Monitor" → Set to "Don't optimize"

On Vivo/Funtouch OS:
Settings → Battery → Background App Management → Solar Monitor → Allow background activity
