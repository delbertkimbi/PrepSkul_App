# 📸 STORAGE SERVICE - USAGE EXAMPLES

## ✅ **What's Been Created:**

### **Files:**
1. ✅ `lib/core/services/storage_service.dart` - Complete file upload service
2. ✅ `lib/core/widgets/image_picker_bottom_sheet.dart` - Beautiful image picker UI
3. ✅ `STORAGE_SETUP_GUIDE.md` - Supabase setup instructions
4. ✅ Added packages: `image_picker`, `file_picker`, `path`, `mime`

### **Features:**
- ✅ Upload profile photos
- ✅ Upload documents (PDF, images)
- ✅ Upload videos
- ✅ Pick from gallery or camera
- ✅ File validation (size, type)
- ✅ Progress tracking support
- ✅ Delete files
- ✅ Get file URLs

---

## 🚀 **STEP 1: Setup Supabase Buckets**

Follow the `STORAGE_SETUP_GUIDE.md`:
1. Create 3 buckets in Supabase dashboard
2. Configure RLS policies
3. Test upload from dashboard

---

## 🚀 **STEP 2: Run Flutter Pub Get**

```bash
cd /Users/user/Desktop/PrepSkul/prepskul_app
flutter pub get
```

---

## 📱 **USAGE EXAMPLES:**

### **Example 1: Upload Profile Photo**

```dart
import 'package:flutter/material.dart';
import '../core/services/storage_service.dart';
import '../core/services/auth_service.dart';
import '../core/widgets/image_picker_bottom_sheet.dart';

class ProfilePhotoUpload extends StatefulWidget {
  @override
  State<ProfilePhotoUpload> createState() => _ProfilePhotoUploadState();
}

class _ProfilePhotoUploadState extends State<ProfilePhotoUpload> {
  String? _photoUrl;
  bool _isUploading = false;

  Future<void> _uploadProfilePhoto() async {
    // Show image picker
    final imageFile = await ImagePickerBottomSheet.show(context);
    
    if (imageFile == null) return;

    setState(() => _isUploading = true);

    try {
      // Get current user ID
      final userId = await AuthService.getUserId();
      if (userId == null) throw Exception('User not logged in');

      // Upload to Supabase
      final photoUrl = await StorageService.uploadProfilePhoto(
        userId: userId,
        imageFile: imageFile,
        fileName: 'avatar.jpg',
      );

      setState(() {
        _photoUrl = photoUrl;
        _isUploading = false;
      });

      // Show success message
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Profile photo uploaded successfully!')),
      );
    } catch (e) {
      setState(() => _isUploading = false);
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: ${e.toString()}')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Display photo
        CircleAvatar(
          radius: 60,
          backgroundImage: _photoUrl != null 
            ? NetworkImage(_photoUrl!) 
            : null,
          child: _photoUrl == null 
            ? Icon(Icons.person, size: 60) 
            : null,
        ),
        
        SizedBox(height: 16),
        
        // Upload button
        ElevatedButton.icon(
          onPressed: _isUploading ? null : _uploadProfilePhoto,
          icon: _isUploading 
            ? SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : Icon(Icons.camera_alt),
          label: Text(_isUploading ? 'Uploading...' : 'Change Photo'),
        ),
      ],
    );
  }
}
```

---

### **Example 2: Upload Document (ID Card, Degree)**

```dart
Future<void> _uploadDocument(String documentType) async {
  setState(() => _isUploading = true);

  try {
    // Pick document
    final documentFile = await StorageService.pickDocument();
    
    if (documentFile == null) {
      setState(() => _isUploading = false);
      return;
    }

    // Get user ID
    final userId = await AuthService.getUserId();
    if (userId == null) throw Exception('User not logged in');

    // Upload document
    final documentUrl = await StorageService.uploadDocument(
      userId: userId,
      documentFile: documentFile,
      documentType: documentType, // e.g., 'id_front', 'degree'
    );

    setState(() {
      _uploadedDocs[documentType] = documentUrl;
      _isUploading = false;
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Document uploaded successfully!')),
    );
  } catch (e) {
    setState(() => _isUploading = false);
    
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Error: ${e.toString()}')),
    );
  }
}

// Usage:
ElevatedButton(
  onPressed: () => _uploadDocument('id_front'),
  child: Text('Upload ID Card Front'),
)
```

---

### **Example 3: Upload Video Introduction**

```dart
Future<void> _uploadVideo() async {
  setState(() => _isUploading = true);

  try {
    // Pick video
    final videoFile = await StorageService.pickVideo();
    
    if (videoFile == null) {
      setState(() => _isUploading = false);
      return;
    }

    // Check file size
    final sizeInMB = await StorageService.getFileSizeInMB(videoFile);
    if (sizeInMB > 50) {
      throw Exception('Video too large. Maximum size is 50 MB');
    }

    // Get user ID
    final userId = await AuthService.getUserId();
    if (userId == null) throw Exception('User not logged in');

    // Upload video
    final videoUrl = await StorageService.uploadVideo(
      userId: userId,
      videoFile: videoFile,
      fileName: 'intro.mp4',
    );

    setState(() {
      _videoUrl = videoUrl;
      _isUploading = false;
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Video uploaded successfully!')),
    );
  } catch (e) {
    setState(() => _isUploading = false);
    
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Error: ${e.toString()}')),
    );
  }
}
```

---

### **Example 4: Document Upload Card (For Tutor Onboarding)**

```dart
Widget _buildDocumentUploadCard({
  required String documentType,
  required String title,
  required String description,
}) {
  final isUploaded = _uploadedDocs.containsKey(documentType);

  return Container(
    margin: EdgeInsets.only(bottom: 16),
    padding: EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(12),
      border: Border.all(
        color: isUploaded ? Colors.green : AppTheme.softBorder,
      ),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(
              isUploaded ? Icons.check_circle : Icons.upload_file,
              color: isUploaded ? Colors.green : AppTheme.primaryColor,
            ),
            SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: GoogleFonts.poppins(
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                    ),
                  ),
                  Text(
                    description,
                    style: GoogleFonts.poppins(
                      fontSize: 12,
                      color: AppTheme.textMedium,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        
        SizedBox(height: 12),
        
        ElevatedButton.icon(
          onPressed: () => _uploadDocument(documentType),
          icon: Icon(isUploaded ? Icons.refresh : Icons.upload),
          label: Text(isUploaded ? 'Replace' : 'Upload'),
          style: ElevatedButton.styleFrom(
            backgroundColor: isUploaded ? Colors.grey : AppTheme.primaryColor,
          ),
        ),
        
        if (isUploaded)
          Padding(
            padding: EdgeInsets.only(top: 8),
            child: Text(
              '✓ Uploaded successfully',
              style: GoogleFonts.poppins(
                fontSize: 12,
                color: Colors.green,
              ),
            ),
          ),
      ],
    ),
  );
}

// Usage:
_buildDocumentUploadCard(
  documentType: 'id_front',
  title: 'ID Card (Front)',
  description: 'Upload the front side of your ID card',
)
```

---

### **Example 5: With Progress Indicator**

```dart
double _uploadProgress = 0.0;

Future<void> _uploadWithProgress() async {
  try {
    final file = await StorageService.pickDocument();
    if (file == null) return;

    final userId = await AuthService.getUserId();
    if (userId == null) throw Exception('User not logged in');

    final url = await StorageService.uploadWithProgress(
      bucket: StorageService.documentsBucket,
      file: file,
      storagePath: '$userId/document.pdf',
      onProgress: (progress) {
        setState(() => _uploadProgress = progress);
      },
    );

    print('File uploaded: $url');
  } catch (e) {
    print('Error: $e');
  }
}

// UI:
if (_uploadProgress > 0 && _uploadProgress < 1)
  LinearProgressIndicator(value: _uploadProgress)
```

---

## 🔧 **HELPER METHODS:**

### **Check File Type:**
```dart
// Check if file is an image
final isImage = StorageService.isImage(file);

// Check if file is PDF
final isPDF = StorageService.isPDF(file);

// Check if file is video
final isVideo = StorageService.isVideo(file);
```

### **Get File Info:**
```dart
// Get file size in MB
final sizeInMB = await StorageService.getFileSizeInMB(file);

// Get file extension
final extension = StorageService.getFileExtension(file);
```

### **Delete File:**
```dart
await StorageService.deleteFile(
  bucket: StorageService.profilePhotosBucket,
  filePath: '$userId/avatar.jpg',
);
```

---

## 🎨 **INTEGRATION WITH TUTOR ONBOARDING:**

Replace the existing `_uploadDocument` method in `tutor_onboarding_screen.dart`:

```dart
void _uploadDocument(String documentType) async {
  final file = await StorageService.pickDocument();
  if (file == null) return;

  setState(() => _isUploading = true);

  try {
    final userId = await AuthService.getUserId();
    if (userId == null) throw Exception('User not logged in');

    final url = await StorageService.uploadDocument(
      userId: userId,
      documentFile: file,
      documentType: documentType,
    );

    setState(() {
      _uploadedDocuments[documentType] = {
        'url': url,
        'name': documentType,
        'uploadedAt': DateTime.now().toIso8601String(),
      };
      _isUploading = false;
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Document uploaded successfully!'),
        backgroundColor: Colors.green,
      ),
    );
  } catch (e) {
    setState(() => _isUploading = false);
    
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Error: ${e.toString()}'),
        backgroundColor: Colors.red,
      ),
    );
  }
}
```

---

## 📋 **PERMISSIONS (iOS/Android):**

### **iOS (ios/Runner/Info.plist):**
```xml
<key>NSPhotoLibraryUsageDescription</key>
<string>We need access to your photo library to upload profile pictures</string>

<key>NSCameraUsageDescription</key>
<string>We need access to your camera to take profile pictures</string>

<key>NSMicrophoneUsageDescription</key>
<string>We need access to your microphone for video recording</string>
```

### **Android (android/app/src/main/AndroidManifest.xml):**
```xml
<uses-permission android:name="android.permission.CAMERA" />
<uses-permission android:name="android.permission.READ_EXTERNAL_STORAGE" />
<uses-permission android:name="android.permission.WRITE_EXTERNAL_STORAGE" />
```

---

## ✅ **NEXT STEPS:**

1. ✅ **Setup Supabase buckets** (follow `STORAGE_SETUP_GUIDE.md`)
2. ✅ **Run `flutter pub get`**
3. ✅ **Add permissions to iOS/Android**
4. ✅ **Test image picker** in a simple screen
5. ✅ **Integrate with tutor onboarding**

---

## 🎯 **READY TO USE!**

The storage service is complete and ready to use. Just:
1. Setup the buckets in Supabase
2. Run `flutter pub get`
3. Add iOS/Android permissions
4. Start using the examples above!

**Any questions?** 🚀



## ✅ **What's Been Created:**

### **Files:**
1. ✅ `lib/core/services/storage_service.dart` - Complete file upload service
2. ✅ `lib/core/widgets/image_picker_bottom_sheet.dart` - Beautiful image picker UI
3. ✅ `STORAGE_SETUP_GUIDE.md` - Supabase setup instructions
4. ✅ Added packages: `image_picker`, `file_picker`, `path`, `mime`

### **Features:**
- ✅ Upload profile photos
- ✅ Upload documents (PDF, images)
- ✅ Upload videos
- ✅ Pick from gallery or camera
- ✅ File validation (size, type)
- ✅ Progress tracking support
- ✅ Delete files
- ✅ Get file URLs

---

## 🚀 **STEP 1: Setup Supabase Buckets**

Follow the `STORAGE_SETUP_GUIDE.md`:
1. Create 3 buckets in Supabase dashboard
2. Configure RLS policies
3. Test upload from dashboard

---

## 🚀 **STEP 2: Run Flutter Pub Get**

```bash
cd /Users/user/Desktop/PrepSkul/prepskul_app
flutter pub get
```

---

## 📱 **USAGE EXAMPLES:**

### **Example 1: Upload Profile Photo**

```dart
import 'package:flutter/material.dart';
import '../core/services/storage_service.dart';
import '../core/services/auth_service.dart';
import '../core/widgets/image_picker_bottom_sheet.dart';

class ProfilePhotoUpload extends StatefulWidget {
  @override
  State<ProfilePhotoUpload> createState() => _ProfilePhotoUploadState();
}

class _ProfilePhotoUploadState extends State<ProfilePhotoUpload> {
  String? _photoUrl;
  bool _isUploading = false;

  Future<void> _uploadProfilePhoto() async {
    // Show image picker
    final imageFile = await ImagePickerBottomSheet.show(context);
    
    if (imageFile == null) return;

    setState(() => _isUploading = true);

    try {
      // Get current user ID
      final userId = await AuthService.getUserId();
      if (userId == null) throw Exception('User not logged in');

      // Upload to Supabase
      final photoUrl = await StorageService.uploadProfilePhoto(
        userId: userId,
        imageFile: imageFile,
        fileName: 'avatar.jpg',
      );

      setState(() {
        _photoUrl = photoUrl;
        _isUploading = false;
      });

      // Show success message
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Profile photo uploaded successfully!')),
      );
    } catch (e) {
      setState(() => _isUploading = false);
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: ${e.toString()}')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Display photo
        CircleAvatar(
          radius: 60,
          backgroundImage: _photoUrl != null 
            ? NetworkImage(_photoUrl!) 
            : null,
          child: _photoUrl == null 
            ? Icon(Icons.person, size: 60) 
            : null,
        ),
        
        SizedBox(height: 16),
        
        // Upload button
        ElevatedButton.icon(
          onPressed: _isUploading ? null : _uploadProfilePhoto,
          icon: _isUploading 
            ? SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : Icon(Icons.camera_alt),
          label: Text(_isUploading ? 'Uploading...' : 'Change Photo'),
        ),
      ],
    );
  }
}
```

---

### **Example 2: Upload Document (ID Card, Degree)**

```dart
Future<void> _uploadDocument(String documentType) async {
  setState(() => _isUploading = true);

  try {
    // Pick document
    final documentFile = await StorageService.pickDocument();
    
    if (documentFile == null) {
      setState(() => _isUploading = false);
      return;
    }

    // Get user ID
    final userId = await AuthService.getUserId();
    if (userId == null) throw Exception('User not logged in');

    // Upload document
    final documentUrl = await StorageService.uploadDocument(
      userId: userId,
      documentFile: documentFile,
      documentType: documentType, // e.g., 'id_front', 'degree'
    );

    setState(() {
      _uploadedDocs[documentType] = documentUrl;
      _isUploading = false;
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Document uploaded successfully!')),
    );
  } catch (e) {
    setState(() => _isUploading = false);
    
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Error: ${e.toString()}')),
    );
  }
}

// Usage:
ElevatedButton(
  onPressed: () => _uploadDocument('id_front'),
  child: Text('Upload ID Card Front'),
)
```

---

### **Example 3: Upload Video Introduction**

```dart
Future<void> _uploadVideo() async {
  setState(() => _isUploading = true);

  try {
    // Pick video
    final videoFile = await StorageService.pickVideo();
    
    if (videoFile == null) {
      setState(() => _isUploading = false);
      return;
    }

    // Check file size
    final sizeInMB = await StorageService.getFileSizeInMB(videoFile);
    if (sizeInMB > 50) {
      throw Exception('Video too large. Maximum size is 50 MB');
    }

    // Get user ID
    final userId = await AuthService.getUserId();
    if (userId == null) throw Exception('User not logged in');

    // Upload video
    final videoUrl = await StorageService.uploadVideo(
      userId: userId,
      videoFile: videoFile,
      fileName: 'intro.mp4',
    );

    setState(() {
      _videoUrl = videoUrl;
      _isUploading = false;
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Video uploaded successfully!')),
    );
  } catch (e) {
    setState(() => _isUploading = false);
    
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Error: ${e.toString()}')),
    );
  }
}
```

---

### **Example 4: Document Upload Card (For Tutor Onboarding)**

```dart
Widget _buildDocumentUploadCard({
  required String documentType,
  required String title,
  required String description,
}) {
  final isUploaded = _uploadedDocs.containsKey(documentType);

  return Container(
    margin: EdgeInsets.only(bottom: 16),
    padding: EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(12),
      border: Border.all(
        color: isUploaded ? Colors.green : AppTheme.softBorder,
      ),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(
              isUploaded ? Icons.check_circle : Icons.upload_file,
              color: isUploaded ? Colors.green : AppTheme.primaryColor,
            ),
            SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: GoogleFonts.poppins(
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                    ),
                  ),
                  Text(
                    description,
                    style: GoogleFonts.poppins(
                      fontSize: 12,
                      color: AppTheme.textMedium,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        
        SizedBox(height: 12),
        
        ElevatedButton.icon(
          onPressed: () => _uploadDocument(documentType),
          icon: Icon(isUploaded ? Icons.refresh : Icons.upload),
          label: Text(isUploaded ? 'Replace' : 'Upload'),
          style: ElevatedButton.styleFrom(
            backgroundColor: isUploaded ? Colors.grey : AppTheme.primaryColor,
          ),
        ),
        
        if (isUploaded)
          Padding(
            padding: EdgeInsets.only(top: 8),
            child: Text(
              '✓ Uploaded successfully',
              style: GoogleFonts.poppins(
                fontSize: 12,
                color: Colors.green,
              ),
            ),
          ),
      ],
    ),
  );
}

// Usage:
_buildDocumentUploadCard(
  documentType: 'id_front',
  title: 'ID Card (Front)',
  description: 'Upload the front side of your ID card',
)
```

---

### **Example 5: With Progress Indicator**

```dart
double _uploadProgress = 0.0;

Future<void> _uploadWithProgress() async {
  try {
    final file = await StorageService.pickDocument();
    if (file == null) return;

    final userId = await AuthService.getUserId();
    if (userId == null) throw Exception('User not logged in');

    final url = await StorageService.uploadWithProgress(
      bucket: StorageService.documentsBucket,
      file: file,
      storagePath: '$userId/document.pdf',
      onProgress: (progress) {
        setState(() => _uploadProgress = progress);
      },
    );

    print('File uploaded: $url');
  } catch (e) {
    print('Error: $e');
  }
}

// UI:
if (_uploadProgress > 0 && _uploadProgress < 1)
  LinearProgressIndicator(value: _uploadProgress)
```

---

## 🔧 **HELPER METHODS:**

### **Check File Type:**
```dart
// Check if file is an image
final isImage = StorageService.isImage(file);

// Check if file is PDF
final isPDF = StorageService.isPDF(file);

// Check if file is video
final isVideo = StorageService.isVideo(file);
```

### **Get File Info:**
```dart
// Get file size in MB
final sizeInMB = await StorageService.getFileSizeInMB(file);

// Get file extension
final extension = StorageService.getFileExtension(file);
```

### **Delete File:**
```dart
await StorageService.deleteFile(
  bucket: StorageService.profilePhotosBucket,
  filePath: '$userId/avatar.jpg',
);
```

---

## 🎨 **INTEGRATION WITH TUTOR ONBOARDING:**

Replace the existing `_uploadDocument` method in `tutor_onboarding_screen.dart`:

```dart
void _uploadDocument(String documentType) async {
  final file = await StorageService.pickDocument();
  if (file == null) return;

  setState(() => _isUploading = true);

  try {
    final userId = await AuthService.getUserId();
    if (userId == null) throw Exception('User not logged in');

    final url = await StorageService.uploadDocument(
      userId: userId,
      documentFile: file,
      documentType: documentType,
    );

    setState(() {
      _uploadedDocuments[documentType] = {
        'url': url,
        'name': documentType,
        'uploadedAt': DateTime.now().toIso8601String(),
      };
      _isUploading = false;
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Document uploaded successfully!'),
        backgroundColor: Colors.green,
      ),
    );
  } catch (e) {
    setState(() => _isUploading = false);
    
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Error: ${e.toString()}'),
        backgroundColor: Colors.red,
      ),
    );
  }
}
```

---

## 📋 **PERMISSIONS (iOS/Android):**

### **iOS (ios/Runner/Info.plist):**
```xml
<key>NSPhotoLibraryUsageDescription</key>
<string>We need access to your photo library to upload profile pictures</string>

<key>NSCameraUsageDescription</key>
<string>We need access to your camera to take profile pictures</string>

<key>NSMicrophoneUsageDescription</key>
<string>We need access to your microphone for video recording</string>
```

### **Android (android/app/src/main/AndroidManifest.xml):**
```xml
<uses-permission android:name="android.permission.CAMERA" />
<uses-permission android:name="android.permission.READ_EXTERNAL_STORAGE" />
<uses-permission android:name="android.permission.WRITE_EXTERNAL_STORAGE" />
```

---

## ✅ **NEXT STEPS:**

1. ✅ **Setup Supabase buckets** (follow `STORAGE_SETUP_GUIDE.md`)
2. ✅ **Run `flutter pub get`**
3. ✅ **Add permissions to iOS/Android**
4. ✅ **Test image picker** in a simple screen
5. ✅ **Integrate with tutor onboarding**

---

## 🎯 **READY TO USE!**

The storage service is complete and ready to use. Just:
1. Setup the buckets in Supabase
2. Run `flutter pub get`
3. Add iOS/Android permissions
4. Start using the examples above!

**Any questions?** 🚀

