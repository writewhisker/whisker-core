# Accessibility Guide for Story Authors

## Introduction

This guide helps you create interactive fiction that everyone can enjoy, including people who use screen readers, keyboard navigation, or other assistive technologies. whisker-core handles most accessibility automatically, but following these guidelines ensures your stories are truly inclusive.

### Why Accessibility Matters

- **10-20% of users** have some form of disability
- **Blind and low-vision users** rely on screen readers to experience your story
- **Motor impairment users** navigate with keyboards, not mice
- **Cognitive disability users** benefit from clear structure and language
- **Accessible stories reach larger audiences** and demonstrate inclusive values

### What whisker-core Provides

whisker-core automatically handles:
- Semantic HTML structure
- Keyboard navigation (Tab, Enter, Arrow keys)
- Screen reader compatibility (NVDA, JAWS, VoiceOver)
- ARIA attributes for dynamic content
- Focus management
- High contrast mode support
- Reduced motion support

### What You Need to Do

As an author, you need to:
- Write clear, descriptive choice text
- Provide alt text for images
- Avoid relying on visual formatting alone
- Test with keyboard and screen readers
- Structure content with headings
- Use clear, simple language

---

## Basic Accessibility Principles

### 1. Write Descriptive Choice Text

**Bad**:
```
* [Click here]
* [Option 1]
* [→]
```

**Good**:
```
* [Search the drawer for clues]
* [Ask the shopkeeper about the map]
* [Leave the shop and head north]
```

**Why**: Screen readers announce choice text. "Click here" or "Option 1" doesn't tell users what the choice does.

### 2. Provide Alt Text for Images

**Bad**:
```
~ image("treasure_map.png")
```

**Good**:
```
~ image("treasure_map.png", "Ancient treasure map showing X marks the spot near the old oak tree")
```

**Why**: Blind users can't see images. Alt text describes the image content and purpose.

**Alt Text Guidelines**:
- Describe what's important about the image, not every detail
- Include text in images (if the image contains words, include them)
- Don't start with "Image of..." (screen readers announce it's an image)
- Keep it concise (1-2 sentences)

### 3. Don't Rely on Color Alone

**Bad**:
```
The red door leads to danger. The green door leads to safety.
// User can't distinguish if colorblind or using screen reader
```

**Good**:
```
The left door is painted red and has a skull carved into it.
The right door is green and has flowers growing around it.
* [Enter the ominous red door with the skull]
* [Enter the welcoming green door with flowers]
```

**Why**: Colorblind users and screen reader users can't perceive color. Always provide text descriptions.

### 4. Structure Content with Headings

**Bad**:
```
**The Forest**

You enter a dark forest...

**Inventory**

Sword, Shield, Potion
```

**Good**:
```
# The Forest

You enter a dark forest...

## Inventory

- Sword
- Shield
- Potion
```

**Why**: Screen readers can navigate by headings (H key). Headings provide structure and help users understand organization.

### 5. Use Lists for Multiple Items

**Bad**:
```
You have: Sword, Shield, Potion, Map, Compass
```

**Good**:
```
You have:
- Sword
- Shield
- Potion
- Map
- Compass
```

**Why**: Screen readers announce lists and item counts ("List with 5 items"). Makes content easier to navigate and understand.

### 6. Avoid ASCII Art for Essential Information

**Bad**:
```
    /\
   /  \
  / || \
 /  ||  \
/________\
   DOOR

* [Enter]
```

**Good**:
```
You stand before a large wooden door with an arched top and iron hinges.

* [Open the door and enter]
```

**Why**: Screen readers read ASCII art as random characters. Use text descriptions instead. ASCII art is okay for decorative purposes if you provide a text alternative.

---

## Advanced Accessibility Techniques

### Passage Titles

Give every passage a clear, descriptive title:

```
=== forest_entrance ===
# Entering the Dark Forest

You stand at the edge of a dark, imposing forest...
```

**Why**: Passage titles are announced to screen readers, helping users understand where they are in the story.

### Choice Context

Provide context with choices so they make sense out of order:

**Bad**:
```
What do you do?
* [Yes]
* [No]
```

**Good**:
```
The shopkeeper offers to sell you a map for 50 gold.
* [Buy the map for 50 gold]
* [Decline the map offer]
```

**Why**: Screen readers may read choices in a list. Each choice should make sense independently.

### Timed Choices

Avoid time-limited choices when possible. If necessary, provide warnings:

**Bad**:
```
* [Quick! Choose!] -> danger
  You have 5 seconds!
```

**Good**:
```
The boulder rolls toward you! You have 10 seconds to decide.

* [Dodge left]
* [Dodge right]
* [Duck and cover]

(Note: This is a timed choice. Screen reader users may need extra time.)
```

**Better**: Don't use timed choices at all. They're inaccessible to many users.

### Hidden Text and Spoilers

Use expandable sections instead of hidden text:

```
You examine the letter.

+ [Read the letter]
    The letter reads: "Meet me at midnight..."
    ++ [Continue]
```

**Why**: This gives all users control over when to reveal information.

### State and Inventory

Make state clear through text:

```
{has_key:
  You have the key to the locked door.
- else:
  You still need to find the key.
}
```

**Why**: Visual indicators (icons, colors) aren't accessible. Always use text to convey state.

---

## Testing Your Story

### Keyboard Testing

1. **Tab through your story**:
   - Press Tab repeatedly
   - Ensure you can reach every choice
   - Ensure Tab order is logical

2. **Select choices with keyboard**:
   - Press Enter or Space to select
   - Arrow keys to navigate choices (if list has multiple items)

3. **Test navigation**:
   - Ensure Restart, Save, Load work with keyboard
   - Ensure Settings dialog opens and closes with keyboard
   - Ensure Escape closes dialogs

**Checklist**:
- [ ] All choices reachable via Tab
- [ ] Choices activate with Enter/Space
- [ ] Can navigate entire story with keyboard only
- [ ] Tab order is logical (top to bottom, left to right)

### Screen Reader Testing

**NVDA (Windows, free)**:
1. Download from nvaccess.org
2. Press Ctrl+Alt+N to start
3. Load your story
4. Press NVDA+Down Arrow to read from top
5. Press H to navigate headings
6. Press B to navigate buttons (choices)

**VoiceOver (macOS, built-in)**:
1. Press Cmd+F5 to start
2. Load your story in Safari
3. Press VO+A to read from top (VO = Ctrl+Option)
4. Press VO+Cmd+H to navigate headings

**What to check**:
- [ ] Story title announced
- [ ] Passage titles announced
- [ ] Choice text clearly read
- [ ] Passage changes announced
- [ ] Image alt text read
- [ ] Lists announced as lists ("List with 5 items")

---

## Common Accessibility Issues

### Issue: "Click here" choices
**Problem**: Choice text is non-descriptive
**Fix**: Use descriptive action text

### Issue: Color-coded choices
**Problem**: Choices differentiated only by color
**Fix**: Add text descriptions or icons with alt text

### Issue: Unmarked spoilers
**Problem**: Hidden text revealed by CSS hover (inaccessible)
**Fix**: Use conditional choices

### Issue: Timed puzzles
**Problem**: Users with slow reading speed or motor impairments can't complete
**Fix**: Remove time limits or make them very generous (30+ seconds)

### Issue: Image-only puzzles
**Problem**: Puzzle requires seeing an image (can't be described in alt text)
**Fix**: Provide text alternative or skip option

### Issue: Unlabeled inventory icons
**Problem**: Icons without text labels
**Fix**: Always include text, use icon as supplement

---

## Accessibility Resources

### Guidelines
- WCAG 2.1 Quick Reference: https://www.w3.org/WAI/WCAG21/quickref/
- ARIA Authoring Practices: https://www.w3.org/WAI/ARIA/apg/

### Testing Tools
- NVDA Screen Reader (Windows): https://www.nvaccess.org/
- VoiceOver (macOS): Built-in (Cmd+F5)
- axe DevTools (browser): https://www.deque.com/axe/devtools/
- WAVE (browser): https://wave.webaim.org/

### Communities
- WebAIM Discussion List: https://webaim.org/discussion/
- A11y Project: https://www.a11yproject.com/

---

## Getting Help

- Check the FAQ in the documentation
- File an issue on GitHub
- Ask in community channels

Remember: Accessibility is not a checkbox, it's a practice. Test with real users, listen to feedback, and continuously improve!
