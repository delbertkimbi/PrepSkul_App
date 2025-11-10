# 🔥 Firebase Service Account Key Setup - Step by Step

**You're on the Firebase Admin SDK page. Here's what to do next:**

---

## 📋 **Steps to Complete:**

### **Step 1: Generate Private Key** (You're Here)

1. **Click "Generate new private key"** button (blue button at the bottom)
2. A warning dialog will appear - click "Generate key"
3. A JSON file will download (e.g., `operating-axis-420213-firebase-adminsdk-xxxxx.json`)

---

### **Step 2: Open the Downloaded JSON File**

1. Find the downloaded JSON file in your Downloads folder
2. Open it with a text editor (VS Code, TextEdit, etc.)
3. You'll see something like this:

```json
{
  "type": "service_account",
  "project_id": "operating-axis-420213",
  "private_key_id": "xxxxx",
  "private_key": "-----BEGIN PRIVATE KEY-----\n...\n-----END PRIVATE KEY-----\n",
  "client_email": "firebase-adminsdk-ikh86@operating-axis-420213.iam.gserviceaccount.com",
  "client_id": "xxxxx",
  "auth_uri": "https://accounts.google.com/o/oauth2/auth",
  "token_uri": "https://oauth2.googleapis.com/token",
  "auth_provider_x509_cert_url": "https://www.googleapis.com/oauth2/v1/certs",
  "client_x509_cert_url": "https://www.googleapis.com/oauth2/v1/certs/..."
}
```

---

### **Step 3: Add to Next.js Environment Variables**

#### **Option A: JSON String (Recommended for Vercel)**

1. **Copy the entire JSON content** (all of it, from `{` to `}`)
2. **Convert to single line:**
   - Remove all newlines
   - Keep all quotes as-is
   - The entire JSON should be on ONE line

3. **Add to `.env.local` in Next.js project:**

```bash
cd /Users/user/Desktop/PrepSkul/PrepSkul_Web
```

Create or edit `.env.local`:

```env
# Firebase Admin (for Push Notifications)
FIREBASE_SERVICE_ACCOUNT_KEY={"type":"service_account","project_id":"operating-axis-420213","private_key_id":"...","private_key":"-----BEGIN PRIVATE KEY-----\n...\n-----END PRIVATE KEY-----\n","client_email":"firebase-adminsdk-ikh86@operating-axis-420213.iam.gserviceaccount.com","client_id":"...","auth_uri":"https://accounts.google.com/o/oauth2/auth","token_uri":"https://oauth2.googleapis.com/token","auth_provider_x509_cert_url":"https://www.googleapis.com/oauth2/v1/certs","client_x509_cert_url":"..."}
```

**Important:** 
- Replace `...` with the actual values from your JSON file
- The entire JSON must be on ONE line
- All quotes must be preserved
- Escape any special characters if needed

#### **Option B: File Path (For Local Development Only)**

1. **Move the JSON file to Next.js project root:**
   ```bash
   # Copy the downloaded file to Next.js project
   cp ~/Downloads/operating-axis-420213-firebase-adminsdk-*.json /Users/user/Desktop/PrepSkul/PrepSkul_Web/firebase-service-account.json
   ```

2. **Add to `.env.local`:**
   ```env
   FIREBASE_SERVICE_ACCOUNT_PATH=./firebase-service-account.json
   ```

3. **Add to `.gitignore`:**
   ```
   firebase-service-account.json
   ```

---

### **Step 4: For Vercel (Production)**

If deploying to Vercel:

1. Go to Vercel Dashboard → Your Project → Settings → Environment Variables
2. Add new variable:
   - **Name:** `FIREBASE_SERVICE_ACCOUNT_KEY`
   - **Value:** The entire JSON (as single line)
   - **Environment:** Production, Preview, Development (select all)
3. Click "Save"
4. Redeploy your application

---

### **Step 5: Verify Setup**

1. **Restart your Next.js dev server:**
   ```bash
   cd /Users/user/Desktop/PrepSkul/PrepSkul_Web
   pnpm dev
   ```

2. **Check logs:**
   - You should see: `✅ Firebase Admin initialized from service account key`
   - No errors about Firebase Admin initialization

3. **Test push notification:**
   - Send a test notification via API
   - Verify it appears on device

---

## 🔒 **Security Reminders**

### **✅ DO:**
- ✅ Store key in environment variables only
- ✅ Add to `.gitignore` if using file path
- ✅ Use Vercel environment variables for production
- ✅ Keep the key secure and private

### **❌ DON'T:**
- ❌ Commit the JSON file to git
- ❌ Share the key publicly
- ❌ Hardcode the key in code
- ❌ Store in client-side code

---

## 🧪 **Quick Test**

After adding the key, test it:

```bash
# In Next.js project
curl -X POST http://localhost:3000/api/notifications/send \
  -H "Content-Type: application/json" \
  -d '{
    "userId": "your-user-id",
    "type": "test",
    "title": "Test Notification",
    "message": "Testing push notifications",
    "sendEmail": false
  }'
```

If successful, you should see:
- ✅ Push notification sent in logs
- ✅ Notification appears on device

---

## 📝 **Summary**

**What to do now:**
1. ✅ Click "Generate new private key"
2. ✅ Download the JSON file
3. ✅ Add to `.env.local` as `FIREBASE_SERVICE_ACCOUNT_KEY`
4. ✅ Restart Next.js server
5. ✅ Test push notification

**Once done, push notifications will work! 🚀**

---

**Need help? Check the logs for any errors and let me know!**

