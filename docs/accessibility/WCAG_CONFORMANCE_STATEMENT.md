# WCAG 2.1 Conformance Statement

## Product Information

**Product**: whisker-core Interactive Fiction Framework
**Version**: 0.1.0
**Date**: December 2024
**Conformance Target**: WCAG 2.1 Level AA

## Conformance Claim

whisker-core conforms to WCAG 2.1 Level AA. The conformance claim covers:

- Web player interface
- Exported HTML stories
- Documentation website

## Scope

This conformance claim covers:
- All user-facing web player functionality
- HTML export output
- Author documentation

This claim does NOT cover:
- Third-party story files (author responsibility)
- Custom extensions or plugins
- Development tools

## Testing

Conformance was validated through:
- Automated testing (vitest with jsdom)
- Manual keyboard navigation testing
- Screen reader testing protocols (NVDA, JAWS, VoiceOver)
- Color contrast validation
- Code review against WCAG criteria

## Conformance by Principle

### Perceivable

**1.1 Text Alternatives**
- Alt text required for all images
- Decorative images use empty alt text
- Complex images have extended descriptions

**1.2 Time-based Media**
- Not applicable (no video/audio in core framework)

**1.3 Adaptable**
- Semantic HTML structure
- Proper heading hierarchy (h1 → h2 → h3)
- Logical reading order
- Content adapts to different presentations

**1.4 Distinguishable**
- Contrast ratios ≥ 4.5:1 for normal text
- Contrast ratios ≥ 3:1 for large text
- No color-only information
- High contrast mode support
- Text can be resized up to 200%

### Operable

**2.1 Keyboard Accessible**
- Full keyboard navigation
- Tab/Shift+Tab for focus navigation
- Enter/Space for activation
- Arrow keys for choice navigation
- No keyboard traps

**2.2 Enough Time**
- No time limits in core framework
- Authors warned about timed content

**2.3 Seizures and Physical Reactions**
- No flashing content
- Reduced motion support via prefers-reduced-motion

**2.4 Navigable**
- Skip links provided
- Page titles descriptive
- Focus visible at all times
- Focus order logical and meaningful
- Link purpose clear from context
- Multiple ways to find content

**2.5 Input Modalities**
- Touch targets at least 44x44 CSS pixels
- Motion actuation not required
- Pointer gestures not required

### Understandable

**3.1 Readable**
- Language of page identified (lang attribute)
- Consistent terminology throughout

**3.2 Predictable**
- Consistent navigation
- Consistent identification
- No surprise context changes
- Focus changes predictable

**3.3 Input Assistance**
- Error messages clear and actionable
- Labels provided for all inputs
- Help text available where needed

### Robust

**4.1 Compatible**
- Valid HTML5
- ARIA used correctly and sparingly
- Name, role, value exposed for all components
- Compatible with current and future assistive technologies

## Known Limitations

1. **Author-Created Content**: Authors must provide alt text and follow accessibility guidelines for their own content
2. **Custom Extensions**: Third-party extensions may not be accessible
3. **Complex Visual Puzzles**: Visual puzzles require author-provided text alternatives
4. **Very Long Stories**: Stories with hundreds of passages may benefit from additional navigation aids

## Accessibility Features

### Keyboard Navigation
- Tab through all interactive elements
- Arrow keys for choice list navigation
- Enter/Space to activate choices
- Escape to close dialogs
- Home/End to jump to first/last choice

### Screen Reader Support
- Tested with NVDA on Windows
- Tested with JAWS on Windows
- Tested with VoiceOver on macOS
- Tested with VoiceOver on iOS
- Live region announcements for dynamic content

### Visual Accommodations
- High contrast mode (forced-colors)
- User preference for increased contrast (prefers-contrast)
- Reduced motion support (prefers-reduced-motion)
- Text resizable to 200% without loss of functionality

### Semantic Structure
- Landmark regions (header, nav, main, footer)
- Heading hierarchy for navigation
- Lists for grouped content
- Articles for passages

## Support

For accessibility questions or to report issues:
- GitHub Issues: [repository URL]
- Email: [contact email]
- Documentation: See docs/accessibility/

## Feedback

We welcome feedback on accessibility. If you encounter barriers:
1. File an issue on GitHub with the "accessibility" label
2. Include steps to reproduce the issue
3. Specify which assistive technology you're using
4. We aim to respond within 5 business days

## Continuous Improvement

Accessibility is an ongoing commitment. We:
- Test with each release
- Monitor screen reader compatibility
- Gather user feedback
- Update documentation
- Train contributors

## Standards Referenced

- WCAG 2.1: https://www.w3.org/TR/WCAG21/
- ARIA 1.2: https://www.w3.org/TR/wai-aria-1.2/
- ARIA Authoring Practices: https://www.w3.org/WAI/ARIA/apg/
- HTML Living Standard: https://html.spec.whatwg.org/

---

Last updated: December 2024
