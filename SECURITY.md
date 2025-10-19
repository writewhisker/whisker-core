# Security Policy

## Supported Versions

We actively support the following versions of whisker-core with security updates:

| Version | Supported          |
| ------- | ------------------ |
| 1.x     | :white_check_mark: |
| < 1.0   | :x:                |

**Note:** Once we release version 1.0, we will maintain security support for the latest major version and the previous major version for 12 months.

## Reporting a Vulnerability

We take the security of whisker-core seriously. If you discover a security vulnerability, please follow these guidelines:

### How to Report

**DO NOT** create a public GitHub issue for security vulnerabilities.

Instead, please report security vulnerabilities through one of these methods:

#### Option 1: GitHub Security Advisories (Preferred)

1. Go to https://github.com/writewhisker/whisker-core/security/advisories
2. Click "Report a vulnerability"
3. Fill out the form with details about the vulnerability

#### Option 2: Email

Send an email to: **security@writewhisker.org** (when available)

Until the dedicated security email is set up, please use GitHub Security Advisories.

### What to Include

Please provide the following information in your report:

1. **Description**: A clear description of the vulnerability
2. **Impact**: What kind of security issue is this? (RCE, XSS, injection, etc.)
3. **Affected Versions**: Which versions are affected?
4. **Reproduction Steps**: Detailed steps to reproduce the vulnerability
5. **Proof of Concept**: Example story file or code that demonstrates the issue
6. **Suggested Fix**: If you have ideas on how to fix it (optional)

### Example Report

```
Title: Lua Code Injection via Malformed Passage Names

Description:
Passage names with certain special characters can lead to arbitrary Lua code
execution when the story is parsed.

Impact:
Remote Code Execution (RCE) - High Severity

Affected Versions:
All versions prior to 1.0.0

Reproduction Steps:
1. Create a passage with name: `Start"]]; os.execute("whoami") --`
2. Parse the story using whisker.parse()
3. Observe that the system command executes

Proof of Concept:
[Attach minimal story file]

Suggested Fix:
Properly escape passage names before using them in Lua string literals.
Use pattern matching to validate passage names.
```

## Security Vulnerability Categories

### Critical (Immediate attention required)

- **Remote Code Execution (RCE)**: Arbitrary code execution via story files
- **Arbitrary File Access**: Reading or writing files outside intended scope
- **Privilege Escalation**: Gaining unauthorized access or permissions

### High

- **Lua Sandbox Escape**: Breaking out of Lua environment restrictions
- **DoS (Denial of Service)**: Crashes or resource exhaustion via malicious stories
- **Path Traversal**: Accessing files outside intended directories

### Medium

- **Information Disclosure**: Leaking sensitive information
- **Regular Expression DoS**: ReDoS attacks via crafted input
- **Unsafe Deserialization**: Security issues in story file parsing

### Low

- **Minor Information Leaks**: Limited information exposure
- **Best Practice Violations**: Security concerns that don't directly lead to exploits

## Response Timeline

We aim to respond to security reports according to the following timeline:

- **Initial Response**: Within 48 hours of receiving the report
- **Severity Assessment**: Within 1 week
- **Fix Development**: Depends on severity
  - Critical: Within 1 week
  - High: Within 2 weeks
  - Medium: Within 4 weeks
  - Low: Next regular release
- **Public Disclosure**: After fix is released and users have time to update

## Security Best Practices for Users

### When Using whisker-core

1. **Validate Story Files**: Don't parse untrusted story files without review
2. **Sandbox Execution**: Run stories in isolated environments when possible
3. **Keep Updated**: Use the latest version with security patches
4. **Limit File Access**: Restrict file system access for story runtimes
5. **Review User Input**: Sanitize any user-generated story content

### For Story Authors

1. **Test Your Stories**: Test your stories before distributing them
2. **Avoid Sensitive Data**: Don't include API keys or credentials in story files
3. **Validate User Input**: If your story accepts user input, validate it
4. **Be Careful with Templates**: Review template code for security issues

### For Integrators

1. **Isolate Story Execution**: Run stories in sandboxed environments
2. **Implement Resource Limits**: Prevent DoS via infinite loops or memory consumption
3. **Validate Before Parse**: Check story files before parsing
4. **Use Secure Defaults**: Enable security features by default
5. **Monitor for Abuse**: Log and monitor story execution for suspicious activity

## Known Security Considerations

### Lua Code Execution

whisker-core executes Lua code from story files. This is **by design**, but has security implications:

- **Trust Story Files**: Only parse story files from trusted sources
- **Sandbox When Possible**: Consider running stories in sandboxed Lua environments
- **Limit System Access**: Restrict access to system libraries (os, io, etc.)

### Template System

The template system allows arbitrary Lua code:

```whisker
:: Start
<<lua print("This executes Lua code") >>
```

**Mitigation**: Review templates before use, especially from untrusted sources.

### File System Access

Some runtimes may allow file system access:

- **Restrict Paths**: Limit file access to designated directories
- **Validate Paths**: Check for path traversal attempts (../, etc.)
- **Use Read-Only**: When possible, mount story directories as read-only

## Security Updates

Security updates will be released as:

1. **Patch Releases**: For critical and high severity issues (e.g., 1.0.1)
2. **GitHub Security Advisories**: Public disclosure after fix is available
3. **CHANGELOG.md**: Documented with `[SECURITY]` prefix
4. **Release Notes**: Highlighted in GitHub releases

## Security Hall of Fame

We recognize security researchers who responsibly disclose vulnerabilities:

| Reporter | Vulnerability | Version Fixed |
|----------|---------------|---------------|
| _None yet_ | - | - |

## Questions?

If you have questions about:
- **This security policy**: Open a GitHub Discussion
- **Security best practices**: See documentation or ask in Discussions
- **A potential vulnerability**: Follow the reporting process above

## License

This security policy is licensed under [CC BY 4.0](https://creativecommons.org/licenses/by/4.0/).
