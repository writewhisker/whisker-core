import * as vscode from 'vscode';
import * as fs from 'fs';
import * as path from 'path';
import { exec } from 'child_process';
import { promisify } from 'util';
import { StoryPreviewProvider } from './preview-provider';
import { GraphProvider } from './graph-provider';

const execAsync = promisify(exec);

export function registerCommands(
  context: vscode.ExtensionContext,
  previewProvider: StoryPreviewProvider,
  graphProvider: GraphProvider
): void {
  // New Story command
  const newStory = vscode.commands.registerCommand('whisker.newStory', async () => {
    // Ask for story format
    const format = await vscode.window.showQuickPick(
      [
        { label: 'Ink', description: 'Traditional Ink format (.ink)', value: 'ink' },
        { label: 'WhiskerScript', description: 'WhiskerScript format (.wscript)', value: 'wscript' },
        { label: 'Twee', description: 'Twine/Twee format (.twee)', value: 'twee' }
      ],
      { placeHolder: 'Select story format' }
    );

    if (!format) return;

    // Ask for story name
    const name = await vscode.window.showInputBox({
      prompt: 'Enter story name',
      placeHolder: 'MyStory',
      validateInput: (value) => {
        if (!value) return 'Name is required';
        if (!/^[\w-]+$/.test(value)) return 'Name can only contain letters, numbers, underscores, and hyphens';
        return null;
      }
    });

    if (!name) return;

    // Get workspace folder
    const workspaceFolder = vscode.workspace.workspaceFolders?.[0];
    if (!workspaceFolder) {
      vscode.window.showErrorMessage('No workspace folder open. Please open a folder first.');
      return;
    }

    // Generate template based on format
    const template = generateTemplate(format.value, name);
    const extension = format.value === 'ink' ? '.ink' : format.value === 'wscript' ? '.wscript' : '.twee';
    const storyPath = path.join(workspaceFolder.uri.fsPath, `${name}${extension}`);

    // Check if file exists
    if (fs.existsSync(storyPath)) {
      const overwrite = await vscode.window.showWarningMessage(
        `File "${name}${extension}" already exists. Overwrite?`,
        'Yes', 'No'
      );
      if (overwrite !== 'Yes') return;
    }

    // Write file and open
    fs.writeFileSync(storyPath, template);
    const doc = await vscode.workspace.openTextDocument(storyPath);
    await vscode.window.showTextDocument(doc);

    vscode.window.showInformationMessage(`Story "${name}" created!`);
  });

  // Preview Story command
  const previewStory = vscode.commands.registerCommand('whisker.previewStory', async () => {
    const editor = vscode.window.activeTextEditor;
    if (!editor) {
      vscode.window.showWarningMessage('No active editor. Open a story file first.');
      return;
    }

    const languageId = editor.document.languageId;
    if (!['ink', 'wscript', 'twee'].includes(languageId)) {
      vscode.window.showWarningMessage('Preview is only available for .ink, .wscript, and .twee files.');
      return;
    }

    await previewProvider.show(editor.document);
  });

  // View Graph command
  const viewGraph = vscode.commands.registerCommand('whisker.viewGraph', async () => {
    const editor = vscode.window.activeTextEditor;
    if (!editor) {
      vscode.window.showWarningMessage('No active editor. Open a story file first.');
      return;
    }

    const languageId = editor.document.languageId;
    if (!['ink', 'wscript', 'twee'].includes(languageId)) {
      vscode.window.showWarningMessage('Graph view is only available for .ink, .wscript, and .twee files.');
      return;
    }

    await graphProvider.show(editor.document);
  });

  // Format Document command
  const formatDocument = vscode.commands.registerCommand('whisker.formatDocument', async () => {
    const editor = vscode.window.activeTextEditor;
    if (!editor) {
      vscode.window.showWarningMessage('No active editor.');
      return;
    }

    const document = editor.document;
    const languageId = document.languageId;

    if (!['ink', 'wscript', 'twee'].includes(languageId)) {
      vscode.window.showWarningMessage('Format is only available for .ink, .wscript, and .twee files.');
      return;
    }

    try {
      const filePath = document.uri.fsPath;

      // Try using whisker-fmt
      try {
        await execAsync(`whisker-fmt "${filePath}"`);
        // Reload document from disk
        await vscode.commands.executeCommand('workbench.action.files.revert');
        vscode.window.showInformationMessage('Document formatted');
      } catch (fmtError) {
        // whisker-fmt not available, use basic formatting
        const formatted = basicFormat(document.getText(), languageId);
        const edit = new vscode.WorkspaceEdit();
        const fullRange = new vscode.Range(
          document.positionAt(0),
          document.positionAt(document.getText().length)
        );
        edit.replace(document.uri, fullRange, formatted);
        await vscode.workspace.applyEdit(edit);
        vscode.window.showInformationMessage('Document formatted (basic)');
      }
    } catch (error) {
      vscode.window.showErrorMessage(`Format failed: ${error}`);
    }
  });

  // Debug Story command
  const debugStory = vscode.commands.registerCommand('whisker.debugStory', async () => {
    const editor = vscode.window.activeTextEditor;
    if (!editor) {
      vscode.window.showWarningMessage('No active editor. Open a story file first.');
      return;
    }

    // Start debugging with default configuration
    const config: vscode.DebugConfiguration = {
      type: 'whisker',
      request: 'launch',
      name: 'Debug Story',
      program: editor.document.uri.fsPath
    };

    try {
      await vscode.debug.startDebugging(undefined, config);
    } catch (error) {
      vscode.window.showErrorMessage(`Failed to start debugger: ${error}`);
    }
  });

  context.subscriptions.push(
    newStory,
    previewStory,
    viewGraph,
    formatDocument,
    debugStory
  );
}

function generateTemplate(format: string, name: string): string {
  switch (format) {
    case 'ink':
      return `// ${name}
// A Whisker Interactive Fiction Story

=== Start ===
Welcome to ${name}!

This is where your story begins. Write your narrative here,
and use choices to guide the reader through your tale.

* [Begin the adventure] -> Chapter1
* [Learn the controls] -> Tutorial

=== Tutorial ===
Here's how to play:

- Read the text carefully
- Choose your actions wisely
- Explore different paths

* [I'm ready to start!] -> Chapter1
+ [Tell me more] -> Tutorial

=== Chapter1 ===
Your adventure truly begins here.

What would you like to do?

* [Explore the surroundings] -> Explore
* [Talk to someone] -> Dialogue
* [End the story] -> Ending

=== Explore ===
You look around and take in your surroundings.
There's so much to discover!

-> Chapter1

=== Dialogue ===
"Hello, traveler!" someone greets you.
"Welcome to our world."

-> Chapter1

=== Ending ===
Thank you for playing ${name}!

We hope you enjoyed this story.

-> END
`;

    case 'wscript':
      return `// ${name}
// A Whisker Interactive Fiction Story

passage "Start" {
  Welcome to ${name}!

  This is where your story begins.

  var player_name = "Traveler"
  var score = 0

  * [Begin the adventure] -> Chapter1
  * [Set your name] -> SetName
}

passage "SetName" {
  What is your name?

  // Name would be set via input
  var player_name = "Hero"

  -> Start
}

passage "Chapter1" {
  Hello, {player_name}!

  Your adventure truly begins here.
  What would you like to do?

  * [Explore] -> Explore
  * [End] -> Ending
}

passage "Explore" {
  You look around carefully.

  var score = score + 10

  -> Chapter1
}

passage "Ending" {
  Thank you for playing, {player_name}!

  Final score: {score}

  -> END
}
`;

    case 'twee':
      return `:: StoryTitle
${name}

:: StoryData
{
  "ifid": "${generateUUID()}",
  "format": "Whisker",
  "format-version": "1.0.0"
}

:: Start [start]
Welcome to ${name}!

This is where your story begins.

<<set $player_name = "Traveler">>
<<set $score = 0>>

[[Begin the adventure|Chapter1]]
[[Set your name|SetName]]

:: SetName
What is your name?

<<set $player_name = "Hero">>

[[Continue|Start]]

:: Chapter1
Hello, $player_name!

Your adventure truly begins here.
What would you like to do?

[[Explore the area|Explore]]
[[End the story|Ending]]

:: Explore
You look around carefully.

<<set $score = $score + 10>>

[[Return|Chapter1]]

:: Ending
Thank you for playing, $player_name!

Final score: $score

<<set $game_complete = true>>
`;

    default:
      return '';
  }
}

function generateUUID(): string {
  return 'xxxxxxxx-xxxx-4xxx-yxxx-xxxxxxxxxxxx'.replace(/[xy]/g, (c) => {
    const r = Math.random() * 16 | 0;
    const v = c === 'x' ? r : (r & 0x3 | 0x8);
    return v.toString(16);
  });
}

function basicFormat(text: string, languageId: string): string {
  const lines = text.split('\n');
  const formatted: string[] = [];

  for (let i = 0; i < lines.length; i++) {
    let line = lines[i];

    // Trim trailing whitespace
    line = line.trimEnd();

    // Normalize indentation (convert tabs to 2 spaces)
    const leadingWhitespace = line.match(/^[\t ]+/)?.[0] || '';
    const content = line.substring(leadingWhitespace.length);
    const normalizedIndent = leadingWhitespace.replace(/\t/g, '  ');

    formatted.push(normalizedIndent + content);
  }

  // Remove excessive blank lines (more than 2 consecutive)
  let result: string[] = [];
  let blankCount = 0;

  for (const line of formatted) {
    if (line.trim() === '') {
      blankCount++;
      if (blankCount <= 2) {
        result.push(line);
      }
    } else {
      blankCount = 0;
      result.push(line);
    }
  }

  // Ensure file ends with single newline
  while (result.length > 0 && result[result.length - 1].trim() === '') {
    result.pop();
  }
  result.push('');

  return result.join('\n');
}
