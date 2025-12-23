import * as vscode from 'vscode';
import { exec } from 'child_process';
import { promisify } from 'util';

const execAsync = promisify(exec);

export class GraphProvider {
  private panel: vscode.WebviewPanel | undefined;
  private context: vscode.ExtensionContext;
  private currentDocument: vscode.TextDocument | undefined;

  constructor(context: vscode.ExtensionContext) {
    this.context = context;
  }

  async show(document: vscode.TextDocument): Promise<void> {
    this.currentDocument = document;

    if (this.panel) {
      this.panel.reveal(vscode.ViewColumn.Beside);
    } else {
      this.panel = vscode.window.createWebviewPanel(
        'whiskerGraph',
        'Story Graph',
        vscode.ViewColumn.Beside,
        {
          enableScripts: true,
          retainContextWhenHidden: true
        }
      );

      this.panel.onDidDispose(() => {
        this.panel = undefined;
      });

      this.panel.webview.onDidReceiveMessage(
        message => this.handleMessage(message),
        undefined,
        this.context.subscriptions
      );
    }

    await this.update();
  }

  async update(): Promise<void> {
    if (!this.panel || !this.currentDocument) return;

    try {
      const mermaidCode = await this.generateGraph(this.currentDocument);
      this.panel.webview.html = this.getGraphHtml(mermaidCode);
    } catch (error) {
      // Fallback to local parsing
      const mermaidCode = this.parseDocumentForGraph(this.currentDocument);
      this.panel.webview.html = this.getGraphHtml(mermaidCode);
    }
  }

  private async generateGraph(document: vscode.TextDocument): Promise<string> {
    const storyPath = document.uri.fsPath;
    const { stdout } = await execAsync(`whisker-graph --format mermaid "${storyPath}"`);
    return stdout;
  }

  private parseDocumentForGraph(document: vscode.TextDocument): string {
    const text = document.getText();
    const languageId = document.languageId;
    const passages: Map<string, string[]> = new Map();

    if (languageId === 'ink') {
      // Parse Ink passages
      const passageRegex = /^(===+)\s*([\w_]+)\s*(===+)/gm;
      const divertRegex = /->\s*([\w_]+|END|DONE)/g;
      const choiceRegex = /[\*\+]\s*\[([^\]]*)\](?:\s*->\s*([\w_]+))?/g;

      let match;
      const passageNames: string[] = [];
      const passageContents: Map<string, string> = new Map();

      // First pass: find all passages
      while ((match = passageRegex.exec(text)) !== null) {
        passageNames.push(match[2]);
      }

      // Second pass: extract content between passages
      for (let i = 0; i < passageNames.length; i++) {
        const start = text.indexOf(`=== ${passageNames[i]} ===`) + `=== ${passageNames[i]} ===`.length;
        const end = i < passageNames.length - 1
          ? text.indexOf(`=== ${passageNames[i + 1]} ===`)
          : text.length;
        passageContents.set(passageNames[i], text.substring(start, end));
      }

      // Third pass: find diverts for each passage
      for (const [name, content] of passageContents) {
        const targets: string[] = [];

        // Find direct diverts
        let divertMatch;
        const divertSearch = new RegExp(divertRegex.source, 'g');
        while ((divertMatch = divertSearch.exec(content)) !== null) {
          if (divertMatch[1] !== 'END' && divertMatch[1] !== 'DONE') {
            targets.push(divertMatch[1]);
          }
        }

        // Find choice diverts
        let choiceMatch;
        const choiceSearch = new RegExp(choiceRegex.source, 'g');
        while ((choiceMatch = choiceSearch.exec(content)) !== null) {
          if (choiceMatch[2] && choiceMatch[2] !== 'END' && choiceMatch[2] !== 'DONE') {
            targets.push(choiceMatch[2]);
          }
        }

        passages.set(name, [...new Set(targets)]);
      }
    } else if (languageId === 'twee') {
      // Parse Twee passages
      const passageRegex = /^::\s*([^\[\{]+)(?:\s*\[([^\]]+)\])?/gm;
      const linkRegex = /\[\[([^\|\]\-]+)(?:\||\->)?([^\]]*)\]\]/g;

      let match;
      const passagePositions: Array<{ name: string; start: number }> = [];

      while ((match = passageRegex.exec(text)) !== null) {
        passagePositions.push({
          name: match[1].trim(),
          start: match.index
        });
      }

      for (let i = 0; i < passagePositions.length; i++) {
        const start = passagePositions[i].start;
        const end = i < passagePositions.length - 1
          ? passagePositions[i + 1].start
          : text.length;
        const content = text.substring(start, end);

        const targets: string[] = [];
        let linkMatch;
        const linkSearch = new RegExp(linkRegex.source, 'g');
        while ((linkMatch = linkSearch.exec(content)) !== null) {
          const target = linkMatch[2]?.trim() || linkMatch[1].trim();
          targets.push(target);
        }

        passages.set(passagePositions[i].name, [...new Set(targets)]);
      }
    } else if (languageId === 'wscript') {
      // Parse WhiskerScript
      const passageRegex = /passage\s+"([^"]+)"/g;
      const divertRegex = /->\s*([\w_]+|END|DONE)/g;
      const choiceRegex = /[\*\+]\s*\[([^\]]*)\](?:\s*->\s*([\w_]+))?/g;

      let match;
      const passagePositions: Array<{ name: string; start: number }> = [];

      while ((match = passageRegex.exec(text)) !== null) {
        passagePositions.push({
          name: match[1],
          start: match.index
        });
      }

      for (let i = 0; i < passagePositions.length; i++) {
        const start = passagePositions[i].start;
        const end = i < passagePositions.length - 1
          ? passagePositions[i + 1].start
          : text.length;
        const content = text.substring(start, end);

        const targets: string[] = [];

        let divertMatch;
        const divertSearch = new RegExp(divertRegex.source, 'g');
        while ((divertMatch = divertSearch.exec(content)) !== null) {
          if (divertMatch[1] !== 'END' && divertMatch[1] !== 'DONE') {
            targets.push(divertMatch[1]);
          }
        }

        let choiceMatch;
        const choiceSearch = new RegExp(choiceRegex.source, 'g');
        while ((choiceMatch = choiceSearch.exec(content)) !== null) {
          if (choiceMatch[2] && choiceMatch[2] !== 'END' && choiceMatch[2] !== 'DONE') {
            targets.push(choiceMatch[2]);
          }
        }

        passages.set(passagePositions[i].name, [...new Set(targets)]);
      }
    }

    return this.generateMermaidCode(passages);
  }

  private generateMermaidCode(passages: Map<string, string[]>): string {
    const lines: string[] = ['graph TD'];

    // Find reachable passages
    const reachable = new Set<string>();
    const startNames = ['Start', 'START', 'Beginning', 'start'];
    let startNode: string | undefined;

    for (const name of passages.keys()) {
      if (startNames.includes(name)) {
        startNode = name;
        break;
      }
    }

    if (!startNode && passages.size > 0) {
      startNode = passages.keys().next().value;
    }

    if (startNode) {
      this.findReachable(startNode, passages, reachable);
    }

    // Generate nodes
    for (const name of passages.keys()) {
      const safeId = this.sanitizeId(name);
      const isUnreachable = !reachable.has(name);

      if (isUnreachable) {
        lines.push(`    ${safeId}["${name}"]:::unreachable`);
      } else if (name === startNode) {
        lines.push(`    ${safeId}(["${name}"]):::start`);
      } else {
        lines.push(`    ${safeId}["${name}"]`);
      }
    }

    // Generate edges
    for (const [source, targets] of passages) {
      const sourceId = this.sanitizeId(source);
      for (const target of targets) {
        if (passages.has(target)) {
          const targetId = this.sanitizeId(target);
          lines.push(`    ${sourceId} --> ${targetId}`);
        } else {
          // Target doesn't exist - show as undefined
          const targetId = this.sanitizeId(target);
          lines.push(`    ${targetId}["${target}"]:::undefined`);
          lines.push(`    ${sourceId} --> ${targetId}`);
        }
      }
    }

    // Add styles
    lines.push('');
    lines.push('    classDef start fill:#4CAF50,stroke:#2E7D32,color:#fff');
    lines.push('    classDef unreachable fill:#FF9800,stroke:#F57C00,color:#fff');
    lines.push('    classDef undefined fill:#F44336,stroke:#C62828,color:#fff');

    return lines.join('\n');
  }

  private findReachable(start: string, passages: Map<string, string[]>, visited: Set<string>): void {
    if (visited.has(start)) return;
    visited.add(start);

    const targets = passages.get(start) || [];
    for (const target of targets) {
      if (passages.has(target)) {
        this.findReachable(target, passages, visited);
      }
    }
  }

  private sanitizeId(name: string): string {
    // Convert passage name to valid Mermaid ID
    return name.replace(/[^a-zA-Z0-9_]/g, '_');
  }

  private getGraphHtml(mermaidCode: string): string {
    return `<!DOCTYPE html>
    <html>
    <head>
      <meta charset="UTF-8">
      <script src="https://cdn.jsdelivr.net/npm/mermaid@10/dist/mermaid.min.js"></script>
      <style>
        body {
          background-color: var(--vscode-editor-background);
          color: var(--vscode-foreground);
          font-family: var(--vscode-font-family);
          padding: 20px;
          margin: 0;
          overflow: auto;
        }
        .header {
          display: flex;
          justify-content: space-between;
          align-items: center;
          margin-bottom: 20px;
          padding-bottom: 10px;
          border-bottom: 1px solid var(--vscode-panel-border);
        }
        .title {
          font-size: 1.1em;
          font-weight: bold;
        }
        .refresh-btn {
          padding: 5px 10px;
          background-color: var(--vscode-button-secondaryBackground);
          color: var(--vscode-button-secondaryForeground);
          border: none;
          border-radius: 3px;
          cursor: pointer;
          font-size: 0.8em;
        }
        .refresh-btn:hover {
          background-color: var(--vscode-button-secondaryHoverBackground);
        }
        #graph {
          display: flex;
          justify-content: center;
          min-height: 400px;
        }
        .legend {
          margin-top: 20px;
          padding: 10px;
          background-color: var(--vscode-editor-inactiveSelectionBackground);
          border-radius: 4px;
          font-size: 0.85em;
        }
        .legend-item {
          display: inline-flex;
          align-items: center;
          margin-right: 15px;
        }
        .legend-color {
          width: 12px;
          height: 12px;
          border-radius: 2px;
          margin-right: 5px;
        }
        .legend-start { background-color: #4CAF50; }
        .legend-unreachable { background-color: #FF9800; }
        .legend-undefined { background-color: #F44336; }
      </style>
    </head>
    <body>
      <div class="header">
        <span class="title">Story Graph</span>
        <button class="refresh-btn" onclick="refresh()">↻ Refresh</button>
      </div>
      <div id="graph">
        <pre class="mermaid">
${mermaidCode}
        </pre>
      </div>
      <div class="legend">
        <span class="legend-item">
          <span class="legend-color legend-start"></span> Start passage
        </span>
        <span class="legend-item">
          <span class="legend-color legend-unreachable"></span> Unreachable passage
        </span>
        <span class="legend-item">
          <span class="legend-color legend-undefined"></span> Undefined target
        </span>
      </div>
      <script>
        const vscode = acquireVsCodeApi();

        // Detect dark/light mode
        const isDark = document.body.classList.contains('vscode-dark') ||
                       window.matchMedia('(prefers-color-scheme: dark)').matches;

        mermaid.initialize({
          startOnLoad: true,
          theme: isDark ? 'dark' : 'default',
          flowchart: {
            useMaxWidth: true,
            htmlLabels: true,
            curve: 'basis'
          }
        });

        function refresh() {
          vscode.postMessage({command: 'refresh'});
        }
      </script>
    </body>
    </html>`;
  }

  private handleMessage(message: any): void {
    if (message.command === 'refresh') {
      this.update();
    }
  }
}
