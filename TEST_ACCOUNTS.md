# 🔑 **Test Accounts**

## ✅ **Ready-to-Use Test Accounts**

Use these accounts for testing your MessageAI app:

---

## 👤 **Test Account 1**

**Email:** `test@example.com`  
**Password:** `Test123!`  
**Name:** Test User  
**Status:** ✅ CONFIRMED

**Use for:** First simulator / First device

---

## 👤 **Test Account 2**

**Email:** `test2@example.com`  
**Password:** `Test123!`  
**Name:** Test User 2  
**Status:** ✅ CONFIRMED

**Use for:** Second simulator / Second device

---

## 👤 **Your Personal Account**

**Email:** `alex.test@messageai.com`  
**Status:** ✅ CONFIRMED

---

## 🧪 **How to Test**

### **Two Simulators:**

1. **Simulator 1:**
   - Login with `test@example.com` / `Test123!`
   
2. **Simulator 2:**
   - Login with `test2@example.com` / `Test123!`

3. **Send messages between them!**

---

## 🆘 **If Login Fails**

### **"User does not exist" error:**

The account might not be in your Cognito user pool. Create it:

```bash
# Create new test account
aws cognito-idp admin-create-user \
    --user-pool-id us-east-1_aJN47Jgfy \
    --username test3@example.com \
    --user-attributes \
        Name=email,Value=test3@example.com \
        Name=email_verified,Value=true \
        Name=name,Value="Test User 3" \
    --message-action SUPPRESS \
    --region us-east-1

# Set password
aws cognito-idp admin-set-user-password \
    --user-pool-id us-east-1_aJN47Jgfy \
    --username test3@example.com \
    --password "Test123!" \
    --permanent \
    --region us-east-1
```

---

### **"User is not confirmed" error:**

Confirm the account:

```bash
aws cognito-idp admin-confirm-sign-up \
    --user-pool-id us-east-1_aJN47Jgfy \
    --username test@example.com \
    --region us-east-1
```

---

### **"Incorrect username or password" error:**

Reset the password:

```bash
aws cognito-idp admin-set-user-password \
    --user-pool-id us-east-1_aJN47Jgfy \
    --username test@example.com \
    --password "Test123!" \
    --permanent \
    --region us-east-1
```

---

## 📋 **List All Users**

To see all users in your Cognito user pool:

```bash
aws cognito-idp list-users \
    --user-pool-id us-east-1_aJN47Jgfy \
    --region us-east-1 \
    --query 'Users[*].[Username, UserStatus, Attributes[?Name==`email`].Value | [0]]' \
    --output table
```

---

## 🔐 **Password Requirements**

Your Cognito password policy requires:
- Minimum 8 characters
- At least 1 uppercase letter
- At least 1 lowercase letter
- At least 1 number
- At least 1 special character (!@#$%^&*)

**Example valid passwords:**
- `Test123!`
- `Password1!`
- `MyApp2024!`

---

## ✅ **Current Status**

All test accounts are:
- ✅ Created
- ✅ Confirmed (verified)
- ✅ Password set to `Test123!`
- ✅ Ready to use

**You can login now!** 🎉

---

## 💡 **Tips**

1. **Use test@ for first user**
   - Easy to remember
   - test@example.com

2. **Use test2@ for second user**
   - Clear differentiation
   - test2@example.com

3. **Same password for both**
   - `Test123!`
   - Easy to test quickly

4. **Create more if needed**
   - test3@example.com
   - test4@example.com
   - etc.

---

**Updated:** October 21, 2025  
**Status:** ✅ All accounts ready for testing

