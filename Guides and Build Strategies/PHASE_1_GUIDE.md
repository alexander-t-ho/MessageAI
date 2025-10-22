# Phase 1: User Authentication - Complete Guide

**Goal**: Build a complete authentication system with signup, login, and user management.

**Status**: 🟡 IN PROGRESS

---

## 📋 What We're Building

### Backend (AWS):
- ✅ AWS Cognito User Pool (user management)
- ✅ Lambda Functions (signup, login, token refresh)
- ✅ API Gateway (REST endpoints)
- ✅ DynamoDB Table (user profiles)

### Frontend (iOS):
- ✅ Login Screen
- ✅ Signup Screen
- ✅ Network Service (API calls)
- ✅ Auth State Management

---

## 🎯 Phase 1 Steps

### Part A: Backend Setup (AWS Console) - 1 hour

#### Step 1: Create Cognito User Pool (15 min)
- [ ] Create User Pool
- [ ] Configure sign-in options (email)
- [ ] Set password requirements
- [ ] Create App Client
- [ ] Note User Pool ID and App Client ID

#### Step 2: Create DynamoDB Table (5 min)
- [ ] Create "Users" table
- [ ] Set partition key: userId
- [ ] Configure attributes

#### Step 3: Create Lambda Functions (30 min)
- [ ] signup-lambda (create new user)
- [ ] login-lambda (authenticate user)
- [ ] refresh-token-lambda (renew tokens)

#### Step 4: Create API Gateway (10 min)
- [ ] Create REST API
- [ ] Create /auth/signup endpoint (POST)
- [ ] Create /auth/login endpoint (POST)
- [ ] Enable CORS
- [ ] Deploy API
- [ ] Note API Gateway URL

---

### Part B: iOS Frontend (Xcode) - 1.5 hours

#### Step 5: Create Data Models (10 min)
- [ ] User model
- [ ] AuthResponse model
- [ ] Error handling

#### Step 6: Create Network Service (20 min)
- [ ] NetworkService.swift
- [ ] signup() method
- [ ] login() method
- [ ] Error handling

#### Step 7: Create Auth Views (40 min)
- [ ] AuthenticationView.swift (login/signup toggle)
- [ ] Login form (email, password, submit)
- [ ] Signup form (name, email, password, submit)
- [ ] Error display

#### Step 8: Update App Flow (10 min)
- [ ] AuthContext to manage logged-in state
- [ ] Show AuthView when not logged in
- [ ] Show main app when logged in

#### Step 9: Test Authentication (10 min)
- [ ] Test signup with new email
- [ ] Verify user in Cognito Console
- [ ] Test login with same credentials
- [ ] See welcome message

---

## 🎓 Learning Goals

By the end of Phase 1, you'll understand:
- How AWS Cognito manages users
- How Lambda functions process requests
- How API Gateway routes requests
- How iOS apps authenticate with backends
- SwiftUI form handling
- Async/await networking in Swift

---

## 📊 Progress Tracker

- [ ] Part A: Backend Setup (0/4 steps)
- [ ] Part B: iOS Frontend (0/5 steps)
- [ ] Testing Complete

---

## ⏱️ Time Estimate

**Total**: 2-3 hours
- Backend setup: 1 hour
- iOS frontend: 1.5 hours
- Testing: 30 minutes

---

## 🔄 Current Step

**Next**: Step 1 - Create AWS Cognito User Pool

---

*This guide will be updated as we progress through Phase 1*

