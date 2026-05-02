# 🚀 Install ngrok - Quick Guide

## Option 1: Download ngrok Binary (No Admin Required - Easiest)

### Step 1: Download ngrok
1. Go to: https://ngrok.com/download
2. Download the Windows version (ZIP file)
3. Extract the ZIP file to a folder (e.g., `C:\ngrok` or `C:\Users\TECH\Desktop\ngrok`)

### Step 2: Add to PATH (Optional but Recommended)
1. Copy the path where you extracted ngrok (e.g., `C:\ngrok`)
2. Open System Environment Variables:
   - Press `Win + R`
   - Type: `sysdm.cpl` and press Enter
   - Go to "Advanced" tab → "Environment Variables"
   - Under "User variables", find "Path" → "Edit"
   - Click "New" → Paste the ngrok folder path → "OK"
3. Restart PowerShell/Terminal

### Step 3: Verify Installation
```powershell
ngrok version
```

### Step 4: Use ngrok
```powershell
# Start ngrok tunnel to port 5000
ngrok http 5000
```

---

## Option 2: Use Chocolatey (Requires Admin)

### Step 1: Open PowerShell as Administrator
1. Press `Win + X`
2. Select "Windows PowerShell (Admin)" or "Terminal (Admin)"
3. Click "Yes" when prompted by UAC

### Step 2: Install ngrok
```powershell
choco install ngrok
```

### Step 3: Verify Installation
```powershell
ngrok version
```

---

## Quick Start After Installation

### Terminal 1: Run Flutter
```powershell
cd C:\Users\TECH\Desktop\PREPSKUL\PrepSkul_App
flutter run -d chrome --web-port=5000
```

### Terminal 2: Start ngrok
```powershell
# If ngrok is in PATH:
ngrok http 5000

# OR if ngrok is in a specific folder:
C:\ngrok\ngrok.exe http 5000
```

### Terminal 3: Use the HTTPS URL
- ngrok will show: `Forwarding https://abc123.ngrok.io -> http://localhost:5000`
- **Use this HTTPS URL on both PCs**: `https://abc123.ngrok.io`
- Browser will show HTTPS (secure) → Camera/mic will work!

---

## Troubleshooting

### "ngrok: command not found"
- Make sure ngrok is in your PATH, OR
- Use full path: `C:\path\to\ngrok.exe http 5000`

### "ngrok: authentication required"
- Sign up for free at: https://dashboard.ngrok.com/signup
- Get your authtoken from dashboard
- Run: `ngrok config add-authtoken YOUR_TOKEN`

### Port already in use
- Make sure Flutter is running on port 5000
- Or use a different port: `ngrok http 8080`

---

**Status**: ✅ ngrok installation guide - **Use Option 1 (download binary) for easiest setup**

