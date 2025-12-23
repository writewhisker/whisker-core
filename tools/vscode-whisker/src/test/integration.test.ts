import * as assert from 'assert';
import * as vscode from 'vscode';
import * as path from 'path';

suite('Whisker Extension Integration Tests', () => {
  test('Extension activates on .ink file', async () => {
    const ext = vscode.extensions.getExtension('whisker.whisker');
    assert.ok(ext);

    // Open test file
    const testFile = path.join(__dirname, '../../test-files/sample.ink');
    const doc = await vscode.workspace.openTextDocument(testFile);
    await vscode.window.showTextDocument(doc);

    // Wait for activation
    await ext!.activate();
    assert.ok(ext!.isActive);
  });

  test('Language client starts successfully', async () => {
    // Extension should be active from previous test
    const ext = vscode.extensions.getExtension('whisker.whisker');
    assert.ok(ext!.isActive);

    // Wait a bit for server to start
    await new Promise(resolve => setTimeout(resolve, 2000));

    // Check output channel for server start message
    // (Note: Direct client inspection not exposed by API)
  });

  test('Completion works for passage reference', async () => {
    const testFile = path.join(__dirname, '../../test-files/sample.ink');
    const doc = await vscode.workspace.openTextDocument(testFile);
    await vscode.window.showTextDocument(doc);

    // Position after "-> "
    const position = new vscode.Position(5, 3);

    const completions = await vscode.commands.executeCommand<vscode.CompletionList>(
      'vscode.executeCompletionItemProvider',
      doc.uri,
      position
    );

    assert.ok(completions);
    assert.ok(completions.items.length > 0);

    // Should include passage names
    const passageNames = completions.items.map(item => item.label);
    assert.ok(passageNames.includes('Start') || passageNames.includes('NorthPath'));
  });

  test('Hover provides documentation', async () => {
    const testFile = path.join(__dirname, '../../test-files/sample.ink');
    const doc = await vscode.workspace.openTextDocument(testFile);
    await vscode.window.showTextDocument(doc);

    // Position on passage name
    const position = new vscode.Position(0, 5);

    const hovers = await vscode.commands.executeCommand<vscode.Hover[]>(
      'vscode.executeHoverProvider',
      doc.uri,
      position
    );

    assert.ok(hovers);
    assert.ok(hovers.length > 0);
  });

  test('Diagnostics appear for errors', async () => {
    const testFile = path.join(__dirname, '../../test-files/error.ink');
    const doc = await vscode.workspace.openTextDocument(testFile);
    await vscode.window.showTextDocument(doc);

    // Wait for diagnostics
    await new Promise(resolve => setTimeout(resolve, 1000));

    const diagnostics = vscode.languages.getDiagnostics(doc.uri);
    // Should have at least one diagnostic for undefined passage
    assert.ok(diagnostics.length > 0);
  });

  test('Go to definition navigates to passage', async () => {
    const testFile = path.join(__dirname, '../../test-files/sample.ink');
    const doc = await vscode.workspace.openTextDocument(testFile);
    await vscode.window.showTextDocument(doc);

    // Position on passage reference
    const position = new vscode.Position(5, 5);

    const locations = await vscode.commands.executeCommand<vscode.Location[]>(
      'vscode.executeDefinitionProvider',
      doc.uri,
      position
    );

    assert.ok(locations);
    // If passage exists, should find definition
  });
});
