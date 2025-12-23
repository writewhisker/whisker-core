# whisker-core Security Architecture

## Overview

whisker-core implements defense-in-depth security through three primary layers:

1. **Capability System**: Permission-based access control for plugins
2. **Lua Sandbox**: Isolated execution environment for untrusted code
3. **Content Sanitization**: XSS prevention for user-generated content

These layers work together to create a secure environment for executing third-party plugins and rendering user-created stories.

## Security Boundaries

### Core Framework (Trusted)

The core framework operates with full system privileges:
- Direct access to all Lua libraries
- Unrestricted file system access
- Network operations without limitations
- Full control over story state

**Trust Assumption**: Core framework code is reviewed and trusted.

### Plugin Execution (Untrusted)

Plugins execute in a restricted environment:
- **Sandboxed Lua Environment**: No access to `os`, `io`, `debug`, `loadfile`
- **Capability-Gated API**: All sensitive operations require declared capabilities
- **Resource Limits**: Execution timeouts, memory limits
- **Permission System**: User must grant capabilities before use

**Trust Assumption**: Plugins are potentially malicious and must be isolated.

### User Content (Untrusted)

Story content is treated as untrusted data:
- **HTML Sanitization**: Remove dangerous tags and attributes
- **CSP Protection**: Browser-level script execution restrictions
- **Template Escaping**: Prevent injection in template variables

**Trust Assumption**: Story authors may intentionally or accidentally include malicious content.

## Capability System

### Capability Definitions

| Capability | Risk | Description |
|-----------|------|-------------|
| `READ_STATE` | Low | Read story variables and history |
| `WRITE_STATE` | Medium | Modify story variables and navigation |
| `NETWORK` | High | Make HTTP requests to external servers |
| `FILESYSTEM` | High | Read/write local files |
| `MODIFY_UI` | Low | Add/modify UI elements |
| `AUDIO` | Low | Play sounds and music |
| `SYSTEM_INFO` | Low | Access platform information |
| `PLUGIN_COMM` | Medium | Communicate with other plugins |

### Capability Flow

```
Plugin Manifest
  ├─> Declares capabilities: ["READ_STATE", "NETWORK"]
  │
  ↓
Plugin Loader
  ├─> Validates capability declarations
  ├─> Creates security context
  │
  ↓
Runtime Execution
  ├─> Plugin calls whisker.get_variable()
  ├─> CapabilityChecker.require_capability("READ_STATE")
  ├─> Check: Plugin declared READ_STATE? ✓
  ├─> Check: User granted READ_STATE? ✓
  ├─> Allow operation
```

### Implementation Modules

- `security/capabilities.lua` - Capability registry and metadata
- `security/capability_checker.lua` - Runtime capability validation
- `security/security_context.lua` - Thread-local storage for plugin context
- `security/permission_manager.lua` - User permission handling
- `security/permission_storage.lua` - Permission persistence

## Lua Sandbox

### Sandbox Construction

1. **Create Clean Environment**: New table with only safe globals
2. **Remove Dangerous Globals**: No `os`, `io`, `debug`, `loadfile`, `dofile`, `package`
3. **Add Safe Libraries**: `string`, `table`, `math` (full)
4. **Protect Metatables**: String metatable made read-only
5. **Provide whisker API**: Capability-gated functions only

### Safe Globals

```lua
-- Always available
"type", "tonumber", "tostring", "assert", "error",
"pcall", "xpcall", "pairs", "ipairs", "next", "select",
"rawequal", "rawget", "rawset", "rawlen", "unpack"

-- Safe libraries (full)
"math", "string"

-- Partial libraries
table = {"concat", "insert", "move", "pack", "remove", "sort", "unpack"}
os = {"clock", "date", "difftime", "time"}  -- No execute, getenv, etc.
```

### Blocked Globals

```lua
"dofile", "loadfile", "load", "loadstring", "require",
"io", "os", "debug", "package", "coroutine",
"collectgarbage", "setfenv", "getfenv"
```

### Execution Timeouts

Plugins are executed with instruction-counting timeouts to prevent:
- Infinite loops
- Long-running operations
- Denial of service attacks

Default timeout: 100ms per operation

## Content Sanitization

### Sanitization Pipeline

```
User HTML Content
  ↓
HTML Parser
  ├─> Parse into DOM tree
  ↓
Tag Filter
  ├─> Remove: script, iframe, object, embed, style
  ↓
Attribute Filter
  ├─> Remove: onclick, onerror, on* event handlers
  ├─> Remove: javascript: URLs, data: URLs
  ├─> Keep: safe attributes (class, id, ARIA)
  ↓
Allowlist Validation
  ├─> Only allowed tags and attributes pass through
  ↓
Safe HTML Output
```

### Allowed Tags

Formatting: `p`, `br`, `strong`, `em`, `u`, `s`, `code`, `pre`

Structure: `div`, `span`, `article`, `section`, `header`, `footer`

Lists: `ul`, `ol`, `li`, `dl`, `dt`, `dd`

Tables: `table`, `thead`, `tbody`, `tr`, `th`, `td`

Media: `img`, `audio`, `video`, `figure`, `figcaption`

Links: `a` (with URL validation)

### Dangerous Content Removed

- `<script>` tags
- Event handlers (`onclick`, `onerror`, etc.)
- `javascript:` URLs
- `data:text/html` URLs
- `<iframe>`, `<object>`, `<embed>` tags
- `<style>` tags
- `<svg>` with script content

## Content Security Policy

### Default CSP Policy

```
default-src 'self';
script-src 'self' 'nonce-RANDOM';
style-src 'self' 'unsafe-inline';
img-src 'self' data: https:;
font-src 'self' data:;
connect-src 'self';
media-src 'self';
object-src 'none';
frame-src 'none';
frame-ancestors 'none';
base-uri 'self';
form-action 'self';
```

This policy:
- ✓ Allows scripts from same origin with nonce
- ✓ Allows images from same origin, data URIs, and HTTPS
- ✗ Blocks inline scripts without nonce
- ✗ Blocks external scripts from CDNs
- ✗ Blocks plugins (Flash, Java, etc.)
- ✗ Blocks embedding in iframes

### Nonce-Based Security

Each HTML export generates a unique cryptographic nonce:

```html
<script nonce="abc123xyz...">
  // Runtime code here
</script>
```

Only scripts with the correct nonce are allowed to execute.

## Security Testing

### Test Categories

1. **Sandbox Escape Tests** - Attempt to access blocked globals
2. **Capability Bypass Tests** - Try to use capabilities without permission
3. **XSS Prevention Tests** - Inject malicious HTML/JavaScript
4. **Path Traversal Tests** - Access files outside allowed directories

### Running Security Tests

```bash
cd whisker-core
busted tests/unit/security/
```

## Security Checklist

### For Code Review

- [ ] All sensitive operations have capability checks
- [ ] Capability checks use `CapabilityChecker.require_capability()`
- [ ] No direct access to StateManager without capability
- [ ] Plugin code executed in sandboxed environment
- [ ] User-generated content sanitized before export
- [ ] CSP meta tag included in HTML exports

### For Plugin Development

- [ ] Only request necessary capabilities
- [ ] Handle permission denial gracefully
- [ ] Validate all external input
- [ ] Use HTTPS for network requests
- [ ] Don't log sensitive data

## Reporting Security Issues

If you discover a security vulnerability:

1. **Do not** share exploit details publicly
2. Email security concerns to the maintainers
3. Include:
   - Description of vulnerability
   - Steps to reproduce
   - Impact assessment
   - Proof of concept (if safe)
4. Wait for response before public disclosure

## Module Reference

| Module | Purpose |
|--------|---------|
| `security/init.lua` | Main entry point |
| `security/capabilities.lua` | Capability registry |
| `security/capability_checker.lua` | Runtime capability validation |
| `security/security_context.lua` | Plugin execution context |
| `security/permission_manager.lua` | User permission handling |
| `security/permission_storage.lua` | Permission persistence |
| `security/sandbox.lua` | Lua sandbox environment |
| `security/content_sanitizer.lua` | HTML sanitization |
| `security/html_parser.lua` | HTML parsing/serialization |
| `security/csp_generator.lua` | CSP policy generation |
| `security/security_logger.lua` | Security audit logging |
