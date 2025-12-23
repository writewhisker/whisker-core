# Security Guide for whisker-core Users

This guide helps you understand and manage plugin permissions in whisker-core.

## Understanding Plugin Permissions

When you install a plugin, it may request permissions to access sensitive features. You control what each plugin can do.

## Permission Types

### Read Story State (Low Risk)

- **What it allows**: Plugin can see your game progress, variables, and history
- **Risks**: Plugin learns your choices and progress
- **Example uses**: Statistics tracking, achievement systems
- **Recommendation**: Safe to grant for trusted plugins

### Modify Story State (Medium Risk)

- **What it allows**: Plugin can change variables and game progress
- **Risks**: Could corrupt your save or alter story flow
- **Example uses**: Cheat codes, save/load systems
- **Recommendation**: Only grant to plugins you fully trust

### Network Access (High Risk)

- **What it allows**: Plugin can send data to internet servers
- **Risks**: Could upload your game progress, track your behavior
- **Example uses**: Cloud saves, analytics, online features
- **Recommendation**: Carefully review what plugin sends

### File System Access (High Risk)

- **What it allows**: Plugin can read/write files on your computer
- **Risks**: Could access sensitive files
- **Example uses**: Save games to file, import/export data
- **Recommendation**: Only grant to highly trusted plugins

## Permission Best Practices

### 1. Grant Minimal Permissions

Only approve the permissions a plugin actually needs.

**Example**: A "passage counter" plugin only needs READ_STATE, not NETWORK or FILESYSTEM. If it asks for more, be suspicious.

### 2. Read Permission Requests Carefully

Before clicking "Allow", ask yourself:
- Does this plugin really need this permission?
- Do I trust the plugin author?
- Is the plugin from a reputable source?

### 3. Revoke Unused Permissions

If you stop using a plugin, revoke its permissions:
1. Go to Settings → Plugins
2. Find the plugin
3. Click "Revoke Permissions"

### 4. Be Wary of High-Risk Permissions

Think twice before granting:
- **NETWORK**: Plugin can send your data anywhere
- **FILESYSTEM**: Plugin can access your files

## Recognizing Suspicious Plugins

### Red Flags

- Plugin requests more permissions than needed
  - Example: A simple timer wants NETWORK and FILESYSTEM
- Permission descriptions don't match plugin functionality
  - Example: "Weather widget" wants READ_STATE
- Plugin from unknown or untrusted source
- No documentation explaining why permissions needed
- Asks you to disable security features

### Safe Plugin Checklist

Before installing:
- [ ] Plugin from known, trusted source
- [ ] Permissions match described functionality
- [ ] Documentation explains permission usage
- [ ] Positive reviews from other users
- [ ] Active maintenance (recent updates)
- [ ] Source code available (for technical users)

## Protecting Your Data

### Backup Your Stories

Regularly backup your stories and saves:
1. Go to File → Export Story
2. Save to secure location
3. Consider cloud backup for important stories

### Use Trusted Plugins Only

- Install plugins from official whisker-core plugin repository
- Check plugin ratings and reviews
- Avoid plugins with no documentation
- Be cautious with new/unreviewed plugins

### Monitor Plugin Behavior

Watch for suspicious activity:
- Unexpected network requests
- Slow performance (possible cryptocurrency mining)
- New files created without your knowledge
- Story corruption or unexpected changes

## Managing Permissions

### Viewing Current Permissions

1. Go to Settings → Plugins
2. Click on a plugin name
3. View granted permissions

### Revoking Permissions

1. Go to Settings → Plugins
2. Click on a plugin name
3. Click "Revoke" next to the permission
4. Or click "Revoke All" to remove all permissions

### Resetting to Defaults

1. Go to Settings → Security
2. Click "Reset All Plugin Permissions"
3. All plugins will need to request permissions again

## Frequently Asked Questions

### Can plugins steal my personal information?

Plugins with NETWORK permission can send data to external servers. Only grant NETWORK to plugins you fully trust, and review what data they access.

### Are all plugins safe?

No. whisker-core provides security mechanisms, but malicious plugins can still harm your stories or privacy. Always review permissions and trust sources.

### Can I run whisker-core offline?

Yes. Deny NETWORK to all plugins to ensure no data leaves your computer. Some plugins may have reduced functionality.

### What if I accidentally granted dangerous permissions?

Revoke them immediately:
1. Go to Settings → Plugins → [Plugin Name]
2. Click "Revoke Permissions"

### Can plugins access my files?

Only if you grant FILESYSTEM permission. Without it, plugins cannot read or write files outside their sandbox.

### How do I report a malicious plugin?

1. Stop using the plugin immediately
2. Revoke all its permissions
3. Report to the whisker-core security team
4. Include plugin name and suspicious behavior

## Security Features

### Sandbox Protection

All plugins run in a sandboxed environment that:
- Prevents access to system commands
- Blocks dangerous Lua libraries
- Limits execution time to prevent freezing
- Isolates plugins from each other

### Content Sanitization

User-generated content is sanitized to prevent:
- Script injection (XSS attacks)
- Dangerous HTML tags
- Malicious links

### Permission System

The permission system:
- Requires user consent for sensitive operations
- Remembers your decisions
- Allows revoking permissions at any time
- Logs security-relevant events

## Getting Help

If you have security concerns:
- Check the documentation
- Ask in community forums
- Report issues to maintainers

If you discover a security vulnerability:
- Do not share exploit details publicly
- Report privately to maintainers
- Include steps to reproduce
