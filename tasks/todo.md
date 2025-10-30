# Filter Session Titles in Start Screen Session List

## Problem
Session titles in the start screen list currently display raw values like "newsession_xyz" or "session_123". We need to apply the same filtering logic as chat_screen.dart: when a title starts with "newsession_" or "session_", display the chatType instead (formatted for readability).

## Investigation Findings

### 1. Session Title Display Location
- **File**: `/Users/sebastiaan/Development/projects/my_flutter_app/lib/screens/start_screen.dart`
- **Line**: 779 (within `_buildSessionItem` method starting at line 642)
- **Current code**:
```dart
Text(
  session.title,
  style: const TextStyle(
    fontSize: 16,
    fontWeight: FontWeight.w600,
    color: Colors.white,
  ),
  maxLines: 1,
  overflow: TextOverflow.ellipsis,
),
```

### 2. Available chatType Values
- `'project_doorgeven'` → Should display as "Project doorgeven"
- `'vakkennis_delen'` → Should display as "Vakkennis delen"
- `'social_media'` → Should display as "Social media"

### 3. Current Chat Screen Logic (Reference)
**File**: `/Users/sebastiaan/Development/projects/my_flutter_app/lib/screens/chat_screen.dart`
**Lines**: 1995-2001

Filters titles starting with "newsession_" or "session_" but keeps default "Chat" value (does NOT use chatType as fallback). Our implementation will be different - we WILL use chatType as fallback.

## Solution Plan

### Task List
- [ ] Add helper method `_formatChatType` to format chatType values for display
- [ ] Update Text widget at line 779 to conditionally show formatted chatType when title should be filtered
- [ ] Test with different session types to verify display

### Implementation Details

#### 1. Add Helper Method `_formatChatType`
**Location**: In `_StartScreenState` class in start_screen.dart (around line 830, after `_formatDate` method)

**Method**:
```dart
String _formatChatType(String? chatType) {
  if (chatType == null) return 'Chat';
  
  switch (chatType) {
    case 'project_doorgeven':
      return 'Project doorgeven';
    case 'vakkennis_delen':
      return 'Vakkennis delen';
    case 'social_media':
      return 'Social media';
    default:
      // Fallback: capitalize and replace underscores with spaces
      return chatType.replaceAll('_', ' ');
  }
}
```

**Reasoning**: Simple switch statement matching the action button titles. Default fallback handles unknown values gracefully.

#### 2. Update Text Widget Display Logic
**Location**: Line 779 in start_screen.dart

**Change from**:
```dart
Text(
  session.title,
  style: const TextStyle(...),
  ...
),
```

**Change to**:
```dart
Text(
  (session.title.startsWith('newsession_') || session.title.startsWith('session_'))
    ? _formatChatType(session.chatType)
    : session.title,
  style: const TextStyle(...),
  ...
),
```

**Reasoning**: Same filtering logic as chat_screen.dart (lines 1996-1997), but uses formatted chatType as fallback instead of generic "Chat".

## Expected Behavior After Changes

### Before
- Session with title "newsession_1698765432" displays as "newsession_1698765432"
- Session with title "session_1698765432" displays as "session_1698765432"
- Session with proper title "My Project" displays as "My Project"

### After
- Session with title "newsession_1698765432" and chatType "project_doorgeven" displays as "Project doorgeven"
- Session with title "session_1698765432" and chatType "vakkennis_delen" displays as "Vakkennis delen"
- Session with proper title "My Project" displays as "My Project" (no change)
- Session with filtered title but no chatType displays as "Chat" (fallback)

## Testing Plan

1. **Test filtered title with chatType**:
   - Create new session via "Project doorgeven" button
   - Return to start screen before backend assigns real title
   - **Expected**: Display shows "Project doorgeven"

2. **Test filtered title without chatType**:
   - Find/create session with title starting with "newsession_" but no chatType
   - **Expected**: Display shows "Chat"

3. **Test normal title**:
   - Open session with real title like "Website Development"
   - **Expected**: Display shows "Website Development"

4. **Test all chatType values**:
   - Create sessions for all 3 action types
   - Verify each shows correct formatted label

## Files to Modify
1. `/Users/sebastiaan/Development/projects/my_flutter_app/lib/screens/start_screen.dart` - Add helper method and update display logic

## Principles Applied
- **Simple**: Only 2 small changes (1 new method, 1 line modification)
- **Minimal impact**: Only touches session list display logic
- **Consistent**: Uses same filtering logic as chat_screen.dart
- **Defensive**: Handles missing chatType gracefully with fallback
- **User-friendly**: Formats chatType values to match UI button text

---

**Ready for review and approval before implementation.**
