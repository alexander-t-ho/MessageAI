# App Icon and Name Update - Manual Steps

## 📱 Issue: Home Screen Still Shows "MessageAI"

The Info.plist has been updated, but you need to do these steps in Xcode:

### Step 1: Update Display Name
1. Open Xcode
2. Click on project in navigator (blue icon)
3. Select "MessageAI" target
4. General tab
5. **Display Name**: Change to "Cloudy"
6. Build and run

### Step 2: Create App Icon
The app icon (cloud with sunset) needs to be created as image assets:

1. Create images (1024x1024, 180x180, 120x120, etc.)
2. In Xcode: Assets.xcassets → AppIcon
3. Drag images into slots
4. Build and run

### Quick Test Icon:
For now, you can use SF Symbol "cloud.fill" as a placeholder.

---

**These require Xcode GUI - can't be done via code/CLI**

Once done, home screen will show "Cloudy" with cloud icon ☁️

