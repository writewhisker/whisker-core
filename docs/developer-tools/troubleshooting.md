# Troubleshooting Whisker Developer Tools

This guide covers common issues and their solutions for all Whisker developer tools.

## LSP Server Issues

### "Language server failed to start"

**Symptoms**: No auto-completion, no diagnostics, no hover information.

**Solutions**:

1. Verify whisker-lsp is installed and in PATH:
   ```bash
   which whisker-lsp
   whisker-lsp --version
   ```

2. Check VSCode output panel:
   - View > Output
   - Select "Whisker Language Server"
   - Look for error messages

3. Set explicit path in settings:
   ```json
   {
     "whisker.lsp.serverPath": "/full/path/to/whisker-lsp"
   }
   ```

4. Check Lua is available:
   ```bash
   lua -v
   ```

### "Server crashed" or frequent restarts

**Solutions**:

1. Restart the server:
   - `Ctrl+Shift+P` > "Whisker: Restart Language Server"

2. Check log file for errors:
   - Location shown in Output panel
   - Look for Lua errors or stack traces

3. Enable verbose logging:
   ```json
   {
     "whisker.lsp.logLevel": "debug",
     "whisker.lsp.trace": "verbose"
   }
   ```

4. Report bug with:
   - Log file contents
   - Steps to reproduce
   - Lua and whisker-lsp versions

### No completions appearing

**Solutions**:

1. Trigger manually: `Ctrl+Space`

2. Check file type is recognized:
   - Bottom-right shows "Ink", "Twee", or "WScript"
   - If not, click to select correct language

3. Verify server is connected:
   - Check status bar for LSP indicator
   - Check Output panel

4. Check for syntax errors:
   - Broken syntax may prevent parsing
   - Fix obvious errors first

## Debugger Issues

### "Debugger not stopping at breakpoints"

**Solutions**:

1. Verify whisker-debug is installed:
   ```bash
   which whisker-debug
   whisker-debug --version
   ```

2. Check breakpoint is on valid line:
   - Passage headers (`=== Name ===`)
   - Choice lines (`* [text] -> target`)
   - Divert lines (`-> target`)
   - NOT comments or blank lines

3. Verify file path in launch.json:
   ```json
   {
     "program": "${file}"
   }
   ```
   Or use absolute path.

4. Check the passage is actually visited:
   - Use `:passages` in whisker-repl to verify

### "Variables not showing"

**Solutions**:

1. Ensure execution is paused (not running):
   - Look for "Paused" status
   - Yellow highlight on current line

2. Expand scopes in Variables pane:
   - Click arrow next to "Globals"
   - Click arrow next to "Locals"

3. Check Debug Console for errors:
   - Type variable name to test access

4. Verify variables are defined:
   - Must be assigned before current point

### "Debug session won't start"

**Solutions**:

1. Check launch.json is valid:
   ```json
   {
     "version": "0.2.0",
     "configurations": [{
       "type": "whisker",
       "request": "launch",
       "name": "Debug Story",
       "program": "${file}"
     }]
   }
   ```

2. Verify whisker-debug path:
   ```json
   {
     "whisker.debug.adapterPath": "/path/to/whisker-debug"
   }
   ```

3. Check Debug Console for startup errors

## Extension Issues

### "Extension not activating"

**Solutions**:

1. Check file extension:
   - Must be `.ink`, `.wscript`, `.twee`, or `.tw`
   - Rename if needed

2. Check Extension Host logs:
   - View > Output
   - Select "Log (Extension Host)"

3. Reload window:
   - `Ctrl+Shift+P` > "Developer: Reload Window"

4. Reinstall extension:
   - Uninstall and reinstall from Marketplace

### "Syntax highlighting not working"

**Solutions**:

1. Verify file association:
   - Check bottom-right language indicator
   - Should show "Ink", "Twee", or "WScript"

2. Click language selector:
   - Bottom-right corner
   - Choose correct language

3. Check for conflicting extensions:
   - Disable other syntax extensions temporarily

4. Reload window:
   - `Ctrl+Shift+P` > "Developer: Reload Window"

### "Preview not updating"

**Solutions**:

1. Save the file:
   - Preview updates on save by default

2. Enable live preview:
   ```json
   {
     "whisker.preview.liveUpdate": true
   }
   ```

3. Reopen preview:
   - Close and reopen preview panel

4. Check for syntax errors:
   - Broken syntax prevents parsing

## CLI Tool Issues

### "Command not found"

**Solutions**:

1. Check LuaRocks bin is in PATH:
   ```bash
   echo $PATH
   # Should include ~/.luarocks/bin or similar
   ```

2. Add to PATH:
   ```bash
   # Add to ~/.bashrc or ~/.zshrc
   export PATH="$HOME/.luarocks/bin:$PATH"
   ```

3. Use full path:
   ```bash
   ~/.luarocks/bin/whisker-lint story.ink
   ```

4. Reinstall:
   ```bash
   luarocks install --force whisker-lint
   ```

### "Cannot open file"

**Solutions**:

1. Check file exists:
   ```bash
   ls -la story.ink
   ```

2. Check permissions:
   ```bash
   chmod +r story.ink
   ```

3. Use absolute path:
   ```bash
   whisker-lint /full/path/to/story.ink
   ```

### "Unknown file format"

**Solutions**:

1. Check file extension:
   - Must be `.ink`, `.twee`, `.tw`, or `.wscript`

2. Rename file:
   ```bash
   mv story.txt story.ink
   ```

3. Specify format (where supported):
   ```bash
   whisker-fmt --stdin --stdin-format ink < story.txt
   ```

### Config file errors

**Solutions**:

1. Validate JSON syntax:
   ```bash
   cat .whisker-lint.json | python -m json.tool
   ```

2. Use online validator:
   - https://jsonlint.com/

3. Check for trailing commas:
   ```json
   {
     "rules": {
       "rule1": "warn",
       "rule2": "error"  <- No comma after last item
     }
   }
   ```

## Performance Issues

### "Editor slow with large files"

**Solutions**:

1. Increase diagnostic delay:
   ```json
   {
     "whisker.lsp.diagnosticsDelay": 2000
   }
   ```

2. Split large stories:
   - Use `INCLUDE` in Ink
   - Use separate files for chapters

3. Disable live preview:
   ```json
   {
     "whisker.preview.liveUpdate": false
   }
   ```

4. Reduce file watchers:
   - Close unused files

### "High CPU usage"

**Solutions**:

1. Check for infinite loops in story:
   - Look for circular navigation without exit

2. Restart language server:
   - `Ctrl+Shift+P` > "Whisker: Restart Language Server"

3. Check for file system issues:
   - Too many files in workspace

4. Limit workspace scope:
   - Open specific folder, not entire drive

## Getting More Help

### Collecting Debug Information

When reporting issues, include:

1. **Versions**:
   ```bash
   whisker-lsp --version
   whisker-debug --version
   lua -v
   ```

2. **Editor info**:
   - VSCode version
   - Extension version

3. **Logs**:
   - VSCode Output > "Whisker Language Server"
   - Debug Console output

4. **Minimal reproduction**:
   - Smallest story file that shows the issue

### Where to Get Help

- **GitHub Issues**: https://github.com/writewhisker/whisker-core/issues
- **Discussions**: https://github.com/writewhisker/whisker-core/discussions

### Reporting Bugs

Create an issue with:

1. Clear title describing the problem
2. Steps to reproduce
3. Expected vs actual behavior
4. Version information
5. Relevant logs or screenshots
6. Minimal example file if applicable
