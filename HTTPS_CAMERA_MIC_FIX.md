# ✅ HTTPS Required for Camera/Microphone Access

## Problem
- Browser blocks camera/microphone on **HTTP** (insecure) connections
- Error: `AgoraRtcException(-1, null)` when trying to join
- Browser shows "Not secure" and blocks permissions
- **Root Cause**: Modern browsers require **HTTPS** (or `localhost`) for camera/mic access

## Why This Happens

**Browser Security Policy:**
- ✅ `http://localhost` → **Allowed** (treated as secure context)
- ✅ `https://anything` → **Allowed** (secure connection)
- ❌ `http://10.148.224.254:5000` → **Blocked** (insecure HTTP on network IP)

**Your Situation:**
- Using `http://10.148.224.254:5000` (HTTP on network IP)
- Browser blocks camera/mic access for security
- Permissions show as "Blocked" in browser settings

## Solutions (Choose One)

### Solution 1: Use ngrok (Easiest - Recommended for Network Testing)

**ngrok** provides a public HTTPS URL that tunnels to your local server.

#### Step 1: Install ngrok
```bash
# Download from: https://ngrok.com/download
# Or use package manager:
# Windows (Chocolatey):
choco install ngrok

# Mac (Homebrew):
brew install ngrok

# Or download binary and add to PATH
```

#### Step 2: Run Flutter on localhost
```bash
# Run Flutter normally (on localhost)
flutter run -d chrome --web-port=5000
```

#### Step 3: Start ngrok tunnel
```bash
# In a new terminal, create HTTPS tunnel to port 5000
ngrok http 5000
```

#### Step 4: Use ngrok URL
- ngrok will show a URL like: `https://abc123.ngrok.io`
- **Both PCs** can access: `https://abc123.ngrok.io`
- Browser will show HTTPS (secure) → Camera/mic will work!

**Pros:**
- ✅ Easiest setup
- ✅ Works from any network (not just local)
- ✅ HTTPS automatically provided
- ✅ No certificate configuration needed

**Cons:**
- ⚠️ Free tier has session timeouts
- ⚠️ Random URLs (change each time)
- ⚠️ Requires internet connection

---

### Solution 2: Use localhost (Simplest - Same Machine Only)

If you're testing on the **same machine**, use `localhost` instead of network IP.

#### Step 1: Run Flutter on localhost
```bash
# Run normally (defaults to localhost)
flutter run -d chrome --web-port=5000
```

#### Step 2: Access via localhost
- **PC 1**: `http://localhost:5000` ✅ (works - localhost is secure)
- **PC 2**: Cannot access (localhost only works on same machine)

**Pros:**
- ✅ No setup needed
- ✅ Works immediately
- ✅ Browser allows camera/mic on localhost

**Cons:**
- ❌ Only works on same machine
- ❌ Cannot test with two different PCs

---

### Solution 3: HTTPS with Self-Signed Certificate (Advanced)

Set up HTTPS locally with a self-signed certificate.

#### Step 1: Generate Self-Signed Certificate

**Windows (PowerShell):**
```powershell
# Install OpenSSL first (or use Git Bash)
# Then generate certificate:
openssl req -x509 -newkey rsa:4096 -keyout key.pem -out cert.pem -days 365 -nodes -subj "/CN=10.148.224.254"
```

**Mac/Linux:**
```bash
openssl req -x509 -newkey rsa:4096 -keyout key.pem -out cert.pem -days 365 -nodes -subj "/CN=10.148.224.254"
```

This creates:
- `key.pem` - Private key
- `cert.pem` - Certificate

#### Step 2: Configure Flutter for HTTPS

Flutter web doesn't natively support HTTPS, so you need a reverse proxy:

**Option A: Use a Node.js HTTPS Server**

Create `https-server.js`:
```javascript
const https = require('https');
const fs = require('fs');
const { exec } = require('child_process');

// Read certificate files
const options = {
  key: fs.readFileSync('key.pem'),
  cert: fs.readFileSync('cert.pem')
};

// Start Flutter web server
exec('flutter run -d chrome --web-port=5000', (error, stdout, stderr) => {
  if (error) {
    console.error(`Error: ${error.message}`);
    return;
  }
  console.log(stdout);
});

// Create HTTPS proxy server
https.createServer(options, (req, res) => {
  // Proxy to Flutter server
  const proxy = require('http').request({
    hostname: 'localhost',
    port: 5000,
    path: req.url,
    method: req.method,
    headers: req.headers
  }, (proxyRes) => {
    res.writeHead(proxyRes.statusCode, proxyRes.headers);
    proxyRes.pipe(res);
  });
  req.pipe(proxy);
}).listen(5443, '0.0.0.0', () => {
  console.log('HTTPS server running on https://10.148.224.254:5443');
});
```

**Option B: Use Caddy (Easier)**

1. Install Caddy: https://caddyserver.com/download
2. Create `Caddyfile`:
```
10.148.224.254:5443 {
    reverse_proxy localhost:5000
    tls internal
}
```
3. Run: `caddy run`

#### Step 3: Trust the Certificate

**Chrome/Edge:**
1. Access `https://10.148.224.254:5443`
2. Click "Advanced" → "Proceed to site"
3. Certificate will be trusted for this session

**Firefox:**
1. Access `https://10.148.224.254:5443`
2. Click "Advanced" → "Accept the Risk and Continue"

**Pros:**
- ✅ Works on local network
- ✅ No external service needed
- ✅ Full control

**Cons:**
- ⚠️ Complex setup
- ⚠️ Requires certificate management
- ⚠️ Browser warnings (self-signed cert)

---

### Solution 4: Browser Flag (Testing Only - Not Recommended)

**⚠️ WARNING: Only for testing! Not secure for production!**

Force browser to allow insecure camera/mic access:

**Chrome/Edge:**
```bash
# Windows:
chrome.exe --unsafely-treat-insecure-origin-as-secure=http://10.148.224.254:5000 --user-data-dir="C:\temp\chrome_dev"

# Mac:
/Applications/Google\ Chrome.app/Contents/MacOS/Google\ Chrome --unsafely-treat-insecure-origin-as-secure=http://10.148.224.254:5000 --user-data-dir="/tmp/chrome_dev"
```

**Pros:**
- ✅ Quick for testing
- ✅ No setup needed

**Cons:**
- ❌ **Not secure** - disables security features
- ❌ Only works with special browser launch
- ❌ Not recommended for production

---

## Recommended Solution: ngrok

For **network testing with two PCs**, use **ngrok** (Solution 1):

### Quick Start:
```bash
# Terminal 1: Run Flutter
flutter run -d chrome --web-port=5000

# Terminal 2: Start ngrok
ngrok http 5000

# Use the HTTPS URL shown by ngrok (e.g., https://abc123.ngrok.io)
# Both PCs can access this URL
```

### Benefits:
- ✅ HTTPS automatically (browser allows camera/mic)
- ✅ Works from any network
- ✅ No certificate setup
- ✅ Easy to use

---

## Testing After Fix

### Expected Behavior:
1. ✅ Browser shows **"Secure"** (HTTPS) or localhost
2. ✅ Permission prompt appears when joining session
3. ✅ Camera/mic permissions can be set to "Allow"
4. ✅ Console shows: `✅ [Web] Local video view set up`
5. ✅ Video session proceeds normally

### Verify:
- Check address bar: Should show 🔒 (secure) or localhost
- Check permissions: Camera/mic should be "Allow" (not "Block")
- Check console: No permission errors
- Check video: Should see camera feed

---

## Production Note

**In production** (`app.prepskul.com`):
- ✅ Already using HTTPS
- ✅ Camera/mic will work automatically
- ✅ No changes needed

This issue only affects **local development** when using HTTP on network IPs.

---

**Status**: ✅ HTTPS required for camera/mic - **Use ngrok for easiest network testing**

