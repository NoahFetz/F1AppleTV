# Swap to Main Player Feature

## Overview
This document describes the implementation of the "Swap to Main" feature, which allows users to swap sidebar or bottom players with the main player in `mainWithSidebar` layout mode. Additionally, sidebar and bottom players are now automatically muted when created.

## Changes Made

### 1. ControlStripActionProtocol.swift
- ✅ Protocol already includes `swapToMainPlayer()` method

### 2. ControlStripOverlayViewController.swift
**Added:**
- New property `swapToMainButton: UIButton?`
- New method `setupSwapToMainButton()` to create the button with swap icon (arrow.up.left.and.arrow.down.right)
- New method `swapToMainPressed()` to handle button tap
- Conditional logic in `addContentToControlsBar()` to only show button for non-main players (position != 0)

**Button Appearance:**
- Normal state: `arrow.up.left.and.arrow.down.right` system icon (outline)
- Focused state: `arrow.up.left.and.arrow.down.right.fill` system icon (filled)
- Position: After "Add Channel" button, before the first spacer
- **Visibility**: Only shown when control strip is opened for sidebar/bottom players (position != 0)
- **tvOS Fix**: Added `layoutIfNeeded()` and `contentMode = .scaleAspectFit` for proper focus highlighting

### 3. PlayerCollectionViewController+Actions.swift
**Enhanced:**
- `swapMainPlayer(to:)` method now handles audio muting/unmuting:
  - Stores references to both players before swap
  - After swap: unmutes the new main player
  - After swap: mutes the previous main player (now in sidebar)
  - Adds debug logging for audio changes

**Existing:**
- `swapToMainPlayer()` method already implemented (calls `swapMainPlayer(to:)` with focused player index)

### 4. PlayerCollectionViewController+PlayerManagement.swift
**Enhanced:**
- `didLoadStreamEntitlement(playerId:streamEntitlement:)` now auto-mutes non-main players:
  - Checks if player index is not 0 (main player)
  - Sets `player.isMuted = true` for sidebar/bottom players
  - Adds debug logging

## User Experience

### When Opening a Sidebar/Bottom Player:
1. User adds a new channel (not the first one)
2. The player loads in a sidebar or bottom position
3. **Audio is automatically muted** for this player
4. Main player continues playing with audio

### Using the Swap Button:
1. User focuses on a sidebar or bottom player
2. User swipes up to open Control Strip
3. User selects the new "Swap to Main" button (third button from left)
4. **The focused player swaps with the main player**
5. **Audio unmutes on the new main player**
6. **Audio mutes on the previous main (now sidebar) player**
7. All players sync to the main player's time
8. Layout updates to reflect new positions

## Layout Modes
This feature is specifically designed for `mainWithSidebar` mode (2-6 players):
- **1 player**: Single mode - swap button hidden (no sidebar players exist)
- **2-6 players**: Main with sidebar/bottom mode - **swap button visible on sidebar/bottom players only**
- **7+ players**: Grid mode - swap button hidden (all players equal size, no distinct main player)

## Control Strip Button Order

The button order is optimized based on the layout mode and player position, prioritizing the most relevant actions:

### Single Player Mode (playerCount = 1):
1. **Add Channel** (+ icon) ← Primary action in single player mode
2. [Spacer]
3. Rewind
4. Play/Pause
5. Forward
6. [Spacer]
7. Mute
8. Volume Slider
9. Language Selector
10. [Spacer]

### MainWithSidebar - Sidebar/Bottom Player (playerCount 2-6, position != 0):
1. **Swap to Main** (↕ icon) ← Primary action for sidebar players
2. **Fullscreen** (⤢ icon)
3. **Add Channel** (+ icon)
4. **Remove Channel** (× icon)
5. [Spacer]
6. Rewind
7. Play/Pause
8. Forward
9. [Spacer]
10. Mute
11. Volume Slider
12. Language Selector
13. [Spacer]

### MainWithSidebar - Main Player (playerCount 2-6, position = 0):
1. **Fullscreen** (⤢ icon) ← Primary action for main player
2. **Add Channel** (+ icon)
3. **Remove Channel** (× icon)
4. [Spacer]
5. Rewind
6. Play/Pause
7. Forward
8. [Spacer]
9. Mute
10. Volume Slider
11. Language Selector
12. [Spacer]

### Grid Mode (playerCount 7+):
1. **Fullscreen** (⤢ icon)
2. **Add Channel** (+ icon)
3. **Remove Channel** (× icon)
4. [Spacer]
5. Rewind
6. Play/Pause
7. Forward
8. [Spacer]
9. Mute
10. Volume Slider
11. Language Selector
12. [Spacer]

**Design Rationale:**
- **Single mode**: Add Channel is first since it's the primary action (adding more players)
- **Sidebar players**: Swap to Main is first since it's the most common action for sidebar players
- **Main/Grid players**: Fullscreen is first since it's the most common action for main players

## Technical Notes

### Audio Muting Strategy:
- **On Load**: Non-main players (index != 0) are muted in `didLoadStreamEntitlement`
- **On Swap**: Audio state is swapped along with player positions
- **User Override**: Users can still manually unmute sidebar players via the Control Strip

### Synchronization:
- After swapping, all players sync to the new main player's position
- This ensures seamless viewing experience when switching perspectives

### Layout Updates:
- Layout invalidation ensures proper positioning after swap
- Collection view reloads to update cell focus states
- Main player index always remains at 0 (array position)

## Future Enhancements (Optional)
1. Add visual indicator showing which player is main
2. Add double-tap gesture as shortcut to swap without opening Control Strip
3. Consider adding audio ducking instead of full mute for sidebar players
4. Persist user's audio preferences per channel type
