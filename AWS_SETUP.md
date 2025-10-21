# AWS Configuration Guide

## Current Status
- ✅ AWS CLI is installed (version 2.4.13)
- ❌ AWS credentials NOT configured yet

## Configure AWS Credentials

You'll need AWS credentials to use AWS services. Here's how to set them up:

### Option 1: If You Have an AWS Account

1. **Log in to AWS Console**: https://console.aws.amazon.com

2. **Create IAM User** (if you don't have one):
   - Go to IAM → Users → Add User
   - Username: `messageai-developer`
   - Access type: ✅ Programmatic access
   - Permissions: Attach existing policy → `AdministratorAccess` (for MVP)
   - Click through to create
   - **IMPORTANT**: Download the credentials CSV or copy:
     - Access Key ID
     - Secret Access Key

3. **Configure AWS CLI**:
   ```bash
   aws configure
   ```
   
   You'll be prompted for:
   - **AWS Access Key ID**: [paste your Access Key ID]
   - **AWS Secret Access Key**: [paste your Secret Access Key]
   - **Default region name**: `us-east-1` (recommended)
   - **Default output format**: `json`

4. **Verify Configuration**:
   ```bash
   aws sts get-caller-identity
   ```
   
   You should see your account info (UserId, Account, Arn).

### Option 2: If You DON'T Have an AWS Account

1. **Create AWS Account**: https://aws.amazon.com
   - Click "Create an AWS Account"
   - Follow the signup process
   - You'll need:
     - Email address
     - Credit card (for verification, free tier is generous)
     - Phone number
   - Takes 5-10 minutes

2. **After Account Creation**:
   - Follow Option 1 above to create IAM user and configure CLI

### Option 3: AWS Academy or Educational Account

If you have AWS Academy access:
1. Log into AWS Academy
2. Go to your course/lab
3. Click "AWS Details"
4. Copy the credentials shown
5. Run `aws configure` and paste them

## Required AWS Services for MessageAI

We'll be using (all have free tier):
- **AWS Cognito**: User authentication (50,000 MAU free)
- **AWS Lambda**: Serverless functions (1M requests/month free)
- **Amazon DynamoDB**: NoSQL database (25 GB storage free)
- **API Gateway**: REST & WebSocket APIs (1M API calls/month free)
- **Amazon SNS**: Push notifications (1M publishes/month free)

**Estimated Cost for MVP Development**: $0 - $5/month (within free tier)

## Security Best Practices

⚠️ **Important**:
- Never commit AWS credentials to GitHub
- Use IAM users, not root account
- Enable MFA on your AWS account
- For production, use more restrictive IAM policies

## What's Next

Once AWS is configured:
1. Verify: `aws sts get-caller-identity` works
2. We'll set up services in Phase 1 (Authentication)

## Troubleshooting

### "Unable to locate credentials"
- Run `aws configure` again
- Check `~/.aws/credentials` file exists
- Verify credentials are correct in AWS Console

### "Access Denied" errors
- Your IAM user needs sufficient permissions
- For MVP, use `AdministratorAccess` policy
- For production, create custom policy with minimal permissions

---

**Note**: You can proceed with Xcode setup first and configure AWS later before Phase 1.



