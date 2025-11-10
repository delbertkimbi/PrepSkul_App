# 🔑 Add Firebase Service Account Key to Environment Variables

**File:** `operating-axis-420213-firebase-adminsdk-ikh86-2a644585f1.json`

---

## 📋 **Step-by-Step Instructions**

### **Step 1: Open the JSON File**

1. Open the downloaded file: `operating-axis-420213-firebase-adminsdk-ikh86-2a644585f1.json`
2. You should see something like this:

```json
{
  "type": "service_account",
  "project_id": "operating-axis-420213",
  "private_key_id": "2a644585f1",
  "private_key": "-----BEGIN PRIVATE KEY-----\n...\n-----END PRIVATE KEY-----\n",
  "client_email": "firebase-adminsdk-ikh86@operating-axis-420213.iam.gserviceaccount.com",
  "client_id": "...",
  "auth_uri": "https://accounts.google.com/o/oauth2/auth",
  "token_uri": "https://oauth2.googleapis.com/token",
  "auth_provider_x509_cert_url": "https://www.googleapis.com/oauth2/v1/certs",
  "client_x509_cert_url": "..."
}
```

---

### **Step 2: Convert to Single Line**

**Option A: Manual (Easy)**
1. Copy the entire JSON (from `{` to `}`)
2. Remove all line breaks
3. Make sure it's all on ONE line
4. Keep all quotes as-is

**Option B: Use a Tool**
1. Use an online JSON minifier: https://www.jsonformatter.org/json-minify
2. Paste your JSON
3. Click "Minify"
4. Copy the result (single line)

---

### **Step 3: Add to `.env.local`**

1. **Navigate to Next.js project:**
   ```bash
   cd /Users/user/Desktop/PrepSkul/PrepSkul_Web
   ```

2. **Open or create `.env.local`:**
   ```bash
   # Create if doesn't exist, or open existing
   nano .env.local
   # or
   code .env.local
   ```

3. **Add the key:**
   ```env
   # Firebase Admin (for Push Notifications)
   FIREBASE_SERVICE_ACCOUNT_KEY={"type":"service_account","project_id":"operating-axis-420213","private_key_id":"2a644585f1","private_key":"-----BEGIN PRIVATE KEY-----\n...\n-----END PRIVATE KEY-----\n","client_email":"firebase-adminsdk-ikh86@operating-axis-420213.iam.gserviceaccount.com","client_id":"...","auth_uri":"https://accounts.google.com/o/oauth2/auth","token_uri":"https://oauth2.googleapis.com/token","auth_provider_x509_cert_url":"https://www.googleapis.com/oauth2/v1/certs","client_x509_cert_url":"..."}
   ```

   **Important:** Replace `...` with the actual values from your JSON file.

---

### **Step 4: Alternative - Use File Path (Easier for Local Dev)**

If the single-line JSON is too complex, use file path instead:

1. **Copy the JSON file to Next.js project:**
   ```bash
   cd /Users/user/Desktop/PrepSkul/PrepSkul_Web
   cp ~/Downloads/operating-axis-420213-firebase-adminsdk-ikh86-2a644585f1.json ./firebase-service-account.json
   ```

2. **Add to `.env.local`:**
   ```env
   FIREBASE_SERVICE_ACCOUNT_PATH=./firebase-service-account.json
   ```

3. **Update `.gitignore`** (if not already there):
   ```
   firebase-service-account.json
   ```

---

### **Step 5: Verify Setup**

1. **Restart Next.js server:**
   ```bash
   cd /Users/user/Desktop/PrepSkul/PrepSkul_Web
   pnpm dev
   ```

2. **Check logs for:**
   ```
   ✅ Firebase Admin initialized from service account key
   ```

3. **If you see errors:**
   - Check that the JSON is valid
   - Check that the path is correct (if using file path)
   - Check that the environment variable name is correct

---

## 🎯 **Recommended Approach**

**For Local Development:** Use **Option B (File Path)** - it's easier and less error-prone.

**For Production (Vercel):** Use **Option A (JSON String)** - Vercel works better with environment variables.

---

## 🔒 **Security Reminders**

- ✅ `.env.local` is already in `.gitignore` (won't be committed)
- ✅ Never commit the JSON file to git
- ✅ Never share the key publicly
- ✅ Keep it secure and private

---

**Once added, restart your Next.js server and push notifications will work! 🚀**

