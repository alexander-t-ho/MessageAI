# Safe Message Editing Implementation Plan

## Current Status
- ✅ Main branch has working direct messages and group chats
- ✅ Created new branch `fix-messaging-edit-feature` from main

## Critical: Do NOT Change
- `recipientIds` must stay as: `conversation.isGroupChat ? conversation.participantIds : nil`
- `recipientId` must always be set for direct messages
- Keep existing sendMessage logic intact

## Implementation Steps

### Step 1: Data Model Updates
- Add `isEdited: Bool` to MessageData
- Add `editedAt: Date?` to MessageData

### Step 2: Frontend Edit UI (Message Bar Style)
- Add `messageToEdit` state variable
- When editing, populate message input with existing text
- Show edit banner above input bar
- Change send button to checkmark when editing

### Step 3: Edit Functions
- `editMessage()` - populate input bar with message text
- `saveEdit()` - save changes and send to backend
- Keep these separate from `sendMessage()` to avoid breaking it

### Step 4: Backend Lambda
- Create `editMessage.js` Lambda
- Update message in DynamoDB
- Broadcast edit to recipients

### Step 5: WebSocket Integration
- Add `sendEditMessage()` to WebSocketService
- Handle incoming edit events
- Update UI with edited messages

## Testing Checkpoints
After each step:
1. ✅ Direct messages still send
2. ✅ Group messages still send
3. ✅ Edit functionality works

## Key Rule
**DO NOT MODIFY THE sendMessage FUNCTION OR ITS PARAMETERS**
