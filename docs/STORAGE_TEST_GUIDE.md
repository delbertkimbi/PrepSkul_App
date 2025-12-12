# 📸 **Storage Test Guide**

## ✅ **Setup Complete!**

You've successfully set up Supabase Storage with:
- ✅ `profile-photos` bucket (public)
- ✅ `documents` bucket (private)
- ✅ RLS policies for security
- ✅ `StorageService` for file operations
- ✅ `ImagePickerBottomSheet` for easy file selection

---

## 🧪 **How to Test**

### **Step 1: Run the App**
```bash
flutter run -d macos
```

### **Step 2: Login/Signup**
1. Complete the signup flow with phone OTP
2. Fill out the survey (tutor, student, or parent)
3. You'll land on the respective dashboard

### **Step 3: Access Storage Test**
1. On the **Tutor Dashboard**, scroll down
2. Click the orange **"Test Storage (Dev Only)"** button
3. You'll be taken to the Storage Test screen

### **Step 4: Test Upload**
1. Click **"Pick & Upload Image"**
2. Choose between:
   - 📸 **Camera** (take a photo)
   - 🖼️ **Gallery** (choose existing photo)
3. Wait for upload progress (50% indicator)
4. Image will appear with:
   - Full preview
   - File path
   - Public URL (working)

### **Step 5: Test Delete**
1. Click **"Delete Image"** button
2. Image should be removed from storage
3. UI resets to empty state

---

## 🔍 **What to Check**

### ✅ **Upload Success Indicators:**
- Green snackbar: "Image uploaded successfully!"
- Image displays in the preview
- File path shows: `{userId}/profile_xxxxx.jpg`
- No errors in console

### ✅ **Security Check:**
- Files are uploaded to user's own folder (`{userId}/...`)
- Only authenticated users can upload
- Each user can only delete their own files

### ❌ **Common Errors & Fixes:**

| Error | Cause | Fix |
|-------|-------|-----|
| "Image too large" | File > 5MB | Choose smaller image |
| "Invalid file type" | Not an image | Select JPG/PNG |
| "Network error" | No internet | Check connection |
| "Unauthorized" | RLS policy issue | Check Supabase policies |

---

## 📱 **File Picker Options**

The `ImagePickerBottomSheet` provides:
- 📷 **Camera**: `StorageService.pickImageFromCamera()`
- 🖼️ **Gallery**: `StorageService.pickImageFromGallery()`
- 📄 **Documents**: `StorageService.pickDocument()` (PDF, images)
- 🎥 **Videos**: `StorageService.pickVideo()` (skipped for now)

---

## 🔐 **Security Features**

### **Folder Structure:**
```
profile-photos/
  └── {user-id-1}/
      ├── profile_1234567890.jpg
      └── avatar.jpg
  └── {user-id-2}/
      ├── profile_9876543210.jpg
      └── avatar.jpg

documents/
  └── {user-id-1}/
      ├── id_front.pdf
      └── degree.jpg
```

### **RLS Policies:**
- ✅ Users can only upload to their own folder
- ✅ Users can only delete their own files
- ✅ Profile photos are publicly viewable
- ✅ Documents are private (only owner can view)

---

## 🚀 **Next Steps**

After confirming storage works:

1. **Remove Test Button** from tutor dashboard
2. **Integrate Upload** into:
   - Tutor profile setup (avatar, documents)
   - Student profile (avatar)
   - Parent profile (avatar)
3. **Document Upload** in tutor verification flow
4. **Profile Photo Display** in all dashboards

---

## 📝 **Code Example**

To use storage in any screen:

```dart
import '../core/services/storage_service.dart';
import '../core/widgets/image_picker_bottom_sheet.dart';

// Pick and upload
final file = await ImagePickerBottomSheet.show(context);
if (file != null) {
  final url = await StorageService.uploadProfilePhoto(
    userId: currentUserId,
    imageFile: file,
  );
  // Use url to display image or save to database
}
```

---

## 🎯 **Success Criteria**

- [ ] Can pick image from camera
- [ ] Can pick image from gallery
- [ ] Image uploads successfully
- [ ] Image displays in preview
- [ ] Can delete uploaded image
- [ ] No errors in console
- [ ] File path follows `{userId}/filename.jpg` format
- [ ] Public URL works when pasted in browser

---

**Test completed? Type "storage test passed" to continue!** ✅



## ✅ **Setup Complete!**

You've successfully set up Supabase Storage with:
- ✅ `profile-photos` bucket (public)
- ✅ `documents` bucket (private)
- ✅ RLS policies for security
- ✅ `StorageService` for file operations
- ✅ `ImagePickerBottomSheet` for easy file selection

---

## 🧪 **How to Test**

### **Step 1: Run the App**
```bash
flutter run -d macos
```

### **Step 2: Login/Signup**
1. Complete the signup flow with phone OTP
2. Fill out the survey (tutor, student, or parent)
3. You'll land on the respective dashboard

### **Step 3: Access Storage Test**
1. On the **Tutor Dashboard**, scroll down
2. Click the orange **"Test Storage (Dev Only)"** button
3. You'll be taken to the Storage Test screen

### **Step 4: Test Upload**
1. Click **"Pick & Upload Image"**
2. Choose between:
   - 📸 **Camera** (take a photo)
   - 🖼️ **Gallery** (choose existing photo)
3. Wait for upload progress (50% indicator)
4. Image will appear with:
   - Full preview
   - File path
   - Public URL (working)

### **Step 5: Test Delete**
1. Click **"Delete Image"** button
2. Image should be removed from storage
3. UI resets to empty state

---

## 🔍 **What to Check**

### ✅ **Upload Success Indicators:**
- Green snackbar: "Image uploaded successfully!"
- Image displays in the preview
- File path shows: `{userId}/profile_xxxxx.jpg`
- No errors in console

### ✅ **Security Check:**
- Files are uploaded to user's own folder (`{userId}/...`)
- Only authenticated users can upload
- Each user can only delete their own files

### ❌ **Common Errors & Fixes:**

| Error | Cause | Fix |
|-------|-------|-----|
| "Image too large" | File > 5MB | Choose smaller image |
| "Invalid file type" | Not an image | Select JPG/PNG |
| "Network error" | No internet | Check connection |
| "Unauthorized" | RLS policy issue | Check Supabase policies |

---

## 📱 **File Picker Options**

The `ImagePickerBottomSheet` provides:
- 📷 **Camera**: `StorageService.pickImageFromCamera()`
- 🖼️ **Gallery**: `StorageService.pickImageFromGallery()`
- 📄 **Documents**: `StorageService.pickDocument()` (PDF, images)
- 🎥 **Videos**: `StorageService.pickVideo()` (skipped for now)

---

## 🔐 **Security Features**

### **Folder Structure:**
```
profile-photos/
  └── {user-id-1}/
      ├── profile_1234567890.jpg
      └── avatar.jpg
  └── {user-id-2}/
      ├── profile_9876543210.jpg
      └── avatar.jpg

documents/
  └── {user-id-1}/
      ├── id_front.pdf
      └── degree.jpg
```

### **RLS Policies:**
- ✅ Users can only upload to their own folder
- ✅ Users can only delete their own files
- ✅ Profile photos are publicly viewable
- ✅ Documents are private (only owner can view)

---

## 🚀 **Next Steps**

After confirming storage works:

1. **Remove Test Button** from tutor dashboard
2. **Integrate Upload** into:
   - Tutor profile setup (avatar, documents)
   - Student profile (avatar)
   - Parent profile (avatar)
3. **Document Upload** in tutor verification flow
4. **Profile Photo Display** in all dashboards

---

## 📝 **Code Example**

To use storage in any screen:

```dart
import '../core/services/storage_service.dart';
import '../core/widgets/image_picker_bottom_sheet.dart';

// Pick and upload
final file = await ImagePickerBottomSheet.show(context);
if (file != null) {
  final url = await StorageService.uploadProfilePhoto(
    userId: currentUserId,
    imageFile: file,
  );
  // Use url to display image or save to database
}
```

---

## 🎯 **Success Criteria**

- [ ] Can pick image from camera
- [ ] Can pick image from gallery
- [ ] Image uploads successfully
- [ ] Image displays in preview
- [ ] Can delete uploaded image
- [ ] No errors in console
- [ ] File path follows `{userId}/filename.jpg` format
- [ ] Public URL works when pasted in browser

---

**Test completed? Type "storage test passed" to continue!** ✅

