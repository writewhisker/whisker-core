# Privacy Compliance Guide

## GDPR Compliance

The whisker-core analytics system is designed to comply with the General Data Protection Regulation (GDPR).

### Consent Requirements

GDPR requires informed consent for non-essential data collection:

| Requirement | Status | Implementation |
|-------------|--------|----------------|
| Freely given | Implemented | Can choose "No Tracking" (NONE) |
| Specific | Implemented | Four granular consent levels |
| Informed | Implemented | Clear descriptions for each level |
| Unambiguous | Implemented | Active selection required |
| Withdrawable | Implemented | Can change consent at any time |

### Data Minimization

Collect only data necessary for stated purpose:

| Level | Data Collected | Purpose |
|-------|----------------|---------|
| ESSENTIAL | Error logs, save reliability | Technical operation |
| ANALYTICS | Session data, behavior | Story improvement |
| FULL | Cross-session, user ID | Personalization |

### Right to Access

Users can access all collected data:

```lua
local ConsentManager = require("whisker.analytics.consent_manager")

-- Export all user data
local userData = ConsentManager.exportUserData()
-- Returns: consent history, queued events, collection stats
```

### Right to Erasure

Users can request data deletion:

```lua
local ConsentManager = require("whisker.analytics.consent_manager")

-- Delete all user data
ConsentManager.deleteUserData()
-- Clears: queued events, consent state, user IDs
```

### Privacy by Design

Privacy is built-in from the start:

- Privacy filter enforces consent before storage
- Default consent is NONE (no tracking)
- PII detection and removal is automatic
- Session-scoped IDs prevent cross-session tracking at lower tiers

## CCPA Compliance

California Consumer Privacy Act requirements:

| Right | Status | Implementation |
|-------|--------|----------------|
| Right to Know | Implemented | `exportUserData()` |
| Right to Delete | Implemented | `deleteUserData()` |
| Right to Opt-Out | Implemented | Set consent to NONE |
| Notice at Collection | Implemented | Consent dialog |

## Consent Levels Explained

### NONE (0)
- No analytics tracking whatsoever
- No data collection
- No session IDs generated
- Use when: Story doesn't need analytics, privacy-sensitive audience

### ESSENTIAL (1)
- Error reporting only
- Save system reliability
- No behavioral tracking
- Session-scoped identifiers
- Use when: Need basic reliability tracking

### ANALYTICS (2)
- Session duration tracking
- Passage navigation
- Choice selections
- Engagement metrics
- No PII collected
- Session-scoped IDs only
- Use when: Want anonymous behavior insights

### FULL (3)
- All analytics features
- Cross-session tracking
- Persistent user IDs
- A/B test consistency
- Third-party integrations
- Use when: Need personalization, A/B testing

## PII Handling

The privacy filter automatically handles PII:

### Fields Always Removed (ANALYTICS and below)
- `userId` (replaced with session ID)
- `userName`
- `userEmail`
- `ipAddress`
- `deviceId`

### Fields Redacted
- `feedbackText` -> "[redacted]"
- `saveName` -> anonymized hash

### Safe Fields
These fields are considered safe at all consent levels:
- `passageId`
- `choiceId`
- `timestamp`
- `errorType`
- `wordCount`

## Implementation Checklist

For story creators ensuring compliance:

- [ ] Include privacy policy explaining data collection
- [ ] Show initial consent dialog on first launch
- [ ] Provide accessible privacy settings
- [ ] Document data retention period
- [ ] Describe security measures for data protection
- [ ] Provide contact information for privacy inquiries
- [ ] Test consent flow with real users
- [ ] Audit events for PII leaks

## Best Practices

### 1. Be Transparent
Clearly explain what data is collected and why. Use the consent dialog's description fields:

```lua
ConsentManager.initialize({
  descriptions = {
    [Privacy.CONSENT_LEVELS.ANALYTICS] =
      "Help us improve the story by sharing anonymous gameplay data"
  }
})
```

### 2. Minimize Collection
Only collect what you actually use:

```lua
-- Good: Collect only needed data
Analytics.trackEvent("puzzle", "solved", {
  puzzleId = "riddle_1",
  attempts = 3
})

-- Bad: Collecting unnecessary data
Analytics.trackEvent("puzzle", "solved", {
  puzzleId = "riddle_1",
  attempts = 3,
  userAgent = "...",  -- Unnecessary
  screenSize = "...", -- Unnecessary
  fullHistory = "..." -- Excessive
})
```

### 3. Honor Requests
Respond to access/deletion requests promptly:

```lua
-- Provide a menu option for privacy
menu.addItem("Privacy Settings", function()
  ConsentManager.showPrivacySettings()
end)

menu.addItem("Delete My Data", function()
  ConsentManager.deleteUserData()
  showMessage("Your data has been deleted")
end)
```

### 4. Secure Storage
Protect collected data in transit and at rest:

- Use HTTPS for all backend endpoints
- Encrypt local storage
- Implement proper access controls
- Set appropriate data retention periods

### 5. Document Everything
Maintain records of data processing activities:

```lua
-- Log consent changes
ConsentManager.onConsentChange(function(oldLevel, newLevel)
  log.info("Consent changed from %d to %d", oldLevel, newLevel)
end)
```

### 6. Review Regularly
Audit analytics for privacy compliance:

- Check that consent is obtained before tracking
- Verify PII is being removed correctly
- Test data export/deletion functionality
- Review third-party backend configurations

## Testing Privacy Features

### Test Consent Enforcement

```lua
-- Set consent to NONE
ConsentManager.setConsentLevel(Privacy.CONSENT_LEVELS.NONE)

-- Track event - should be blocked
local success = Analytics.trackEvent("test", "event", {})
assert(success == false, "Event should be blocked at NONE consent")
```

### Test PII Removal

```lua
-- Set consent to ANALYTICS
ConsentManager.setConsentLevel(Privacy.CONSENT_LEVELS.ANALYTICS)

-- Track event with PII
Analytics.trackEvent("user", "feedback", {
  rating = 5,
  feedbackText = "Great story!",
  userEmail = "test@example.com"
})

-- Verify PII is removed
local events = backend:getEvents()
assert(events[1].metadata.feedbackText == "[redacted]")
assert(events[1].metadata.userEmail == nil)
```

### Test Data Deletion

```lua
-- Generate some data
Analytics.trackEvent("test", "event", {})

-- Delete data
ConsentManager.deleteUserData()

-- Verify deletion
local events = backend:getEvents()
assert(#events == 0, "Events should be deleted")
```

## Resources

- [GDPR Official Text](https://gdpr-info.eu/)
- [CCPA Information](https://oag.ca.gov/privacy/ccpa)
- [Privacy by Design Framework](https://www.ipc.on.ca/wp-content/uploads/Resources/7foundationalprinciples.pdf)
- [ICO Guide to Consent](https://ico.org.uk/for-organisations/guide-to-data-protection/guide-to-the-general-data-protection-regulation-gdpr/consent/)
