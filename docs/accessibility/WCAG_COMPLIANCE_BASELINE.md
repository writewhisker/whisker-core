# WCAG 2.1 Compliance Baseline

**Date**: 2024-12-21
**Target Level**: AA
**Current Status**: PARTIAL COMPLIANCE

## Compliance Summary

| Level | Criteria | Compliant | Partial | Fail | N/A |
|-------|----------|-----------|---------|------|-----|
| A     | 30       | 18        | 5       | 5    | 2   |
| AA    | 20       | 8         | 4       | 6    | 2   |

**Overall Score**: ~52% Level AA Compliant

## Level A Criteria Status

### Perceivable

| Criterion | Status | Notes |
|-----------|--------|-------|
| 1.1.1 Non-text Content | PARTIAL | Loading spinner needs label |
| 1.2.1 Audio-only/Video-only | N/A | No audio/video content |
| 1.2.2 Captions | N/A | No audio/video content |
| 1.2.3 Audio Description | N/A | No audio/video content |
| 1.3.1 Info and Relationships | FAIL | Missing landmarks, list structure |
| 1.3.2 Meaningful Sequence | PASS | DOM order matches visual |
| 1.3.3 Sensory Characteristics | PASS | No sensory-dependent instructions |
| 1.4.1 Use of Color | PASS | Color not sole indicator |
| 1.4.2 Audio Control | N/A | No auto-playing audio |

### Operable

| Criterion | Status | Notes |
|-----------|--------|-------|
| 2.1.1 Keyboard | PARTIAL | Basic keyboard works, no arrow nav |
| 2.1.2 No Keyboard Trap | PASS | No keyboard traps |
| 2.1.4 Character Key Shortcuts | PASS | Shortcuts use modifiers |
| 2.2.1 Timing Adjustable | PASS | No time limits |
| 2.2.2 Pause, Stop, Hide | PASS | No auto-updating content |
| 2.3.1 Three Flashes | PASS | No flashing content |
| 2.4.1 Bypass Blocks | FAIL | No skip link |
| 2.4.2 Page Titled | PASS | Descriptive title present |
| 2.4.3 Focus Order | PARTIAL | Order OK, management needs work |
| 2.4.4 Link Purpose | PASS | Button text is descriptive |
| 2.5.1 Pointer Gestures | PASS | Click only, no gestures |
| 2.5.2 Pointer Cancellation | PASS | Standard click behavior |
| 2.5.3 Label in Name | PASS | Button text is accessible name |
| 2.5.4 Motion Actuation | PASS | No motion activation |

### Understandable

| Criterion | Status | Notes |
|-----------|--------|-------|
| 3.1.1 Language of Page | PASS | lang="en" present |
| 3.2.1 On Focus | PASS | No context change on focus |
| 3.2.2 On Input | PASS | User-initiated navigation |
| 3.3.1 Error Identification | N/A | No form inputs |
| 3.3.2 Labels or Instructions | N/A | No form inputs |

### Robust

| Criterion | Status | Notes |
|-----------|--------|-------|
| 4.1.1 Parsing | PASS | Valid HTML |
| 4.1.2 Name, Role, Value | PARTIAL | Buttons OK, structure needs ARIA |

## Level AA Criteria Status

### Perceivable

| Criterion | Status | Notes |
|-----------|--------|-------|
| 1.2.4 Captions (Live) | N/A | No live audio |
| 1.2.5 Audio Description | N/A | No video |
| 1.3.4 Orientation | PASS | Works in any orientation |
| 1.3.5 Identify Input Purpose | N/A | No form inputs |
| 1.4.3 Contrast (Minimum) | PARTIAL | Needs verification |
| 1.4.4 Resize Text | PASS | Text scales properly |
| 1.4.5 Images of Text | PASS | No images of text |
| 1.4.10 Reflow | PASS | Responsive layout |
| 1.4.11 Non-text Contrast | FAIL | Focus indicators weak |
| 1.4.12 Text Spacing | PASS | No fixed spacing |
| 1.4.13 Content on Hover/Focus | PASS | No hover content |

### Operable

| Criterion | Status | Notes |
|-----------|--------|-------|
| 2.4.5 Multiple Ways | PARTIAL | Single navigation method |
| 2.4.6 Headings and Labels | FAIL | No heading structure |
| 2.4.7 Focus Visible | FAIL | Focus indicators not custom |

### Understandable

| Criterion | Status | Notes |
|-----------|--------|-------|
| 3.1.2 Language of Parts | PASS | Single language content |
| 3.2.3 Consistent Navigation | PASS | Consistent UI placement |
| 3.2.4 Consistent Identification | PASS | Consistent button naming |
| 3.3.3 Error Suggestion | N/A | No form inputs |
| 3.3.4 Error Prevention | N/A | No form submissions |

### Robust

| Criterion | Status | Notes |
|-----------|--------|-------|
| 4.1.3 Status Messages | FAIL | Passage changes not announced |

## Critical Gaps Summary

### Must Fix for Level A

1. **1.3.1 Info and Relationships**
   - Add landmark regions (`<nav>`, `<main>`)
   - Structure choices as semantic list
   - Add heading hierarchy

2. **2.4.1 Bypass Blocks**
   - Add skip link to main content

3. **4.1.2 Name, Role, Value**
   - Add ARIA roles to dynamic content

### Must Fix for Level AA

1. **1.4.11 Non-text Contrast**
   - Add visible focus indicators (3:1 minimum)

2. **2.4.6 Headings and Labels**
   - Add heading structure to passages
   - Label choice sections

3. **2.4.7 Focus Visible**
   - Implement custom focus indicators

4. **4.1.3 Status Messages**
   - Add ARIA live region
   - Announce passage changes
   - Announce loading/error states

## Remediation Priority

| Priority | Criterion | Impact | Effort |
|----------|-----------|--------|--------|
| 1 | 4.1.3 Status Messages | High | Low |
| 2 | 2.4.7 Focus Visible | High | Low |
| 3 | 2.4.1 Bypass Blocks | Medium | Low |
| 4 | 1.3.1 Info and Relationships | High | Medium |
| 5 | 2.4.6 Headings and Labels | Medium | Low |
| 6 | 1.4.11 Non-text Contrast | Medium | Low |

## Target Timeline

- **After Stage 3-4**: 70% Level AA compliance
- **After Stage 7**: 90% Level AA compliance
- **After Stage 8**: 100% Level AA compliance
