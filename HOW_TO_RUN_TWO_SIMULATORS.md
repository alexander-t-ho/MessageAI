# 📱 **How to Run Your App on Two Simulators**

## 🎯 **Goal**

Test real-time messaging by running MessageAI on two different iOS simulators simultaneously.

---

## 📋 **Step-by-Step Instructions**

### **Step 1: Open Your Project in Xcode**

1. **Open Xcode**
2. **Open your project:**
   - File → Open
   - Navigate to `/Users/alexho/MessageAI/MessageAI/MessageAI.xcodeproj`
   - Click **Open**

---

### **Step 2: Build and Run on First Simulator**

1. **At the top of Xcode**, you'll see the scheme selector:
   ```
   MessageAI > iPhone 17
   ```

2. **Click on "iPhone 17"** (or whatever iPhone it shows)

3. **Choose a simulator:**
   - Select **iPhone 16** (or any iPhone from the list)
   - This will be your "Device 1"

4. **Click the ▶️ Play button** (or press Cmd+R)

5. **Wait for:**
   - Build to complete
   - Simulator to launch
   - App to install and open

6. **You should see:** The MessageAI login screen

7. **Login with a test account:**
   - Use an existing account or create one
   - This will be "User 1"

---

### **Step 3: Launch Second Simulator**

**Keep the first simulator running!** Don't stop it.

1. **In Xcode menu bar**, go to:
   ```
   Window → Devices and Simulators
   ```
   (Or press Shift+Cmd+2)

2. **Click "Simulators" tab** at the top

3. **You'll see a list of simulators:**
   ```
   iPhone 16
   iPhone 16 Pro
   iPhone 17
   iPhone 17 Pro
   ...
   ```

4. **Find a DIFFERENT simulator** than the one running
   - For example, if iPhone 16 is running, choose **iPhone 17**

5. **Right-click** on the simulator you want
   - Click **"Boot"**
   - Or just double-click it

6. **A second simulator will launch!** 📱📱

7. **Close the "Devices and Simulators" window**

---

### **Step 4: Run App on Second Simulator**

1. **Back in Xcode**, click on the scheme selector again:
   ```
   MessageAI > iPhone 16
   ```

2. **Select the SECOND simulator** you just booted:
   - Click on **iPhone 17** (or whichever one you booted)

3. **Click the ▶️ Play button** again (or Cmd+R)

4. **Xcode will:**
   - Keep the first simulator running
   - Build and install on the second simulator
   - Launch the app on second simulator

5. **You should now have:**
   - ✅ Two simulators running side-by-side
   - ✅ MessageAI app running on both

---

### **Step 5: Login on Second Simulator**

1. **On the second simulator**, login with a **DIFFERENT account**
   - Create a new account or use a different existing one
   - This will be "User 2"

2. **Now you have:**
   - Simulator 1: Logged in as User 1
   - Simulator 2: Logged in as User 2

---

### **Step 6: Test Messaging!**

#### **On Simulator 1 (User 1):**

1. **Go to conversations list**
2. **Tap on a conversation** (or create one with User 2)
3. **Type a message:** "Hello from User 1!"
4. **Send it** (tap the ↑ button)

#### **On Simulator 2 (User 2):**

1. **Watch the conversation screen**
2. **The message should appear INSTANTLY!** ⚡
3. **Type a reply:** "Hi back from User 2!"
4. **Send it**

#### **On Simulator 1:**

1. **The reply appears instantly!** ⚡

**🎉 CONGRATULATIONS! Real-time messaging is working!**

---

## 🖥️ **Visual Layout Tips**

### **Arrange Simulators Side-by-Side:**

1. **Click and drag** the simulator windows
2. **Position them side-by-side:**
   ```
   ┌──────────┐  ┌──────────┐
   │ iPhone 16│  │ iPhone 17│
   │  (User 1)│  │  (User 2)│
   │          │  │          │
   │  [Chat]  │  │  [Chat]  │
   │          │  │          │
   └──────────┘  └──────────┘
   ```

3. **This makes testing easier!**

---

## 🔍 **Watching Console Output**

### **To See Real-Time Logs:**

1. **In Xcode**, open the console:
   - **View → Debug Area → Show Debug Area**
   - Or press **Shift+Cmd+Y**

2. **You'll see logs like:**
   ```
   💡 WebSocketService initialized
   🔌 Connecting to WebSocket...
   ✅ Connected to WebSocket
   ✅ Message sent via WebSocket: abc123
   📥 Received WebSocket message
   ✅ New message received: def456
   ```

3. **This helps debug issues!**

---

## ⚙️ **Troubleshooting**

### **Issue: Can't find second simulator**

**Solution:**
1. Go to Xcode → Settings (or Cmd+,)
2. Click **Platforms** tab
3. Make sure iOS platform is installed
4. Download additional simulators if needed

---

### **Issue: Second simulator won't boot**

**Solution 1: Restart Xcode**
1. Close Xcode completely
2. Reopen and try again

**Solution 2: Reset simulator**
```bash
xcrun simctl shutdown all
xcrun simctl boot "iPhone 17"
```

---

### **Issue: App crashes on second simulator**

**This is expected!** The database is shared. Try this:

**Solution: Delete app from both simulators**
1. Long-press the MessageAI app icon
2. Tap "Remove App"
3. Tap "Delete App"
4. Rebuild and run on both simulators

---

### **Issue: Can't see both simulators**

**Solution: They might be on top of each other**
1. Click and drag one simulator window
2. Move it to the side
3. Both should be visible now

---

### **Issue: Xcode keeps switching simulators**

**Solution: This is normal!**
- Xcode will switch to whichever simulator you last ran on
- Just switch back to view the other one
- Both apps keep running in background

---

## 🎮 **Controlling Simulators**

### **Useful Shortcuts:**

**In Simulator:**
- **Cmd+K** - Toggle keyboard
- **Cmd+H** - Go to home screen
- **Cmd+Shift+H** - Double-tap home (app switcher)
- **Cmd+1** - Scale to 100%
- **Cmd+2** - Scale to 75%
- **Cmd+3** - Scale to 50%

**In Xcode:**
- **Cmd+R** - Run/Build
- **Cmd+.** - Stop running
- **Shift+Cmd+Y** - Show/hide console

---

## 🧹 **Cleanup (When Done Testing)**

### **Stop Simulators:**

**Option 1: In Xcode**
- Click the ⏹️ Stop button (or Cmd+.)

**Option 2: Close Simulator Windows**
- Just close the simulator windows

**Option 3: Terminal Command**
```bash
xcrun simctl shutdown all
```

---

## 🎥 **Video Tutorial (If Needed)**

If you get stuck, search YouTube for:
- "How to run iOS app on two simulators"
- "Xcode multiple simulators tutorial"

---

## 📝 **Quick Summary**

1. ✅ Run app on first simulator (Cmd+R)
2. ✅ Login as User 1
3. ✅ Window → Devices and Simulators
4. ✅ Boot a different simulator
5. ✅ Switch to that simulator in Xcode scheme selector
6. ✅ Run app again (Cmd+R)
7. ✅ Login as User 2
8. ✅ Test messaging between them!

---

## 💡 **Pro Tips**

1. **Use different sized simulators**
   - Makes it easier to tell them apart
   - Example: iPhone 16 and iPhone 17 Pro Max

2. **Scale simulators down**
   - Press Cmd+3 in simulator
   - Takes less screen space
   - Both fit on screen easier

3. **Name your test accounts clearly**
   - User1@test.com / User2@test.com
   - Easy to remember which is which

4. **Keep console open**
   - Watch real-time logs
   - See connection status
   - Debug issues immediately

---

## ❓ **Still Stuck?**

Let me know at which step you're stuck:
1. Building on first simulator?
2. Launching second simulator?
3. Switching between simulators?
4. Testing messaging?

I'll help you through it! 💪

---

**Good luck testing!** 🚀

**You're about to see your real-time messaging in action!** ⚡

