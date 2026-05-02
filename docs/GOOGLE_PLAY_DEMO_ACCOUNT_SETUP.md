# Google Play Console - Demo Account Setup Guide

**Issue:** Missing demo or guest account details  
**Status:** Action Required ⚠️

---

## 📋 Step-by-Step Instructions

### **STEP 1: Create a Demo Account in Your App**

1. **Open your PrepSkul app** on a device or emulator
2. **Sign up for a new account:**
   - Tap **"Sign Up"** or **"Create Account"**
   - Choose **"Tutor"** as the user type
   - Enter email: `demo@prepskul.com` (or create a real email like `prepskul.demo@gmail.com`)
   - Create a password: `PrepSkulDemo2026!` (or your own strong password)
   - **⚠️ IMPORTANT:** Write down the email and password - you'll need them for Play Console
3. **Complete the signup process:**
   - Verify your email/phone if required
   - Complete OTP verification if using phone
4. **Complete Tutor Onboarding:**
   - Fill in all required fields:
     - Personal information
     - Contact details
     - Subjects you teach
     - Experience and teaching style
     - Availability
     - Upload profile photo (optional but recommended)
     - Upload verification documents (use test documents)
   - Complete all onboarding steps
   - Submit for approval

### **STEP 2: Approve the Demo Account**

1. **Go to your Admin Dashboard:**
   - Open: `https://admin.prepskul.com/admin/tutors`
   - Log in with your admin credentials
2. **Find the demo account:**
   - Look for the tutor account you just created (email: `demo@prepskul.com`)
   - Or search by email in the tutors list
3. **Approve the account:**
   - Click on the tutor profile
   - Change status from **"Pending"** to **"Approved"**
   - Save the changes
4. **Verify approval:**
   - Check that the account status shows **"Approved"**
   - The tutor should now have full access to all features

### **STEP 3: Test the Demo Account**

1. **Log out** of the demo account (if still logged in)
2. **Log back in** using the credentials:
   - Email: `demo@prepskul.com`
   - Password: `PrepSkulDemo2026!` (or your password)
3. **Verify you can access:**
   - ✅ Tutor dashboard
   - ✅ Profile settings
   - ✅ Session management
   - ✅ Student booking features
   - ✅ All main app features
4. **If anything doesn't work:**
   - Fix the issues before submitting to Play Console
   - Make sure the account is fully functional

### **STEP 4: Add Credentials in Google Play Console**

1. **Go to Google Play Console:**
   - Visit: https://play.google.com/console
   - Sign in with your Google Play Developer account

2. **Navigate to your app:**
   - Click on **"PrepSkul"** (com.prepskul.prepskul)

3. **Go to App Access:**
   - In the left sidebar, click: **Policy** → **App content**
   - Scroll down to find: **App access**
   - Click on **"App access"** section

4. **Add Demo Account:**
   - Click **"Add new instructions"** or **"Edit"** button
   - You'll see a form to fill in

5. **Fill in the credentials:**
   
   **Email/Username field:**
   ```
   demo@prepskul.com
   ```
   (or whatever email you used in Step 1)
   
   **Password field:**
   ```
   PrepSkulDemo2026!
   ```
   (or the password you created in Step 1)
   
   **Instructions field:**
   ```
   Demo Account Credentials for PrepSkul Review:
   
   Email: demo@prepskul.com
   Password: PrepSkulDemo2026!
   
   Account Type: Pre-approved Tutor Account
   
   IMPORTANT NOTES FOR REVIEWERS:
   - This account is already approved and has full access to all features
   - No waiting period or manual approval needed
   - You can immediately access:
     * Tutor dashboard
     * Student booking management
     * Session scheduling and management
     * Profile and settings
     * Video call features (Agora)
     * All app functionality
   
   The account has completed all onboarding steps and is ready for review.
   
   If you encounter any issues accessing the account, please contact: support@prepskul.com
   ```

6. **Save the credentials:**
   - Click **"Save"** or **"Submit"** button
   - Verify the credentials are saved (you should see them listed)

### **STEP 5: Verify App Access Declaration**

1. **Check the App Access section:**
   - Make sure it shows: **"Some or all functionality is restricted"**
   - This indicates that login is required

2. **Review your instructions:**
   - Make sure the demo account credentials are clearly visible
   - Ensure the instructions are helpful and clear

### **STEP 6: Submit for Review**

1. **Go to Publishing Overview:**
   - In Play Console, click: **Publishing overview** in the left sidebar
   - Or go to: **Release** → **Production** (or your active track)

2. **Review your changes:**
   - Check that all policy issues are addressed:
     - ✅ Privacy policy URL updated
     - ✅ Demo account credentials added
     - ✅ App access instructions provided

3. **Send for review:**
   - Click **"Send changes for review"** or **"Submit for review"** button
   - You'll see a confirmation message
   - Note the submission date

### **STEP 7: Monitor Review Status**

1. **Check review status:**
   - Go to **Publishing overview**
   - Look for: **"Under review"** status
   - Review typically takes **1-3 business days**

2. **If approved:**
   - ✅ Your app will be published
   - You'll receive an email notification

3. **If rejected again:**
   - Check the new rejection reason
   - Update credentials if needed
   - Fix any new issues
   - Resubmit

---

## ✅ Quick Checklist

Before submitting, make sure:

- [ ] Demo account created in app
- [ ] Demo account approved in admin dashboard
- [ ] Demo account tested and working (can log in and access features)
- [ ] Credentials added in Play Console → Policy → App content → App access
- [ ] Clear instructions provided for reviewers
- [ ] App submitted for review

---

## 🔧 Troubleshooting

### **Q: What if I don't have access to the admin dashboard?**
**A:** Contact your backend developer or database administrator to approve the demo account manually. You can also approve it directly in your database if you have access.

### **Q: What if reviewers can't log in?**
**A:** 
- Double-check the email and password are correct
- Test logging in yourself before submitting
- Make sure the account isn't locked or disabled
- Verify the account is approved in the admin dashboard

### **Q: Should I create multiple demo accounts?**
**A:** One approved tutor account is usually sufficient. However, if your app has very different features for students vs tutors, you might want to create both:
- One tutor account (approved)
- One student account (if student features are significantly different)

### **Q: How long does review take?**
**A:** Typically 1-3 business days, but can take up to 7 days. You'll receive an email when the review is complete.

### **Q: What if I want to use phone number instead of email?**
**A:** You can provide phone number login instructions:
```
To review the app:
1. Open the app and select "Sign in with phone"
2. Enter phone number: +237612345678 (use a real test number)
3. Complete OTP verification
4. Log in with password: [your password]
```

### **Q: Can I use a guest account instead?**
**A:** If your app supports guest access, you can provide guest account instructions. However, since PrepSkul requires login, a demo account is the best approach.

---

## 📞 Need Help?

If you encounter any issues:
1. Check the Google Play Console Help Center: https://support.google.com/googleplay/android-developer
2. Review the rejection email for specific details
3. Contact Google Play support through Play Console if needed

---

## 🎯 Summary

**What you need to do:**
1. Create a demo tutor account in your app
2. Approve it in the admin dashboard
3. Add the credentials in Play Console → Policy → App content → App access
4. Submit for review

**Time required:** ~30 minutes  
**Review time:** 1-3 business days

Good luck! 🚀

