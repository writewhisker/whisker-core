# Screen Reader Quirks and Workarounds

This document catalogs known screen reader quirks and their workarounds. Use this as a reference when implementing accessibility features or debugging screen reader issues.

---

## NVDA Quirks

### Live Region Delay
**Quirk**: NVDA needs ~100ms delay after DOM change before live region triggers reliably.

**Workaround**:
```typescript
// Add delay before updating live region
setTimeout(() => {
  liveRegion.textContent = message;
}, 100);
```

### Button Name Priority
**Quirk**: If both `aria-label` and text content are present, NVDA uses `aria-label` exclusively.

**Workaround**: Choose one approach:
- Use `aria-label` for descriptive names when button text is iconic
- Use text content alone when it's sufficiently descriptive
- Use `aria-labelledby` to combine multiple text sources

### Focus Mode Auto-Switching
**Quirk**: NVDA automatically switches to Focus mode for interactive widgets, which changes arrow key behavior.

**Workaround**: Ensure roving tabindex widgets work correctly in Focus mode:
```typescript
// Arrow keys should work in focus mode
element.addEventListener('keydown', (e) => {
  if (e.key === 'ArrowDown') {
    // Handle navigation
  }
});
```

### Browse Mode Reading
**Quirk**: In Browse mode, NVDA reads content using virtual buffer, which may not reflect dynamic changes immediately.

**Workaround**: Use live regions for dynamic announcements that should be read immediately.

---

## JAWS Quirks

### Form Mode Inconsistency
**Quirk**: JAWS sometimes doesn't automatically enter form mode for custom widgets.

**Workaround**: Ensure proper roles to trigger form mode:
```html
<div role="button" tabindex="0">Click me</div>
<div role="textbox" tabindex="0" aria-label="Input">...</div>
```

### Verbosity in Tables
**Quirk**: JAWS announces table structure very verbosely ("Row 1, Column 1...").

**Workaround**: Use `role="presentation"` on layout tables that aren't data tables:
```html
<table role="presentation">...</table>
```

### aria-describedby Reading
**Quirk**: JAWS may read aria-describedby content with different timing than other screen readers.

**Workaround**: Keep descriptions concise and ensure they're not critical for immediate understanding.

### Forms List (Insert+F5)
**Quirk**: JAWS Forms List shows all interactive elements including some that shouldn't be listed.

**Workaround**: Ensure only truly interactive elements have focusable attributes.

---

## VoiceOver (macOS) Quirks

### Lists Not Announced
**Quirk**: VoiceOver doesn't always announce `<ul>` as a list.

**Workaround**: Add explicit roles:
```html
<ul role="list">
  <li role="listitem">Item 1</li>
  <li role="listitem">Item 2</li>
</ul>
```

### aria-live Timing
**Quirk**: VoiceOver may delay or skip polite announcements if the user is actively navigating.

**Workaround**:
- Use `aria-live="assertive"` for critical announcements
- Add longer delays before polite announcements
- Consider using `role="alert"` for errors

### Roving Tabindex Verbosity
**Quirk**: VoiceOver may announce both selection state and focus, causing verbosity.

**Workaround**: Carefully manage `aria-selected` updates to avoid duplicate announcements:
```typescript
// Update selection before moving focus
currentElement.setAttribute('aria-selected', 'false');
newElement.setAttribute('aria-selected', 'true');
// Brief delay before focus
setTimeout(() => newElement.focus(), 50);
```

### Web Rotor Categories
**Quirk**: VoiceOver Web Rotor may not categorize custom widgets correctly.

**Workaround**: Use semantic HTML and standard ARIA roles that VoiceOver recognizes.

### Safari Refresh Bug
**Quirk**: Sometimes VoiceOver loses its place after page content changes.

**Workaround**: Ensure focus is explicitly moved after major content changes.

---

## VoiceOver (iOS) Quirks

### Double-Tap Delay
**Quirk**: Double-tap activation has a noticeable delay before the action executes.

**Workaround**: Provide immediate visual feedback before the action completes:
```typescript
button.addEventListener('click', () => {
  // Show loading state immediately
  showLoadingIndicator();
  // Then perform action
  performAction();
});
```

### Touch Target Size
**Quirk**: Touch exploration requires large enough touch targets to be discovered.

**Workaround**: Ensure all interactive elements are at least 44x44px:
```css
button, a, [role="button"] {
  min-height: 44px;
  min-width: 44px;
}
```

### Swipe Navigation Order
**Quirk**: Swipe navigation follows DOM order, which may not match visual order.

**Workaround**: Ensure DOM order matches logical reading order. Use CSS for visual positioning if needed.

### Input Focus Issues
**Quirk**: Text input focus can be inconsistent on iOS Safari.

**Workaround**: Use explicit focus management and ensure inputs are clearly labeled.

---

## Cross-Platform Quirks

### aria-label Overrides Everything
**Quirk**: `aria-label` completely replaces an element's accessible name, including all child content.

**Workaround**: Use `aria-labelledby` when you want to combine multiple text sources:
```html
<button aria-labelledby="btn-icon btn-text">
  <span id="btn-icon" aria-hidden="true">+</span>
  <span id="btn-text">Add item</span>
</button>
```

### Live Region Must Exist at Page Load
**Quirk**: Live regions created dynamically after page load may not work in all screen readers.

**Workaround**: Create live region containers at page load, even if initially empty:
```html
<!-- Always in initial HTML -->
<div id="announcer" role="status" aria-live="polite" aria-atomic="true"></div>
<div id="alerts" role="alert" aria-live="assertive" aria-atomic="true"></div>
```

### Role Changes Not Announced
**Quirk**: Changing an element's role dynamically may not be announced.

**Workaround**: Create new elements with the correct role instead of changing existing elements.

### Hidden Content Still Read
**Quirk**: Some screen readers may still discover content that's visually hidden but in the DOM.

**Workaround**: Use `aria-hidden="true"` in addition to visual hiding:
```html
<div hidden aria-hidden="true">...</div>
```

### tabindex="0" on Non-Interactive Elements
**Quirk**: Adding `tabindex="0"` to non-interactive elements can confuse users.

**Workaround**: Only make elements focusable if they're interactive. For programmatic focus, use `tabindex="-1"`.

---

## Testing Tips

### Debugging Live Regions
1. Open browser developer tools
2. Monitor the live region element
3. Watch for `textContent` changes
4. Listen for screen reader announcements
5. Adjust timing if announcements are missed or queued

### Debugging Focus Issues
1. Use the focus debugger utility (`enableFocusDebugger()`)
2. Monitor focus events in console
3. Check `document.activeElement`
4. Verify tabindex values

### Debugging ARIA Issues
1. Use browser accessibility inspector
2. Check computed accessible name
3. Check computed accessible description
4. Verify role is correct
5. Check for ARIA validation errors

---

## Resources

- [NVDA User Guide](https://www.nvaccess.org/files/nvda/documentation/userGuide.html)
- [JAWS Quick Reference](https://www.freedomscientific.com/products/software/jaws/jaws-quick-reference/)
- [VoiceOver User Guide](https://support.apple.com/guide/voiceover/welcome/mac)
- [ARIA Authoring Practices](https://www.w3.org/WAI/ARIA/apg/)
- [WebAIM Screen Reader Survey](https://webaim.org/projects/screenreadersurvey9/)
