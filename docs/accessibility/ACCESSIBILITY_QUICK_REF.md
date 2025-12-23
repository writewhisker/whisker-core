# Accessibility Quick Reference

## Author Checklist

Before publishing your story, check:

- [ ] Every choice has descriptive text (not "Yes/No" or "Click here")
- [ ] Every image has alt text
- [ ] Color is not the only way info is shown
- [ ] Headings structure your content
- [ ] Lists used for multiple items
- [ ] Tested with Tab key (keyboard navigation)
- [ ] Tested with screen reader (NVDA or VoiceOver)

---

## Common Patterns

### Good Choice Text
```
* [Search the desk for clues]
* [Ask the innkeeper about rumors]
* [Leave town and head north]
```

### Image Alt Text
```
~ image("map.png", "Treasure map showing X north of village")
```

### Headings
```
# Main Heading
## Sub Heading
### Section
```

### Lists
```
Your inventory:
- Sword
- Shield
- Potion
```

---

## Testing Shortcuts

### Keyboard Testing
| Key | Action |
|-----|--------|
| Tab | Next element |
| Shift+Tab | Previous element |
| Enter/Space | Activate choice |
| Arrow keys | Navigate choice list |
| Escape | Close dialog |
| Home | First choice |
| End | Last choice |

### NVDA (Windows)
| Key | Action |
|-----|--------|
| Ctrl+Alt+N | Start NVDA |
| NVDA+Q | Quit NVDA |
| NVDA+Down Arrow | Read all |
| H | Next heading |
| Shift+H | Previous heading |
| B | Next button |
| NVDA+F7 | Elements list |

### VoiceOver (Mac)
| Key | Action |
|-----|--------|
| Cmd+F5 | Start/stop VoiceOver |
| VO+A | Read all (VO = Ctrl+Option) |
| VO+Right | Next item |
| VO+Left | Previous item |
| VO+Cmd+H | Next heading |
| VO+U | Open rotor |

### VoiceOver (iOS)
| Gesture | Action |
|---------|--------|
| Swipe right | Next item |
| Swipe left | Previous item |
| Double tap | Activate |
| Two-finger swipe down | Read all |
| Rotor | Rotate two fingers |

---

## Common Fixes

| Problem | Fix |
|---------|-----|
| "Click here" choice | Use descriptive text: "Enter the cave" |
| "Yes/No" choices | Add context: "Accept the quest" / "Decline the quest" |
| No alt text | Add: `image("pic.png", "Description of image")` |
| Color-only info | Add text: "red (dangerous)" not just "red" |
| No structure | Add headings with # ## ### |
| Items in paragraph | Use list with - or * |
| Timed puzzle | Remove timer or add 30+ seconds |
| Hidden content | Use expandable choices instead |

---

## Do's and Don'ts

### Do

- Write clear, action-oriented choice text
- Describe images for screen readers
- Use headings to structure content
- Test with keyboard only
- Provide text for all information

### Don't

- Use "click here" or "here" as link text
- Rely on color alone to convey meaning
- Use ASCII art without text alternative
- Create time-limited puzzles
- Assume users can see visual formatting

---

## Resources

| Resource | URL |
|----------|-----|
| Full Guide | docs/accessibility/ACCESSIBILITY_GUIDE.md |
| Screen Reader Testing | docs/accessibility/SCREEN_READER_TESTING.md |
| WCAG Quick Reference | w3.org/WAI/WCAG21/quickref |
| NVDA Download | nvaccess.org |
| axe DevTools | deque.com/axe/devtools |

---

## Getting Help

1. Read the full accessibility guide
2. Check the FAQ
3. File a GitHub issue with "accessibility" label
4. Include: what you tried, what happened, assistive technology used
