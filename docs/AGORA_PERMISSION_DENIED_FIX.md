# 🔒 Agora Permission Denied Error - Quick Fix Guide

## 🔴 Error You're Seeing

```
NotAllowedError: Permission denied
at createMicrophoneAudioTrack
at createCameraVideoTrack
```

This means your browser is **blocking camera and microphone access**.

## ✅ Quick Fix (3 Steps)

### Step 1: Find the Permission Icon
Look at your browser's **address bar** (where the URL is):
- **Chrome/Edge**: Look for a camera/microphone icon (🎥 or 🎤) or padlock icon (🔒)
- **Firefox**: Look for a padlock icon (🔒)

### Step 2: Allow Permissions
1. **Click the icon** in the address bar
2. In the popup, find **"Camera"** and **"Microphone"**
3. Set both to **"Allow"** (not "Ask" or "Block")
4. Close the popup

### Step 3: Refresh and Retry
1. **Refresh the page** (press `F5` or `Ctrl+R` / `Cmd+R`)
2. Try joining the session again
3. When the browser prompts, click **"Allow"** for both camera and microphone

## 🔧 If You Don't See the Icon

### Chrome/Edge:
1. Click the **padlock icon** (🔒) in the address bar
2. Click **"Site settings"**
3. Find **"Camera"** and **"Microphone"**
4. Set both to **"Allow"**
5. Refresh the page

### Firefox:
1. Click the **padlock icon** (🔒) in the address bar
2. Click **"More Information"** or **"Permissions"**
3. Find **"Use Camera"** and **"Use Microphone"**
4. Set both to **"Allow"**
5. Refresh the page

## 🔄 Reset Permissions (If Still Not Working)

### Chrome/Edge:
1. Click the camera/mic icon in address bar
2. Click **"Reset permissions"** button
3. Refresh the page
4. When prompted, click **"Allow"** for both

### Or via Settings:
1. Go to `chrome://settings/content/camera` (Chrome) or `edge://settings/content/camera` (Edge)
2. Find your site (`app.prepskul.com`)
3. Remove it from the list
4. Refresh the page
5. When prompted, click **"Allow"**

## 📋 Checklist

- [ ] Found the camera/microphone icon in address bar
- [ ] Set Camera to "Allow"
- [ ] Set Microphone to "Allow"
- [ ] Refreshed the page
- [ ] Clicked "Allow" when browser prompted
- [ ] Tried joining the session again

## ⚠️ Common Issues

### Issue 1: No Permission Prompt Appears
**Cause**: Permissions were previously denied  
**Fix**: Reset permissions (see above) and refresh

### Issue 2: Camera/Mic Already in Use
**Cause**: Another app or browser tab is using the camera  
**Fix**: 
- Close Zoom, Teams, Skype, etc.
- Close other browser tabs using camera
- Try again

### Issue 3: Still Getting Error After Allowing
**Cause**: Browser needs a full refresh  
**Fix**: 
- Close the browser tab completely
- Open a new tab
- Navigate to the app again
- Try joining

## 🎯 Expected Behavior After Fix

1. ✅ Browser shows permission prompt when joining
2. ✅ You click "Allow" for camera and microphone
3. ✅ Session connects successfully
4. ✅ Video and audio work properly

## 💡 Pro Tips

- **Use HTTPS**: Some browsers require HTTPS for camera/mic access
- **Check Browser Settings**: Make sure camera/mic aren't globally blocked
- **Try Incognito Mode**: If permissions are stuck, try incognito/private mode
- **Check System Settings**: On Windows/Mac, ensure camera/mic aren't blocked at OS level

---

**After fixing permissions, refresh the page and try joining the session again!**

