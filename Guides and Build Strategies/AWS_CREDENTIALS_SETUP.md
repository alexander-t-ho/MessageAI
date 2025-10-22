# AWS Credentials Configuration

## Step 3: Configure AWS CLI

**Run this command in Terminal:**

```bash
aws configure
```

**You'll be prompted for 4 things:**

### 1. AWS Access Key ID
```
AWS Access Key ID [None]: 
```
**→ Paste your Access Key ID** (from the AWS Console, looks like `AKIA...`)
**→ Press Enter**

### 2. AWS Secret Access Key
```
AWS Secret Access Key [None]: 
```
**→ Paste your Secret Access Key** (the long random string)
**→ Press Enter**

### 3. Default region name
```
Default region name [None]: 
```
**→ Type: `us-east-1`**
**→ Press Enter**

### 4. Default output format
```
Default output format [None]: 
```
**→ Type: `json`**
**→ Press Enter**

---

## Step 4: Verify Configuration

**Run this command:**
```bash
aws sts get-caller-identity
```

**Expected output:**
```json
{
    "UserId": "AIDAXXXXXXXXXXXXXXXXX",
    "Account": "123456789012",
    "Arn": "arn:aws:iam::123456789012:user/messageai-developer"
}
```

If you see this, **SUCCESS!** ✅

---

## Troubleshooting

### Error: "Unable to locate credentials"
- Rerun `aws configure` and enter credentials again
- Make sure you copied the keys correctly (no extra spaces)

### Error: "InvalidClientTokenId"
- The Access Key ID is incorrect
- Go back to AWS Console and create new access keys
- Rerun `aws configure` with the new keys

### Error: "SignatureDoesNotMatch"
- The Secret Access Key is incorrect
- Go back to AWS Console and create new access keys
- Rerun `aws configure` with the new keys

---

## Security Notes

✅ **Good practices:**
- Never commit credentials to GitHub
- Don't share your access keys
- Keys are stored in: `~/.aws/credentials`

❌ **Don't:**
- Post keys in chat/email
- Commit credentials file to git (already in .gitignore)
- Use root account keys (always use IAM user)

---

## What's Next

Once `aws sts get-caller-identity` works, we're ready for Phase 1!

