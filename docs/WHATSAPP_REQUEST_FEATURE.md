# WhatsApp Tutor Request Feature

## Overview
When students or parents can't find a tutor using the search filters in the Find Tutors screen, they can now request a tutor via WhatsApp. The feature sends a detailed, automatically formatted message to **+237 6 53 30 19 97** with all relevant information.

## How It Works

### 1. **Trigger**
- Appears when "No tutors found" state is shown
- User clicks "Request Tutor via WhatsApp" button (green outlined button with WhatsApp icon)

### 2. **Data Collection**
The system automatically gathers:
- **User Profile**: Name, Role (Student/Parent)
- **Survey Data**: All information from completed student/parent survey
- **Search Filters**: Current filters being used in the search

### 3. **Message Format**
The WhatsApp message is automatically formatted with clear sections:

```
🎓 *PrepSkul Tutor Request*

Hello! I'm looking for a tutor.

👤 *Personal Information:*
• Name: [User Name]
• Role: [Student/Parent]

📍 *Location:*
• City: [City Name]
• Quarter: [Quarter Name]

📚 *Learning Details:*
• Learning Path: [Academic/Skills/Exam Prep]
• Education Level: [Primary/Secondary/University]
• Class: [Class Name]
• Stream: [Arts/Science/etc]
• Subjects: [Subject 1, Subject 2, ...]

📝 *Exam Preparation:* (if applicable)
• Exam Type: [GCE O/A Level, BEPC, etc]
• Specific Exam: [Exam name]
• Exam Subjects: [Subject list]

💰 *Budget:*
• Range: [Min] - [Max] XAF per session

⚙️ *Preferences:*
• Tutor Gender: [Male/Female/No preference]
• Qualification: [Student/Graduate/Professional]
• Location: [Home/Tutor's place/Library/etc]
• Schedule: [Weekday mornings/evenings/Weekends/etc]

🎯 *Learning Goals:*
• [Goal 1, Goal 2, ...]

⚠️ *Challenges:*
• [Challenge 1, Challenge 2, ...]

🔍 *Current Search Filters:*
• Search: [Search term]
• Subject: [Selected subject]
• Price Range: [Selected range]
• Minimum Rating: [X+ stars]

---
Please help me find a suitable tutor. Thank you! 🙏
```

## Technical Implementation

### Files Modified
- **`lib/features/discovery/screens/find_tutors_screen.dart`**
  - Added imports: `auth_service.dart`, `survey_repository.dart`, `url_launcher`
  - Added `_requestTutorViaWhatsApp()` method
  - Added `_buildWhatsAppMessage()` method
  - Updated `_buildEmptyState()` UI

### Dependencies Used
- **url_launcher**: For opening WhatsApp
- **auth_service**: For getting current user info
- **survey_repository**: For fetching student/parent survey data

### Key Features
1. **Automatic Data Retrieval**: Fetches user profile and survey data from Supabase
2. **Smart Formatting**: Creates a clear, organized WhatsApp message
3. **Error Handling**: Handles cases where user is not logged in or WhatsApp is not installed
4. **URL Encoding**: Properly encodes the message for WhatsApp deep linking
5. **Role-Based**: Works for both students and parents

## WhatsApp Number
- **Number**: +237 6 53 30 19 97
- **Format in code**: `237653301997` (no spaces, no +, no special chars)

## User Experience

### Success Flow:
1. User searches for tutors
2. No results found
3. User clicks "Request Tutor via WhatsApp"
4. System fetches user data
5. WhatsApp opens with pre-filled message
6. User reviews and sends

### Error Cases:
- **Not logged in**: Shows snackbar asking user to log in
- **WhatsApp not installed**: Shows snackbar with helpful message
- **Data fetch error**: Shows error message with details

## Benefits

### For Students/Parents:
- ✅ No need to manually type details
- ✅ All relevant information included automatically
- ✅ Quick and easy process
- ✅ Direct communication channel

### For Admin:
- ✅ Receives structured, complete information
- ✅ Can match tutors more effectively
- ✅ Professional, organized requests
- ✅ All details in one message

## Testing Checklist

- [ ] Test as logged-in student
- [ ] Test as logged-in parent
- [ ] Test as logged-out user (should show error)
- [ ] Test with completed survey data
- [ ] Test with active search filters
- [ ] Test on device with WhatsApp installed
- [ ] Test on device without WhatsApp
- [ ] Verify message format in WhatsApp
- [ ] Verify all survey data is included
- [ ] Verify search filters are included

## Future Enhancements

1. **Save Request History**: Store requests in database
2. **Track Status**: Allow users to track their request status
3. **In-App Notifications**: Notify user when a match is found
4. **Multiple Contact Methods**: Add email/SMS alternatives
5. **Request Templates**: Allow customizing request messages
6. **Photos**: Allow attaching relevant documents/certificates

## Notes

- The feature uses WhatsApp Web API (`wa.me/` URL scheme)
- Works on all platforms (Android, iOS, Web)
- Requires `url_launcher` package (already in pubspec.yaml)
- Message is URL-encoded to handle special characters
- Uses `LaunchMode.externalApplication` to open WhatsApp in separate app

