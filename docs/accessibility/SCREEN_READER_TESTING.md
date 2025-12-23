# Screen Reader Testing Guide

This guide provides comprehensive procedures for testing the whisker-core web player with screen readers. Testing with actual assistive technologies is the ultimate validation of accessibility implementation.

## Testing Environments

### Primary: NVDA + Firefox (Windows)
- **Why**: Free, widely used, excellent standards compliance
- **Setup**: NVDA 2023.3+, Firefox 120+
- **Usage**: Represents typical Windows screen reader user

### Secondary: JAWS + Chrome (Windows)
- **Why**: Enterprise standard, most feature-rich
- **Setup**: JAWS 2024 (trial available), Chrome 120+
- **Usage**: Represents professional/enterprise users

### macOS: VoiceOver + Safari
- **Why**: Built-in macOS screen reader
- **Setup**: macOS 14+ built-in VoiceOver, Safari 17+
- **Usage**: Represents Apple ecosystem users

### Mobile: iOS VoiceOver
- **Why**: Mobile accessibility validation
- **Setup**: iOS 17+ built-in VoiceOver, Mobile Safari
- **Usage**: Represents mobile users

---

## NVDA + Firefox Testing

### Setup

1. **Install NVDA** (free):
   - Download from: https://www.nvaccess.org/download/
   - Version: 2023.3 or later
   - Install with default settings

2. **Configure NVDA**:
   - NVDA Menu > Preferences > Settings
   - Speech: Select voice (eSpeak NG recommended for testing)
   - Keyboard: Check "Use CapsLock as NVDA modifier key"
   - Browse mode: Set mode to "Automatic"

3. **Install Firefox**:
   - Version: 120 or later
   - Set as default browser for testing

### Basic NVDA Commands

| Action | Keys |
|--------|------|
| Start NVDA | Ctrl+Alt+N |
| Stop NVDA | NVDA+Q |
| Toggle speech on/off | NVDA+S |
| Read current line | NVDA+Up Arrow |
| Read all from cursor | NVDA+Down Arrow |
| Next heading | H |
| Previous heading | Shift+H |
| Next link | K |
| Previous link | Shift+K |
| Next button | B |
| Previous button | Shift+B |
| Next form field | F |
| Next list | L |
| Next list item | I |
| Elements list | NVDA+F7 |
| Browse/Focus mode toggle | NVDA+Space |

### Testing Procedure

#### Test 1: Page Load and Structure

**Steps**:
1. Launch Firefox and navigate to whisker-core player
2. Start NVDA (Ctrl+Alt+N)
3. Press NVDA+Down Arrow (read from top)

**Expected Behavior**:
- [ ] Page title announced
- [ ] "Skip to main content" link announced first
- [ ] Story controls navigation announced as "navigation"
- [ ] Main content region announced as "main"
- [ ] Story title heading announced as "heading level 1"
- [ ] Current passage announced

**What to Listen For**:
- Clear announcement of page structure
- Logical reading order
- All headings announced with correct level
- Landmarks identified ("navigation", "main")

#### Test 2: Heading Navigation

**Steps**:
1. Press H key repeatedly to navigate by headings

**Expected Behavior**:
- [ ] Story title (H1) announced
- [ ] Passage title (H2) announced
- [ ] "Available choices" heading announced (may be visually hidden)
- [ ] Settings dialog heading (H2) when opened
- [ ] No skipped heading levels

**What to Listen For**:
- Heading text and level announced ("Heading level 2, The Crossroads")
- Logical hierarchy (H1 → H2 → H3, no skips)

#### Test 3: Landmark Navigation

**Steps**:
1. Press D key to navigate by landmarks

**Expected Behavior**:
- [ ] Navigation landmark announced ("navigation, Story controls")
- [ ] Main landmark announced ("main, Story content")
- [ ] Complementary landmarks (aside) announced if present
- [ ] Footer landmark announced (if present)

**What to Listen For**:
- Landmark type and label announced
- Ability to skip between major page regions

#### Test 4: Button Navigation

**Steps**:
1. Press B key to navigate to buttons
2. Test each button activation

**Expected Behavior**:
- [ ] Restart button announced with label
- [ ] Save button announced with label
- [ ] Settings button announced with label
- [ ] Choice buttons announced with text
- [ ] All buttons activatable with Enter/Space

**What to Listen For**:
- "Button" role announced
- Descriptive button text
- State if relevant (e.g., "pressed" for toggle buttons)

#### Test 5: Choice Selection

**Steps**:
1. Navigate to story passage with choices
2. Press B or Down Arrow to reach first choice
3. Press Enter to select choice
4. Listen for passage change announcement

**Expected Behavior**:
- [ ] Choices announced as buttons or options
- [ ] Choice text clearly read
- [ ] Position indicated ("Choice 1 of 3")
- [ ] Passage change announced when choice selected
- [ ] New passage content read automatically

**What to Listen For**:
- Choice list identified (possibly as "list" or "listbox")
- "X of Y choices available" context
- Smooth transition announcement after selection

#### Test 6: Modal Dialog

**Steps**:
1. Navigate to and activate Settings button
2. Listen for dialog announcement
3. Navigate within dialog
4. Close dialog with Escape or Cancel

**Expected Behavior**:
- [ ] Dialog opening announced
- [ ] Dialog title announced
- [ ] Focus moved to dialog
- [ ] Form fields properly labeled
- [ ] Close button findable and activatable
- [ ] Dialog closing announced
- [ ] Focus restored to Settings button

**What to Listen For**:
- "Dialog" role announced
- "Settings, dialog" or similar
- Form field labels read before field
- Exit from dialog returns focus correctly

#### Test 7: Form Interaction

**Steps**:
1. Open Settings dialog
2. Navigate through form fields with Tab/F
3. Change settings values
4. Save or cancel

**Expected Behavior**:
- [ ] Labels announced before fields
- [ ] Current values announced
- [ ] Required fields indicated
- [ ] Error messages associated with fields
- [ ] Fieldset legends announced

**What to Listen For**:
- "Label text, combo box" or "Label text, checkbox"
- Current selected value
- Changes announced as they're made

#### Test 8: Live Region Announcements

**Steps**:
1. Select a story choice
2. Listen for passage change announcement
3. Trigger loading state (if applicable)
4. Trigger error state

**Expected Behavior**:
- [ ] Passage changes announced politely
- [ ] "New passage: [title]" announced
- [ ] Choice count announced ("3 choices available")
- [ ] Loading state announced
- [ ] Errors announced assertively

**What to Listen For**:
- Announcements occur without needing to navigate
- Announcements don't interrupt current reading (polite)
- Errors do interrupt current reading (assertive)
- Announcements are concise (1-2 sentences)

#### Test 9: Browse vs. Focus Mode

**Steps**:
1. Start in Browse mode (default)
2. Navigate to a form field or button
3. Verify automatic switch to Focus mode
4. Press NVDA+Space to manually toggle

**Expected Behavior**:
- [ ] Automatic switch to Focus mode for forms/buttons
- [ ] Arrow keys work for choice navigation in Focus mode
- [ ] Can return to Browse mode with NVDA+Space

**What to Listen For**:
- "Focus mode" announcement when entering interactive element
- "Browse mode" announcement when leaving

#### Test 10: Elements List (NVDA+F7)

**Steps**:
1. Press NVDA+F7 to open elements list
2. Select "Headings" tab
3. Select "Links" tab
4. Select "Buttons" tab

**Expected Behavior**:
- [ ] All headings listed with levels
- [ ] All buttons listed with names
- [ ] Selecting item navigates to it
- [ ] List accurately reflects page structure

---

## JAWS + Chrome Testing

### JAWS-Specific Commands

| Action | Keys |
|--------|------|
| Next heading | H |
| Next button | B |
| Next form field | F |
| Next list | L |
| Forms list | Insert+F5 |
| Headings list | Insert+F6 |
| Links list | Insert+F7 |
| Say all | Insert+Down Arrow |
| Read current line | Insert+Up Arrow |

### JAWS-Specific Behavior

- **Verbosity**: JAWS is more verbose than NVDA by default
  - Announces more role information
  - Provides more context
  - May announce ARIA more explicitly

- **Form Mode**: Similar to NVDA's Focus mode
  - Automatically enters form mode for form fields
  - Exit with Num Pad Plus

- **Virtual Cursor**: JAWS uses virtual cursor in browse mode
  - Arrow keys navigate by line
  - Quick keys (H, B, F, etc.) jump by element type

### Testing Focus Areas

Focus JAWS testing on:
1. Verbosity differences (is too much being announced?)
2. Form mode transitions
3. Dynamic content announcement timing
4. ARIA support differences

---

## VoiceOver + Safari Testing (macOS)

### Setup

1. **Enable VoiceOver**:
   - System Settings > Accessibility > VoiceOver
   - Turn on VoiceOver (Cmd+F5)

2. **VoiceOver Training**:
   - Complete VoiceOver tutorial (recommended)
   - Cmd+F5 to toggle VoiceOver on/off

### Basic VoiceOver Commands

| Action | Keys |
|--------|------|
| Start/Stop VoiceOver | Cmd+F5 |
| VoiceOver modifier | Ctrl+Option (VO) |
| Next item | VO+Right Arrow |
| Previous item | VO+Left Arrow |
| Activate item | VO+Space |
| Read from current position | VO+A |
| Next heading | VO+Cmd+H |
| Open rotor | VO+U |
| Web rotor | VO+U (then arrow keys) |

### VoiceOver Rotor Navigation

**Steps**:
1. Open whisker-core player in Safari
2. Start VoiceOver (Cmd+F5)
3. Press VO+U to open rotor
4. Use Left/Right arrows to switch rotor categories
5. Use Up/Down arrows to navigate items

**Expected Behavior**:
- [ ] Headings category shows all headings
- [ ] Landmarks category shows navigation, main, footer
- [ ] Form controls category shows all interactive elements
- [ ] Links category shows all links

### VoiceOver-Specific Issues

**List Announcements**:
- VoiceOver may not announce lists as lists without explicit role="list"
- Solution: Added `role="list"` to `<ul>` elements

**Automatic Announcements**:
- VoiceOver may not respect aria-live="polite" timing
- Solution: Added appropriate delays for announcements

---

## iOS VoiceOver Testing

### Setup
1. Settings > Accessibility > VoiceOver
2. Enable VoiceOver
3. Triple-click home/side button to toggle

### Basic Gestures

| Action | Gesture |
|--------|---------|
| Next item | Swipe right |
| Previous item | Swipe left |
| Activate | Double tap |
| Read all | Two-finger swipe down |
| Open rotor | Rotate two fingers |

### Testing Focus

1. Touch exploration (tap around screen)
2. Swipe navigation through all elements
3. Double-tap activation of choices
4. Rotor navigation

**Expected Behavior**:
- [ ] All interactive elements reachable by swiping
- [ ] Choice selection works with double-tap
- [ ] Passage changes announced
- [ ] Navigation buttons accessible
- [ ] Touch targets at least 44x44px

---

## Common Issues and Resolutions

### Button Not Announced as Button
- **Cause**: Using div with onclick instead of button element
- **Fix**: Use semantic `<button>` element

### Passage Changes Not Announced
- **Cause**: Live region not configured or text not changing
- **Fix**: Ensure aria-live="polite" and content changes

### Choice Context Not Clear
- **Cause**: Choices not in list structure
- **Fix**: Use `<ul role="list">` with `<li role="listitem">`

### Form Fields Not Labeled
- **Cause**: Missing `<label>` or aria-label
- **Fix**: Associate label with for/id or add aria-label

### Dialog Opening Not Announced
- **Cause**: Missing role="dialog" or focus not moved
- **Fix**: Add role="dialog", aria-modal="true", move focus

### Navigation Too Verbose
- **Cause**: Redundant ARIA or overly detailed labels
- **Fix**: Simplify labels, remove redundant ARIA

---

## Regression Testing Checklist

After code changes, re-test:

- [ ] Page load and structure announced correctly
- [ ] Heading navigation works (H key)
- [ ] Landmark navigation works (D key)
- [ ] All buttons navigable and activatable
- [ ] Choice selection and passage changes work
- [ ] Modal dialogs trap focus properly
- [ ] Live region announcements fire correctly
- [ ] Focus mode transitions work
- [ ] Elements list accurately reflects page

---

## Tips for Effective Testing

1. **Learn the screen reader first** - Spend time with tutorials before testing
2. **Test with sound only** - Close your eyes or turn off monitor periodically
3. **Test common user flows** - Focus on realistic usage patterns
4. **Document everything** - Record issues with exact reproduction steps
5. **Test after every change** - Accessibility can break easily
6. **Recruit actual users** - Nothing beats testing with real screen reader users
