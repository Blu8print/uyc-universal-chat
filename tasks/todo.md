# Add chatType to Session Creation Flow

## Summary
Add chatType parameter to session creation flow so that when users click action buttons (Project doorgeven, Vakkennis delen, Social media), the chatType is sent in the webhook request.

## Todo Items

- [x] Add chatType parameter to ApiService.createSession()
- [x] Update SessionService methods to pass chatType
- [x] Update start_screen.dart to map actionType to chatType

## Implementation Details

### Mapping
- 'project' → 'project_doorgeven'
- 'knowledge' → 'vakkennis_delen'
- 'social' → 'social_media'

### Flow
start_screen action button → SessionService.resetSession(chatType) → startNewSession(chatType) → _createSessionOnBackend(chatType) → ApiService.createSession(chatType) → webhook with chatType parameter

## Files Modified

1. **lib/services/api_service.dart** (lines 164-212)
   - Added optional `String? chatType` parameter to `createSession()` method
   - Updated request body to conditionally include chatType when not null
   - Updated response parsing to include `chat_type` from webhook response

2. **lib/services/session_service.dart** (lines 32-40, 73-75, 90-100)
   - Added optional `String? chatType` parameter to `startNewSession()`
   - Added optional `String? chatType` parameter to `resetSession()`
   - Updated `_createSessionOnBackend()` to accept and pass chatType to ApiService

3. **lib/screens/start_screen.dart** (lines 167-190)
   - Updated `_navigateToAction()` to map actionType to chatType
   - Pass mapped chatType to `SessionService.resetSession()`

## Review

Successfully implemented chatType parameter throughout the session creation flow:
- When user clicks "Project doorgeven", chatType "project_doorgeven" is sent in webhook
- When user clicks "Vakkennis delen", chatType "vakkennis_delen" is sent in webhook
- When user clicks "Social media", chatType "social_media" is sent in webhook
- All parameters are optional/nullable for backward compatibility
- Response parsing handles both snake_case (`chat_type`) and camelCase (`chatType`) formats
