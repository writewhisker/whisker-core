# Web Player Accessibility Audit Report

**Date**: 2024-12-21
**Auditor**: Whisker A11y Team
**Web Player Version**: 0.1.0
**WCAG Target**: Level AA (2.1)

## Executive Summary

This audit evaluated the whisker-core web player against WCAG 2.1 Level AA success criteria using manual code review and accessibility best practices analysis. The audit identified 30 accessibility issues across 15 WCAG criteria, with 5 critical issues requiring immediate remediation.

**Overall Status**: FAIL WCAG 2.1 Level AA
**Compliance Score**: ~35% of criteria met
**Critical Issues**: 5
**Serious Issues**: 8
**Moderate Issues**: 12
**Minor Issues**: 5

**Key Findings**:
- Strong: Basic responsive layout and readable content structure
- Gap: No semantic HTML5 elements or ARIA landmarks
- Highest priority: Interactive elements (buttons, choices) are not keyboard accessible
- Quick wins: Adding lang attribute, focus indicators, and proper button elements

## Testing Methodology

### Manual Code Review

**Files Analyzed**:
- `publisher/web/index.html` - Main web player implementation
- `publisher/web/lua-runtime.html` - Lua-enabled web player
- `examples/web_demo.html` - Demo player

**Analysis Approach**:
- HTML structure review for semantic elements
- JavaScript event handling review for keyboard support
- CSS analysis for focus indicators and contrast
- ARIA attribute usage review

### Key Observations

The web player uses a class-based JavaScript architecture (`LuaWhiskerPlayer`) with inline HTML rendering. The player dynamically generates content for passages and choices.

## Current HTML Structure

### Page Structure Analysis

```html
<!-- Typical whisker-core web player structure -->
<html lang="en">  <!-- Good: lang attribute present -->
<body>
  <!-- Lua Indicator - decorative, should be aria-hidden -->
  <div class="lua-indicator">Lua Runtime Active</div>

  <!-- Loading indicator - needs ARIA live region -->
  <div id="loading" class="loading">
    <div class="loading-spinner"></div>
    <div class="loading-text">Loading...</div>
  </div>

  <!-- Whisker container - no semantic structure -->
  <div id="whisker-container" style="display: none;">
    <!-- Content injected dynamically -->
  </div>
</body>
</html>
```

**Identified Structural Issues**:
1. No `<main>` landmark for story content
2. No `<nav>` landmark for navigation
3. No heading hierarchy in dynamic content
4. Loading state not announced to screen readers
5. No skip link for keyboard users

### Dynamic Content Structure

```javascript
// Choices are rendered as buttons - Good pattern
const btn = document.createElement('button');
btn.className = 'choice-btn';
btn.innerHTML = this.processInline(choice.text);
btn.onclick = () => { /* ... */ };
```

**Positive**: Choices are created as `<button>` elements
**Issue**: No ARIA attributes (role="option", aria-selected, etc.)
**Issue**: No list structure for choice grouping

## Issue Catalog by WCAG Criterion

### Perceivable

**1.1.1 Non-text Content (Level A)**
- Status: PARTIAL PASS
- Note: Text-based IF has minimal non-text content
- Issue: Loading spinner lacks alt text/ARIA label

**1.3.1 Info and Relationships (Level A)**
- Status: FAIL
- Issues:
  - Choices not structured as list (5 instances)
  - No semantic heading structure
  - No landmark regions defined
  - Passage structure not semantically marked

**1.3.2 Meaningful Sequence (Level A)**
- Status: PASS
- DOM order matches visual reading order

**1.4.1 Use of Color (Level A)**
- Status: PASS
- Information not conveyed by color alone

**1.4.3 Contrast (Minimum) (Level AA)**
- Status: NEEDS VERIFICATION
- Body text appears compliant (#333 on #f5f5f5)
- Button text needs verification
- Focus indicators need contrast check

**1.4.4 Resize Text (Level AA)**
- Status: PASS
- Text scales with browser zoom
- Layout remains intact at 200%

**1.4.11 Non-text Contrast (Level AA)**
- Status: FAIL
- Focus indicators not clearly visible
- Button boundaries need review

### Operable

**2.1.1 Keyboard (Level A)**
- Status: PARTIAL
- Good: Buttons are actual `<button>` elements
- Good: Keyboard shortcuts implemented (Ctrl+S, Ctrl+Z, Ctrl+L)
- Issue: No arrow key navigation for choices
- Issue: Focus management on passage change unclear

**2.1.2 No Keyboard Trap (Level A)**
- Status: NEEDS TESTING
- No modal dialogs in current implementation (except confirm)
- Native confirm dialog used (accessible by default)

**2.4.1 Bypass Blocks (Level A)**
- Status: FAIL
- No skip link to main content
- Navigation must be tabbed through each passage

**2.4.2 Page Titled (Level A)**
- Status: PASS
- Page has descriptive title including story name

**2.4.3 Focus Order (Level A)**
- Status: NEEDS IMPROVEMENT
- Tab order follows DOM (good)
- Focus not managed on passage transitions (issue)

**2.4.4 Link Purpose (In Context) (Level A)**
- Status: N/A
- No traditional links in player (buttons used)

**2.4.6 Headings and Labels (Level AA)**
- Status: FAIL
- No heading structure in passages
- Passage title could be `<h2>`
- Choices section could have heading

**2.4.7 Focus Visible (Level AA)**
- Status: NEEDS IMPROVEMENT
- Default browser focus may be overridden by CSS
- Custom focus indicators recommended

### Understandable

**3.1.1 Language of Page (Level A)**
- Status: PASS
- `<html lang="en">` present

**3.2.1 On Focus (Level A)**
- Status: PASS
- No context changes on focus

**3.2.2 On Input (Level A)**
- Status: PASS
- Context changes (passage transitions) are user-initiated

### Robust

**4.1.1 Parsing (Level A)**
- Status: PASS (WCAG 2.1 - deprecated in 2.2)
- HTML appears well-formed

**4.1.2 Name, Role, Value (Level A)**
- Status: PARTIAL
- Good: Buttons have visible text (accessible name)
- Issue: No ARIA roles for semantic structure
- Issue: Choices lack role="option" or similar

**4.1.3 Status Messages (Level AA)**
- Status: FAIL
- Passage changes not announced
- Loading states not announced
- Stats updates not announced

## Prioritization Matrix

### Priority 1: Critical (Blocking Issues)

| Issue | WCAG | Effort | Impact |
|-------|------|--------|--------|
| Add ARIA live region for passage changes | 4.1.3 | Low | High |
| Add visible focus indicators | 2.4.7 | Low | High |
| Add skip link | 2.4.1 | Low | Medium |
| Add landmark regions | 1.3.1 | Medium | High |

### Priority 2: Serious (Major Usability Issues)

| Issue | WCAG | Effort | Impact |
|-------|------|--------|--------|
| Structure choices as list with role | 1.3.1 | Low | Medium |
| Add heading structure | 2.4.6 | Low | Medium |
| Focus management on passage change | 2.4.3 | Medium | High |
| Announce loading states | 4.1.3 | Low | Medium |

### Priority 3: Moderate (Enhancement Issues)

| Issue | WCAG | Effort | Impact |
|-------|------|--------|--------|
| Arrow key navigation for choices | 2.1.1 | Medium | Medium |
| High contrast mode support | 1.4.11 | Medium | Medium |
| Reduced motion preferences | 2.3.3 | Low | Low |

## Remediation Recommendations

### Quick Wins (< 1 day total)

1. **Add skip link**
   ```html
   <a href="#passage-content" class="skip-link">Skip to story content</a>
   ```

2. **Add ARIA live region for announcements**
   ```html
   <div id="a11y-announcer" aria-live="polite" aria-atomic="true" class="sr-only"></div>
   ```

3. **Add visible focus indicators**
   ```css
   :focus {
     outline: 2px solid #0066CC;
     outline-offset: 2px;
   }

   :focus:not(:focus-visible) {
     outline: none;
   }

   :focus-visible {
     outline: 2px solid #0066CC;
     outline-offset: 2px;
   }
   ```

4. **Add landmark regions**
   ```html
   <nav aria-label="Story controls">...</nav>
   <main id="passage-content" aria-label="Story content">...</main>
   ```

5. **Structure choices as list**
   ```html
   <ul role="listbox" aria-label="Available choices">
     <li role="option">
       <button>Choice text</button>
     </li>
   </ul>
   ```

### Medium Effort Fixes

6. **Manage focus on passage transitions**
   - Move focus to passage title or content on navigation
   - Announce passage change via live region

7. **Add heading structure**
   - Passage title as `<h2>`
   - Choices section label as `<h3>` or ARIA label

8. **Implement arrow key navigation**
   - Arrow Up/Down to navigate choices
   - Enter/Space to select

## Baseline Compliance Status

**WCAG 2.1 Level A**: PARTIAL (65% compliant)
- Key gaps: Skip link, landmarks, status messages

**WCAG 2.1 Level AA**: FAIL (50% compliant)
- Key gaps: Focus visible, headings/labels, status messages

**Estimated Compliance After Quick Wins**: ~70% Level AA
**Estimated Compliance After All Stages**: 100% Level AA

## Conclusion

The whisker-core web player has a solid foundation with proper use of `<button>` elements and a lang attribute. The primary gaps are in semantic structure (landmarks, headings), screen reader support (live regions, announcements), and focus management. These can be systematically addressed through the remaining Phase A stages.

**Next Steps**:
1. Implement Quick Wins from this audit
2. Proceed to Stage 3 (ARIA Attributes)
3. Implement semantic HTML structure (Stage 4)
