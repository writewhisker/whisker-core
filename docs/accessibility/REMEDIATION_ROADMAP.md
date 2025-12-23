# Accessibility Remediation Roadmap

**Created**: 2024-12-21
**Target**: WCAG 2.1 Level AA Compliance

## Overview

This roadmap outlines the prioritized fixes needed to achieve WCAG 2.1 Level AA compliance for the whisker-core web player. Fixes are organized by priority and mapped to implementation stages in Phase A.

## Priority 1: Quick Wins

**Effort**: Low | **Impact**: High | **Target**: Stage 3-4

### QW-1: Add ARIA Live Region

**WCAG**: 4.1.3 Status Messages
**Location**: Main player container

```html
<!-- Add hidden live region for announcements -->
<div id="a11y-live"
     role="status"
     aria-live="polite"
     aria-atomic="true"
     class="sr-only">
</div>
```

**Implementation**:
```javascript
function announce(message) {
  const liveRegion = document.getElementById('a11y-live');
  liveRegion.textContent = message;
}

// Use when navigating passages
announce(`Navigated to: ${passage.title}`);
```

### QW-2: Add Skip Link

**WCAG**: 2.4.1 Bypass Blocks
**Location**: Start of body

```html
<a href="#main-content" class="skip-link">
  Skip to story content
</a>
```

```css
.skip-link {
  position: absolute;
  top: -40px;
  left: 0;
  padding: 8px 16px;
  background: #0066CC;
  color: white;
  z-index: 1000;
}

.skip-link:focus {
  top: 0;
}
```

### QW-3: Add Visible Focus Indicators

**WCAG**: 2.4.7 Focus Visible, 1.4.11 Non-text Contrast
**Location**: Global CSS

```css
/* High visibility focus ring */
:focus-visible {
  outline: 3px solid #0066CC;
  outline-offset: 2px;
}

/* Button-specific focus */
button:focus-visible,
.choice-btn:focus-visible {
  outline: 3px solid #0066CC;
  outline-offset: 2px;
  box-shadow: 0 0 0 6px rgba(0, 102, 204, 0.2);
}

/* Remove default outline for mouse users */
:focus:not(:focus-visible) {
  outline: none;
}
```

### QW-4: Add Landmark Regions

**WCAG**: 1.3.1 Info and Relationships
**Location**: Player structure

```html
<header role="banner">
  <h1 id="story-title">Story Title</h1>
</header>

<nav aria-label="Story controls">
  <button>Restart</button>
  <button>Save</button>
  <button>Settings</button>
</nav>

<main id="main-content" aria-label="Story content">
  <article id="passage" aria-live="polite">
    <!-- Passage content -->
  </article>

  <section aria-label="Story choices">
    <!-- Choices -->
  </section>
</main>

<aside aria-label="Story statistics">
  <!-- Stats panel -->
</aside>
```

### QW-5: Add Heading Structure

**WCAG**: 2.4.6 Headings and Labels
**Location**: Passage rendering

```javascript
// When rendering passage
const passageContent = `
  <h2 id="passage-title">${passage.title}</h2>
  <div id="passage-content">${content}</div>
`;
```

## Priority 2: Structural Improvements

**Effort**: Medium | **Impact**: High | **Target**: Stage 4-5

### SI-1: Semantic Choice List

**WCAG**: 1.3.1 Info and Relationships, 4.1.2 Name, Role, Value

```html
<ul role="list" aria-label="Available choices">
  <li role="listitem">
    <button type="button" class="choice-btn" data-choice-index="0">
      Go north
    </button>
  </li>
  <li role="listitem">
    <button type="button" class="choice-btn" data-choice-index="1">
      Go south
    </button>
  </li>
</ul>
```

**With count announcement**:
```javascript
function renderChoices(choices) {
  announce(`${choices.length} choices available`);
  // ... render choices
}
```

### SI-2: Focus Management on Navigation

**WCAG**: 2.4.3 Focus Order
**Location**: Navigation logic

```javascript
goToPassage(passageId) {
  // ... existing logic ...

  // After rendering new passage
  requestAnimationFrame(() => {
    const passageTitle = document.getElementById('passage-title');
    if (passageTitle) {
      passageTitle.focus();
    }
    announce(`Now at: ${passage.title}`);
  });
}
```

### SI-3: Loading State Announcements

**WCAG**: 4.1.3 Status Messages

```javascript
function showLoading() {
  loadingElement.style.display = 'block';
  loadingElement.setAttribute('aria-busy', 'true');
  announce('Loading story...');
}

function hideLoading() {
  loadingElement.style.display = 'none';
  loadingElement.setAttribute('aria-busy', 'false');
  announce('Story loaded');
}
```

## Priority 3: Enhanced Navigation

**Effort**: Medium | **Impact**: Medium | **Target**: Stage 5-6

### EN-1: Arrow Key Choice Navigation

**WCAG**: 2.1.1 Keyboard (enhancement)

```javascript
class ChoiceListNavigator {
  constructor(container) {
    this.container = container;
    this.choices = [];
    this.currentIndex = 0;
    this.init();
  }

  init() {
    this.choices = Array.from(this.container.querySelectorAll('.choice-btn'));
    this.container.addEventListener('keydown', this.handleKeyDown.bind(this));
    this.updateTabIndices();
  }

  handleKeyDown(event) {
    switch (event.key) {
      case 'ArrowDown':
      case 'ArrowRight':
        this.moveToNext();
        event.preventDefault();
        break;
      case 'ArrowUp':
      case 'ArrowLeft':
        this.moveToPrevious();
        event.preventDefault();
        break;
      case 'Home':
        this.moveToFirst();
        event.preventDefault();
        break;
      case 'End':
        this.moveToLast();
        event.preventDefault();
        break;
    }
  }

  moveToNext() {
    const nextIndex = (this.currentIndex + 1) % this.choices.length;
    this.setFocus(nextIndex);
  }

  moveToPrevious() {
    const prevIndex = (this.currentIndex - 1 + this.choices.length) % this.choices.length;
    this.setFocus(prevIndex);
  }

  moveToFirst() {
    this.setFocus(0);
  }

  moveToLast() {
    this.setFocus(this.choices.length - 1);
  }

  setFocus(index) {
    this.choices[this.currentIndex].setAttribute('tabindex', '-1');
    this.currentIndex = index;
    this.choices[this.currentIndex].setAttribute('tabindex', '0');
    this.choices[this.currentIndex].focus();
  }

  updateTabIndices() {
    this.choices.forEach((choice, index) => {
      choice.setAttribute('tabindex', index === 0 ? '0' : '-1');
    });
  }
}
```

### EN-2: Keyboard Shortcut Help

```html
<button aria-describedby="shortcuts-help">
  Keyboard Shortcuts
</button>

<div id="shortcuts-help" role="tooltip" hidden>
  <ul>
    <li>Ctrl+S: Save game</li>
    <li>Ctrl+Z: Undo</li>
    <li>Ctrl+L: Load game</li>
    <li>Arrow keys: Navigate choices</li>
    <li>Enter/Space: Select choice</li>
  </ul>
</div>
```

## Priority 4: Visual Accessibility

**Effort**: Medium | **Impact**: Medium | **Target**: Stage 10-11

### VA-1: High Contrast Mode Support

```css
@media (forced-colors: active) {
  .choice-btn {
    border: 2px solid CanvasText;
  }

  .choice-btn:focus {
    outline: 3px solid Highlight;
  }

  .passage {
    background: Canvas;
    color: CanvasText;
  }
}
```

### VA-2: Reduced Motion Support

```css
@media (prefers-reduced-motion: reduce) {
  *,
  *::before,
  *::after {
    animation-duration: 0.01ms !important;
    animation-iteration-count: 1 !important;
    transition-duration: 0.01ms !important;
  }

  .loading-spinner {
    animation: none;
  }
}
```

## Implementation Schedule

| Stage | Fixes Implemented | Target Compliance |
|-------|-------------------|-------------------|
| Stage 3 | QW-1, QW-2, QW-3 | 60% Level AA |
| Stage 4 | QW-4, QW-5, SI-1 | 70% Level AA |
| Stage 5 | SI-2, EN-1 | 80% Level AA |
| Stage 6 | EN-1 refinement | 85% Level AA |
| Stage 7 | SI-2 refinement | 90% Level AA |
| Stage 8 | Testing & fixes | 95% Level AA |
| Stage 10-11 | VA-1, VA-2 | 100% Level AA |

## Verification Checklist

After each stage, verify:

- [ ] Automated tests pass (axe-core)
- [ ] Keyboard navigation works for all interactive elements
- [ ] Focus visible on all focusable elements
- [ ] Screen reader announces dynamic content changes
- [ ] Skip link works correctly
- [ ] Landmarks properly identified by screen reader
- [ ] Headings create logical outline
- [ ] Color contrast meets 4.5:1 minimum
