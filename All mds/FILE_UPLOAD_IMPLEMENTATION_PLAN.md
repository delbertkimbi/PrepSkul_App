# 📸 File Upload Implementation Plan

**Goal:** Complete file upload integration in tutor onboarding before V1  
**Timeline:** 2-3 hours  
**Status:** IN PROGRESS

---

## 📋 **WHAT NEEDS TO BE ADDED**

### **1. State Variables (Add to `_TutorOnboardingScreenState`)**

```dart
// File upload states
File? _profilePhotoFile;
String? _profilePhotoUrl;
bool _isUploadingProfilePhoto = false;

File? _idCardFrontFile;
String? _idCardFrontUrl;
bool _isUploadingIdCardFront = false;

File? _idCardBackFile;
String? _idCardBackUrl;
bool _isUploadingIdCardBack = false;

Map<String, File> _certificateFiles = {}; // key: certificate name, value: File
Map<String, String> _certificateUrls = {}; // key: certificate name, value: URL
Map<String, bool> _uploadingCertificates = {}; // track upload progress
```

### **2. Import Required Packages**

```dart
import 'dart:io';
import 'package:file_picker/file_picker.dart';
import '../../core/widgets/image_picker_bottom_sheet.dart';
import '../../core/services/storage_service.dart';
import '../../core/services/auth_service.dart';
```

### **3. Upload Methods**

#### **Profile Photo Upload:**
```dart
Future<void> _uploadProfilePhoto() async {
  try {
    final File? image = await ImagePickerBottomSheet.show(
      context: context,
      fileType: FileType.image,
    );

    if (image == null) return;

    setState(() => _isUploadingProfilePhoto = true);

    // Get current user ID
    final userData = await AuthService.getCurrentUser();
    final userId = userData['userId'];

    // Upload to Supabase Storage
    final imageUrl = await StorageService.uploadProfilePhoto(
      userId: userId,
      file: image,
    );

    setState(() {
      _profilePhotoFile = image;
      _profilePhotoUrl = imageUrl;
      _isUploadingProfilePhoto = false;
    });

    // Auto-save
    await _saveData();

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Profile photo uploaded successfully!')),
    );
  } catch (e) {
    setState(() => _isUploadingProfilePhoto = false);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Failed to upload photo: $e')),
    );
  }
}
```

#### **Document Upload (ID Cards):**
```dart
Future<void> _uploadDocument(String documentType) async {
  try {
    final File? file = await ImagePickerBottomSheet.show(
      context: context,
      fileType: FileType.custom,
      allowedExtensions: ['pdf', 'jpg', 'jpeg', 'png'],
    );

    if (file == null) return;

    setState(() {
      if (documentType == 'id_card_front') {
        _isUploadingIdCardFront = true;
      } else if (documentType == 'id_card_back') {
        _isUploadingIdCardBack = true;
      }
    });

    final userData = await AuthService.getCurrentUser();
    final userId = userData['userId'];

    // Upload to Supabase Storage
    final docUrl = await StorageService.uploadDocument(
      userId: userId,
      file: file,
      category: documentType,
    );

    setState(() {
      if (documentType == 'id_card_front') {
        _idCardFrontFile = file;
        _idCardFrontUrl = docUrl;
        _isUploadingIdCardFront = false;
      } else if (documentType == 'id_card_back') {
        _idCardBackFile = file;
        _idCardBackUrl = docUrl;
        _isUploadingIdCardBack = false;
      }
    });

    await _saveData();

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('$documentType uploaded successfully!')),
    );
  } catch (e) {
    setState(() {
      if (documentType == 'id_card_front') {
        _isUploadingIdCardFront = false;
      } else if (documentType == 'id_card_back') {
        _isUploadingIdCardBack = false;
      }
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Failed to upload document: $e')),
    );
  }
}
```

#### **Certificate Upload:**
```dart
Future<void> _uploadCertificate(String certificateName) async {
  try {
    final File? file = await ImagePickerBottomSheet.show(
      context: context,
      fileType: FileType.custom,
      allowedExtensions: ['pdf', 'jpg', 'jpeg', 'png'],
    );

    if (file == null) return;

    setState(() => _uploadingCertificates[certificateName] = true);

    final userData = await AuthService.getCurrentUser();
    final userId = userData['userId'];

    final docUrl = await StorageService.uploadDocument(
      userId: userId,
      file: file,
      category: 'certificate_$certificateName',
    );

    setState(() {
      _certificateFiles[certificateName] = file;
      _certificateUrls[certificateName] = docUrl;
      _uploadingCertificates[certificateName] = false;
    });

    await _saveData();

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('$certificateName uploaded successfully!')),
    );
  } catch (e) {
    setState(() => _uploadingCertificates[certificateName] = false);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Failed to upload certificate: $e')),
    );
  }
}
```

### **4. Update Auto-Save to Include File URLs**

```dart
Future<void> _saveData() async {
  final prefs = await SharedPreferences.getInstance();
  final data = {
    // ... existing fields ...
    'profilePhotoUrl': _profilePhotoUrl,
    'idCardFrontUrl': _idCardFrontUrl,
    'idCardBackUrl': _idCardBackUrl,
    'certificateUrls': _certificateUrls,
  };
  await prefs.setString('tutor_onboarding_data', jsonEncode(data));
}
```

### **5. Update Submit Method to Include File URLs**

```dart
// In the final submission method
final tutorData = {
  // ... existing fields ...
  'profile_photo_url': _profilePhotoUrl,
  'id_card_front_url': _idCardFrontUrl,
  'id_card_back_url': _idCardBackUrl,
  'certifications': _certificateUrls.entries.map((e) => {
    'name': e.key,
    'url': e.value,
  }).toList(),
};
```

---

## 🎨 **UI UPDATES NEEDED**

### **Profile Photo Section:**
```dart
Widget _buildProfilePhotoUpload() {
  return Container(
    padding: EdgeInsets.all(20),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      border: Border.all(color: AppTheme.softBorder),
    ),
    child: Column(
      children: [
        // Preview or placeholder
        if (_profilePhotoFile != null)
          CircleAvatar(
            radius: 60,
            backgroundImage: FileImage(_profilePhotoFile!),
          )
        else
          CircleAvatar(
            radius: 60,
            backgroundColor: AppTheme.accentBlue.withOpacity(0.1),
            child: Icon(Icons.person, size: 60, color: AppTheme.accentBlue),
          ),
        
        SizedBox(height: 16),
        
        // Upload button
        ElevatedButton.icon(
          onPressed: _isUploadingProfilePhoto ? null : _uploadProfilePhoto,
          icon: _isUploadingProfilePhoto
              ? SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : Icon(Icons.upload),
          label: Text(_profilePhotoUrl != null ? 'Change Photo' : 'Upload Photo'),
        ),
        
        if (_profilePhotoUrl != null)
          Padding(
            padding: EdgeInsets.only(top: 8),
            child: Text(
              '✓ Photo uploaded',
              style: TextStyle(color: Colors.green),
            ),
          ),
      ],
    ),
  );
}
```

### **Document Upload Card:**
```dart
Widget _buildDocumentUploadCard({
  required String title,
  required String description,
  required String documentType,
  required bool isUploading,
  required String? fileUrl,
}) {
  return Container(
    padding: EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      border: Border.all(color: AppTheme.softBorder),
    ),
    child: Row(
      children: [
        Icon(
          fileUrl != null ? Icons.check_circle : Icons.description,
          color: fileUrl != null ? Colors.green : AppTheme.accentBlue,
          size: 32,
        ),
        SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
              Text(description, style: GoogleFonts.poppins(fontSize: 12)),
              if (fileUrl != null)
                Text(
                  '✓ Uploaded',
                  style: TextStyle(color: Colors.green, fontSize: 12),
                ),
            ],
          ),
        ),
        ElevatedButton(
          onPressed: isUploading ? null : () => _uploadDocument(documentType),
          child: isUploading
              ? SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : Text(fileUrl != null ? 'Replace' : 'Upload'),
        ),
      ],
    ),
  );
}
```

---

## ✅ **IMPLEMENTATION CHECKLIST**

### **Step 1: Add Imports**
- [ ] Add `dart:io`
- [ ] Add `file_picker` import
- [ ] Add `ImagePickerBottomSheet` import
- [ ] Add `StorageService` import

### **Step 2: Add State Variables**
- [ ] Add profile photo states
- [ ] Add ID card states
- [ ] Add certificate states
- [ ] Add upload progress states

### **Step 3: Add Upload Methods**
- [ ] Implement `_uploadProfilePhoto()`
- [ ] Implement `_uploadDocument()`
- [ ] Implement `_uploadCertificate()`

### **Step 4: Update UI**
- [ ] Update profile photo section with upload button
- [ ] Update ID card sections with upload buttons
- [ ] Update certificate sections with upload buttons
- [ ] Add progress indicators
- [ ] Add file previews

### **Step 5: Update Auto-Save**
- [ ] Save file URLs in `_saveData()`
- [ ] Load file URLs in `_loadSavedData()`

### **Step 6: Update Submit**
- [ ] Include file URLs in final tutor data submission
- [ ] Save to `tutor_profiles` table via `SurveyRepository`

### **Step 7: Test**
- [ ] Test profile photo upload
- [ ] Test ID card uploads
- [ ] Test certificate uploads
- [ ] Verify files in Supabase Storage
- [ ] Verify URLs in database

---

## 🚀 **LET'S START IMPLEMENTATION!**

Ready to implement? This will take about 2-3 hours to complete properly.

