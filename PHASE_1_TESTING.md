# Phase 1: Authentication Testing Guide

## 🎯 What We're Testing

Your iOS app now has:
- ✅ Beautiful login/signup screens
- ✅ Connection to your AWS backend
- ✅ User authentication flow
- ✅ Session management

Let's test it!

---

## 📱 Testing Steps

### Step 1: Build and Run (2 minutes)

**In Xcode:**

1. **Open the project:**
   - If not already open: `open /Users/alexho/MessageAI/MessageAI/MessageAI.xcodeproj`

2. **Make sure iPhone 17 is selected** (top-left dropdown)

3. **Build and Run:**
   - Press **Cmd+R**
   - Wait for build (30 seconds)
   - App launches in simulator

**Expected**: You should see a beautiful login screen with:
- Blue/purple gradient background
- MessageAI logo (message icon)
- Login/Sign Up tabs
- Email and password fields

---

### Step 2: Create a New Account (3 minutes)

**In the simulator:**

1. **Switch to Sign Up tab**
   - Tap "Sign Up" at the top

2. **Fill in the form:**
   - **Name**: Your name (e.g., "John Doe")
   - **Email**: Use a unique email (e.g., "john.doe@test.com")
   - **Password**: Must meet requirements:
     - At least 8 characters
     - 1 uppercase letter
     - 1 lowercase letter
     - 1 number
     - 1 special character
     - Example: `Test123!@#`

3. **Tap "Create Account" button**

4. **Wait 2-3 seconds**

**Expected Result:**
- Green success message appears
- Message says: "User created successfully. Please check your email..."
- After 2 seconds, form switches back to Login tab

**In Terminal** (to verify user was created):
```bash
aws cognito-idp list-users \
  --user-pool-id us-east-1_aJN47Jgfy \
  --region us-east-1 \
  --query 'Users[*].[Username,Attributes[?Name==`email`].Value | [0]]' \
  --output table
```

You should see your email listed!

---

### Step 3: Confirm Your Account (1 minute)

Since email verification is required, we need to confirm the account manually:

**In Terminal:**
```bash
aws cognito-idp admin-confirm-sign-up \
  --user-pool-id us-east-1_aJN47Jgfy \
  --username YOUR_EMAIL_HERE \
  --region us-east-1
```

Replace `YOUR_EMAIL_HERE` with the email you just used.

**Expected**: No error message (success!)

---

### Step 4: Login (2 minutes)

**Back in the simulator:**

1. **Make sure you're on the Login tab**

2. **Enter your credentials:**
   - **Email**: The email you just signed up with
   - **Password**: The password you used

3. **Tap "Login" button**

4. **Wait 2-3 seconds**

**Expected Result:**
- Loading indicator appears briefly
- Screen transitions to **Home View**
- You see:
  - Green checkmark icon
  - "Welcome!" message
  - "Hello, [Your Name]! 👋"
  - Your email address
  - "Phase 1 Complete!" badge
  - Logout button at the bottom

**SUCCESS!** 🎉 You're logged in!

---

### Step 5: Test Session Persistence (1 minute)

**In Xcode:**

1. **Stop the app** (click Stop ■ button)
2. **Run it again** (Cmd+R)

**Expected Result:**
- App launches **directly to Home View**
- You're still logged in!
- Your name and email are displayed

This proves session management works!

---

### Step 6: Test Logout (1 minute)

**In the simulator (Home View):**

1. **Scroll down to the bottom**
2. **Tap the "Logout" button**

**Expected Result:**
- Screen transitions back to Login screen
- Form is empty
- You're logged out

---

### Step 7: Login Again (1 minute)

**Test that you can login multiple times:**

1. Enter your email and password
2. Tap "Login"
3. Should go back to Home View

---

## ✅ Success Criteria

Phase 1 is complete when ALL of these work:

- [ ] Login screen displays correctly
- [ ] Can create a new account (signup)
- [ ] Can login with credentials
- [ ] Home screen shows user name and email
- [ ] Session persists after app restart
- [ ] Can logout successfully
- [ ] Can login again after logout

---

## 🎓 What You Just Built

Congratulations! You now have:

1. **AWS Backend:**
   - Cognito User Pool managing users
   - DynamoDB storing user profiles
   - Lambda functions handling auth logic
   - API Gateway exposing REST endpoints

2. **iOS Frontend:**
   - Beautiful authentication UI
   - Network service for API calls
   - State management with ObservableObjects
   - Session persistence with UserDefaults
   - Smooth transitions between views

3. **Full Authentication Flow:**
   - User registration
   - Email/password login
   - JWT token management
   - Logout functionality

---

## 🐛 Troubleshooting

### Issue: App crashes on launch

**Check Xcode console** (bottom panel) for error messages.

Common fixes:
- Clean Build: Product → Clean Build Folder (Cmd+Shift+K)
- Delete app from simulator: Long-press app icon → Delete
- Rebuild: Cmd+R

### Issue: "Internal Server Error" when signing up

**Check Lambda logs:**
```bash
aws logs tail /aws/lambda/messageai-signup_AlexHo --since 5m --region us-east-1
```

### Issue: "Incorrect email or password" when logging in

- Make sure you confirmed the account (Step 3)
- Check password meets requirements
- Email is case-sensitive

### Issue: Simulator is slow

- Use iPhone 17 (not Pro) - lighter and faster
- Window → Physical Size (makes simulator smaller)
- Close other apps on your Mac

---

## 📸 Screenshots to Share

Take screenshots of:
1. Login screen
2. Signup form filled out
3. Home screen with your name
4. Terminal showing successful API calls

---

## ⏭️ What's Next

After Phase 1 is complete, we'll move to:

**Phase 2: Local Data Persistence**
- SwiftData models for messages
- Local database setup
- Offline message storage

**Phase 3: One-on-One Messaging**
- Chat interface
- Send/receive messages
- Real-time updates

---

## 🎊 Celebrate!

You just built a production-quality authentication system from scratch! This is a major milestone.

**Phase 1: COMPLETE!** ✅

When you've tested everything and it works, let me know and we'll start Phase 2! 🚀

