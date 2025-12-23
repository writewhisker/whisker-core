import * as vscode from 'vscode';
import * as path from 'path';
import * as fs from 'fs';
import { exec } from 'child_process';
import { promisify } from 'util';

const execAsync = promisify(exec);

export class StoryPreviewProvider {
  private panel: vscode.WebviewPanel | undefined;
  private context: vscode.ExtensionContext;
  private currentDocument: vscode.TextDocument | undefined;
  private storyState: StoryState | undefined;

  constructor(context: vscode.ExtensionContext) {
    this.context = context;
  }

  async show(document: vscode.TextDocument): Promise<void> {
    this.currentDocument = document;

    if (this.panel) {
      this.panel.reveal(vscode.ViewColumn.Beside);
    } else {
      this.panel = vscode.window.createWebviewPanel(
        'whiskerPreview',
        'Story Preview',
        vscode.ViewColumn.Beside,
        {
          enableScripts: true,
          retainContextWhenHidden: true,
          localResourceRoots: [this.context.extensionUri]
        }
      );

      this.panel.onDidDispose(() => {
        this.panel = undefined;
        this.storyState = undefined;
      });

      this.panel.webview.onDidReceiveMessage(
        message => this.handleMessage(message),
        undefined,
        this.context.subscriptions
      );
    }

    // Reset story state when showing new document
    this.storyState = undefined;
    await this.update();
  }

  async update(): Promise<void> {
    if (!this.panel || !this.currentDocument) {
      return;
    }

    try {
      const state = await this.getStoryState(this.currentDocument);
      this.panel.webview.html = this.getWebviewContent(state);
    } catch (error) {
      this.panel.webview.html = this.getErrorContent(error as Error);
    }
  }

  private async getStoryState(document: vscode.TextDocument): Promise<StoryState> {
    const storyPath = document.uri.fsPath;
    const storageDir = this.context.globalStorageUri.fsPath;

    // Ensure storage directory exists
    if (!fs.existsSync(storageDir)) {
      fs.mkdirSync(storageDir, { recursive: true });
    }

    const tempFile = path.join(storageDir, 'preview-state.json');

    try {
      // Execute whisker-core to render story
      let command = `whisker-run --format json --output "${tempFile}" "${storyPath}"`;

      if (this.storyState?.sessionId) {
        command += ` --session "${this.storyState.sessionId}"`;
      }

      await execAsync(command);

      // Read rendered state
      const stateJson = fs.readFileSync(tempFile, 'utf8');
      this.storyState = JSON.parse(stateJson);
      return this.storyState!;
    } catch (error) {
      // Fallback: parse document directly for basic preview
      return this.parseDocumentForPreview(document);
    }
  }

  private parseDocumentForPreview(document: vscode.TextDocument): StoryState {
    const text = document.getText();
    const passages: Passage[] = [];
    const languageId = document.languageId;

    // Parse passages based on language
    if (languageId === 'ink') {
      // Parse Ink passages: === PassageName ===
      const passageRegex = /^(===+)\s*([\w_]+)\s*(===+)(.*)?$/gm;
      let match;
      let lastEnd = 0;

      const matches: Array<{ name: string; start: number; content?: string }> = [];
      while ((match = passageRegex.exec(text)) !== null) {
        matches.push({
          name: match[2],
          start: match.index + match[0].length
        });
      }

      // Extract content for each passage
      for (let i = 0; i < matches.length; i++) {
        const start = matches[i].start;
        const end = i < matches.length - 1 ? matches[i + 1].start - matches[i + 1].name.length - 8 : text.length;
        const content = text.substring(start, end).trim();

        passages.push({
          name: matches[i].name,
          text: this.cleanPassageContent(content),
          choices: this.extractChoices(content, 'ink')
        });
      }
    } else if (languageId === 'twee') {
      // Parse Twee passages: :: PassageName
      const passageRegex = /^::\s*([^\[\{]+)(?:\s*\[([^\]]+)\])?(?:\s*\{([^\}]+)\})?\s*$/gm;
      let match;
      const matches: Array<{ name: string; start: number; tags?: string }> = [];

      while ((match = passageRegex.exec(text)) !== null) {
        matches.push({
          name: match[1].trim(),
          start: match.index + match[0].length,
          tags: match[2]
        });
      }

      for (let i = 0; i < matches.length; i++) {
        const start = matches[i].start;
        const end = i < matches.length - 1 ? matches[i + 1].start - matches[i + 1].name.length - 4 : text.length;
        const content = text.substring(start, end).trim();

        passages.push({
          name: matches[i].name,
          text: this.cleanPassageContent(content),
          choices: this.extractChoices(content, 'twee')
        });
      }
    } else if (languageId === 'wscript') {
      // Parse WhiskerScript passages: passage "PassageName" {
      const passageRegex = /passage\s+"([^"]+)"\s*\{/g;
      let match;
      const matches: Array<{ name: string; start: number }> = [];

      while ((match = passageRegex.exec(text)) !== null) {
        matches.push({
          name: match[1],
          start: match.index + match[0].length
        });
      }

      for (let i = 0; i < matches.length; i++) {
        const start = matches[i].start;
        // Find matching closing brace
        let braceCount = 1;
        let end = start;
        while (braceCount > 0 && end < text.length) {
          if (text[end] === '{') braceCount++;
          if (text[end] === '}') braceCount--;
          end++;
        }
        const content = text.substring(start, end - 1).trim();

        passages.push({
          name: matches[i].name,
          text: this.cleanPassageContent(content),
          choices: this.extractChoices(content, 'wscript')
        });
      }
    }

    // Find START passage or first passage
    const startPassage = passages.find(p =>
      p.name.toLowerCase() === 'start' ||
      p.name.toLowerCase() === 'beginning'
    ) || passages[0];

    return {
      currentPassage: startPassage || { name: 'Unknown', text: 'No passages found', choices: [] },
      choices: startPassage?.choices || [],
      passages,
      sessionId: undefined
    };
  }

  private cleanPassageContent(content: string): string {
    // Remove choice lines, diverts, and code for display
    return content
      .split('\n')
      .filter(line => {
        const trimmed = line.trim();
        return !trimmed.startsWith('*') &&
               !trimmed.startsWith('+') &&
               !trimmed.startsWith('->') &&
               !trimmed.startsWith('~') &&
               !trimmed.startsWith('<<') &&
               !trimmed.startsWith('[[');
      })
      .join('\n')
      .trim();
  }

  private extractChoices(content: string, language: string): Choice[] {
    const choices: Choice[] = [];

    if (language === 'ink' || language === 'wscript') {
      // Parse * [text] -> target or + [text] -> target
      const choiceRegex = /^[\s]*([\*\+])\s*\[([^\]]*)\](?:\s*->\s*([\w_]+))?/gm;
      let match;
      let index = 0;

      while ((match = choiceRegex.exec(content)) !== null) {
        choices.push({
          index: index++,
          text: match[2],
          target: match[3] || undefined
        });
      }
    } else if (language === 'twee') {
      // Parse [[text|target]] or [[text->target]]
      const linkRegex = /\[\[([^\|\]\-]+)(?:\||\->)?([^\]]*)\]\]/g;
      let match;
      let index = 0;

      while ((match = linkRegex.exec(content)) !== null) {
        choices.push({
          index: index++,
          text: match[1].trim(),
          target: match[2]?.trim() || match[1].trim()
        });
      }
    }

    return choices;
  }

  private getWebviewContent(state: StoryState): string {
    const passageName = this.escapeHtml(state.currentPassage?.name || 'Unknown');
    const passageText = this.formatPassageText(state.currentPassage?.text || '');
    const choices = state.choices || state.currentPassage?.choices || [];

    const choiceItems = choices.map((choice: Choice) => `
      <li class="choice" data-index="${choice.index}" data-target="${this.escapeHtml(choice.target || '')}">
        ${this.escapeHtml(choice.text)}
      </li>
    `).join('');

    const hasChoices = choices.length > 0;
    const isEnd = !hasChoices && (
      state.currentPassage?.text?.includes('-> END') ||
      state.currentPassage?.text?.includes('-> DONE')
    );

    return `<!DOCTYPE html>
    <html lang="en">
    <head>
      <meta charset="UTF-8">
      <meta name="viewport" content="width=device-width, initial-scale=1.0">
      <title>Story Preview</title>
      <style>
        body {
          font-family: var(--vscode-font-family);
          color: var(--vscode-foreground);
          background-color: var(--vscode-editor-background);
          padding: 20px;
          line-height: 1.6;
          max-width: 800px;
          margin: 0 auto;
        }
        .header {
          display: flex;
          justify-content: space-between;
          align-items: center;
          margin-bottom: 20px;
          padding-bottom: 10px;
          border-bottom: 1px solid var(--vscode-panel-border);
        }
        .passage-name {
          font-size: 0.9em;
          color: var(--vscode-textLink-foreground);
          font-weight: bold;
        }
        .restart-btn {
          padding: 5px 10px;
          background-color: var(--vscode-button-secondaryBackground);
          color: var(--vscode-button-secondaryForeground);
          border: none;
          border-radius: 3px;
          cursor: pointer;
          font-size: 0.8em;
        }
        .restart-btn:hover {
          background-color: var(--vscode-button-secondaryHoverBackground);
        }
        .passage {
          margin-bottom: 20px;
          padding: 15px;
          border-left: 3px solid var(--vscode-textLink-foreground);
          background-color: var(--vscode-editor-inactiveSelectionBackground);
        }
        .passage p {
          margin: 0 0 10px 0;
        }
        .passage p:last-child {
          margin-bottom: 0;
        }
        .choices {
          list-style: none;
          padding: 0;
          margin-top: 20px;
        }
        .choice {
          padding: 12px 15px;
          margin: 8px 0;
          background-color: var(--vscode-button-background);
          color: var(--vscode-button-foreground);
          cursor: pointer;
          border-radius: 4px;
          transition: all 0.2s ease;
          border: 1px solid transparent;
        }
        .choice:hover {
          background-color: var(--vscode-button-hoverBackground);
          transform: translateX(5px);
        }
        .choice:active {
          background-color: var(--vscode-button-activeBackground);
        }
        .end-marker {
          text-align: center;
          padding: 20px;
          color: var(--vscode-descriptionForeground);
          font-style: italic;
        }
        .no-choices {
          color: var(--vscode-descriptionForeground);
          font-style: italic;
        }
      </style>
    </head>
    <body>
      <div class="header">
        <span class="passage-name">${passageName}</span>
        <button class="restart-btn" onclick="restart()">↻ Restart</button>
      </div>
      <div class="passage">${passageText}</div>
      ${hasChoices ? `
        <ul class="choices">
          ${choiceItems}
        </ul>
      ` : isEnd ? `
        <div class="end-marker">— The End —</div>
      ` : `
        <p class="no-choices">No choices available</p>
      `}
      <script>
        const vscode = acquireVsCodeApi();

        document.querySelectorAll('.choice').forEach(choice => {
          choice.addEventListener('click', () => {
            const index = parseInt(choice.getAttribute('data-index') || '0');
            const target = choice.getAttribute('data-target');
            vscode.postMessage({command: 'choose', index: index, target: target});
          });
        });

        function restart() {
          vscode.postMessage({command: 'restart'});
        }
      </script>
    </body>
    </html>`;
  }

  private getErrorContent(error: Error): string {
    return `<!DOCTYPE html>
    <html lang="en">
    <head>
      <meta charset="UTF-8">
      <style>
        body {
          font-family: var(--vscode-font-family);
          color: var(--vscode-foreground);
          background-color: var(--vscode-editor-background);
          padding: 20px;
        }
        .error {
          padding: 15px;
          background-color: var(--vscode-inputValidation-errorBackground);
          border: 1px solid var(--vscode-inputValidation-errorBorder);
          border-radius: 4px;
        }
        .error-title {
          font-weight: bold;
          color: var(--vscode-errorForeground);
          margin-bottom: 10px;
        }
        pre {
          white-space: pre-wrap;
          word-wrap: break-word;
          font-size: 0.9em;
        }
      </style>
    </head>
    <body>
      <div class="error">
        <div class="error-title">Preview Error</div>
        <pre>${this.escapeHtml(error.message)}</pre>
      </div>
    </body>
    </html>`;
  }

  private async handleMessage(message: any): Promise<void> {
    if (message.command === 'choose') {
      // Navigate to target passage or execute choice
      if (message.target && this.storyState?.passages) {
        const targetPassage = this.storyState.passages.find(
          p => p.name === message.target
        );
        if (targetPassage) {
          this.storyState.currentPassage = targetPassage;
          this.storyState.choices = targetPassage.choices;
          await this.update();
          return;
        }
      }

      // Try using whisker-run with choice
      if (this.currentDocument) {
        const storyPath = this.currentDocument.uri.fsPath;
        const storageDir = this.context.globalStorageUri.fsPath;
        const tempFile = path.join(storageDir, 'preview-state.json');

        let command = `whisker-run --format json --output "${tempFile}" --choice ${message.index} "${storyPath}"`;
        if (this.storyState?.sessionId) {
          command += ` --session "${this.storyState.sessionId}"`;
        }

        try {
          await execAsync(command);
          await this.update();
        } catch (error) {
          // Fallback to local navigation
          await this.update();
        }
      }
    } else if (message.command === 'restart') {
      this.storyState = undefined;
      await this.update();
    }
  }

  private formatPassageText(text: string): string {
    // Convert newlines to paragraphs
    return text
      .split(/\n\n+/)
      .map(para => `<p>${this.escapeHtml(para.trim()).replace(/\n/g, '<br>')}</p>`)
      .join('');
  }

  private escapeHtml(text: string): string {
    return text
      .replace(/&/g, '&amp;')
      .replace(/</g, '&lt;')
      .replace(/>/g, '&gt;')
      .replace(/"/g, '&quot;')
      .replace(/'/g, '&#039;');
  }
}

interface StoryState {
  currentPassage?: Passage;
  choices: Choice[];
  passages?: Passage[];
  sessionId?: string;
}

interface Passage {
  name: string;
  text: string;
  choices?: Choice[];
}

interface Choice {
  index: number;
  text: string;
  target?: string;
}
