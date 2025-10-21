# Step 1: Create AWS Cognito User Pool

**Time**: 15 minutes  
**Goal**: Set up user authentication backend in AWS

---

## 🎯 What is AWS Cognito?

Cognito is AWS's authentication service that:
- Stores user accounts securely
- Handles password hashing
- Manages login sessions
- Issues JWT tokens for authentication
- Provides signup/login APIs

---

## 📋 Step-by-Step Instructions

### Part 1: Access Cognito (1 minute)

1. **Go to AWS Console**: https://console.aws.amazon.com
2. In the **search bar at the top**, type: **"Cognito"**
3. Click **"Amazon Cognito"** from the results
4. Click **"Create user pool"** (orange button)

---

### Part 2: Configure Sign-in Experience (2 minutes)

#### Screen: "Configure sign-in experience"

1. **Provider types:**
   - Select: ✅ **"Cognito user pool"** (should be default)

2. **Cognito user pool sign-in options:**
   - ✅ Check **"Email"**
   - ❌ Uncheck "Phone number" (if checked)
   - ❌ Uncheck "User name" (if checked)
   
   > Users will sign in with their email address

3. **User name requirements:** (leave as is)

4. Click **"Next"** at the bottom

---

### Part 3: Configure Security Requirements (3 minutes)

#### Screen: "Configure security requirements"

1. **Password policy:**
   - Select: ⚪ **"Cognito defaults"**
   
   This requires:
   - Minimum 8 characters
   - At least 1 number
   - At least 1 special character
   - At least 1 uppercase letter
   - At least 1 lowercase letter

2. **Multi-factor authentication (MFA):**
   - Select: ⚪ **"No MFA"**
   
   > For MVP, we'll skip MFA to keep it simple

3. **User account recovery:**
   - ✅ Check **"Enable self-service account recovery"**
   - Select: ✅ **"Email only"**

4. **Self-service sign-up:**
   - ✅ Check **"Enable self-registration"**
   
   > This allows new users to sign up

5. **Attribute verification and user account confirmation:**
   - ✅ Check **"Allow Cognito to automatically send messages to verify and confirm"**
   - Select: ✅ **"Send email message, verify email address"**

6. Click **"Next"**

---

### Part 4: Configure Sign-up Experience (2 minutes)

#### Screen: "Configure sign-up experience"

1. **Required attributes:**
   - Look for **"name"** in the list
   - ✅ Check **"name"**
   - ❌ Leave all others unchecked
   
   > Users must provide their name when signing up

2. **Custom attributes:** (skip this section)

3. Click **"Next"**

---

### Part 5: Configure Message Delivery (2 minutes)

#### Screen: "Configure message delivery"

1. **Email:**
   - Select: ⚪ **"Send email with Cognito"**
   
   > For MVP, we'll use Cognito's built-in email (50 emails/day free)
   > For production, you'd use Amazon SES

2. **SES Region:** (leave as default)

3. **FROM email address:** (leave default - no-reply@verificationemail.com)

4. **REPLY-TO email address:** (leave blank)

5. **SMS:** (skip - we're not using phone numbers)

6. Click **"Next"**

---

### Part 6: Integrate Your App (3 minutes)

#### Screen: "Integrate your app"

1. **User pool name:**
   - Type: **`MessageAI-UserPool`**

2. **Hosted authentication pages:**
   - ❌ Uncheck **"Use the Cognito Hosted UI"**
   
   > We'll build our own login UI in the iOS app

3. **Initial app client:**
   - **App client name:** Type: **`MessageAI-iOS`**
   - **Client secret:** Select ⚪ **"Don't generate a client secret"**
   
   > ⚠️ IMPORTANT: Must select "Don't generate" - mobile apps don't use client secrets

4. **Advanced app client settings:** (leave as default)

5. Click **"Next"**

---

### Part 7: Review and Create (2 minutes)

#### Screen: "Review and create"

1. **Review all settings** - scroll through to verify:
   - Sign-in: Email ✅
   - Password policy: Cognito defaults ✅
   - MFA: No MFA ✅
   - Required attributes: name ✅
   - Email delivery: Cognito ✅
   - Pool name: MessageAI-UserPool ✅
   - App client: MessageAI-iOS (no secret) ✅

2. Click **"Create user pool"** at the bottom

3. **Wait 10-20 seconds** for creation

---

### Part 8: Save Important Information (2 minutes)

After creation, you'll see the User Pool details page:

#### Save These Values:

1. **User Pool ID:**
   - Look for: "User pool ID" (looks like `us-east-1_XXXXXXXXX`)
   - **Copy this** and save to notes
   - Label it: "Cognito User Pool ID"

2. **App Client ID:**
   - Click **"App integration"** tab at the top
   - Scroll down to **"App clients and analytics"** section
   - Click on **"MessageAI-iOS"**
   - Look for: "Client ID" (looks like a long random string)
   - **Copy this** and save to notes
   - Label it: "Cognito App Client ID"

---

## ✅ Step 1 Complete!

You should now have:
- ✅ Cognito User Pool created
- ✅ Named: MessageAI-UserPool
- ✅ Email-based authentication
- ✅ App client created (MessageAI-iOS)
- ✅ User Pool ID saved
- ✅ App Client ID saved

---

## 📝 Information You Saved

Make sure you have these in your notes:

```
Cognito User Pool ID: us-east-1_XXXXXXXXX
Cognito App Client ID: xxxxxxxxxxxxxxxxxxxx
```

---

## ⏭️ Next Step

**Step 2**: Create DynamoDB Table for user profiles

---

## 🆘 Troubleshooting

### Can't find User Pool ID
- Go to Cognito → User pools → Click "MessageAI-UserPool"
- It's at the top under "User pool overview"

### Can't find App Client ID
- Go to Cognito → User pools → MessageAI-UserPool
- Click "App integration" tab
- Scroll to "App clients and analytics"
- Click "MessageAI-iOS"
- Client ID is at the top

### Created pool with wrong settings
- You can delete and recreate:
- Cognito → User pools → Select pool → "Delete"
- Start over from Part 1

---

**Once you have both IDs saved, let me know and we'll move to Step 2!** 🎉

