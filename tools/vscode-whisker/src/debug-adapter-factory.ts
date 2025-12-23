import * as vscode from 'vscode';
import * as path from 'path';
import * as fs from 'fs';
import { DebugAdapterExecutable, DebugAdapterDescriptor } from 'vscode';

/**
 * Factory for creating debug adapter descriptors for Whisker stories
 */
export class WhiskerDebugAdapterFactory implements vscode.DebugAdapterDescriptorFactory {
  private context: vscode.ExtensionContext;

  constructor(context: vscode.ExtensionContext) {
    this.context = context;
  }

  createDebugAdapterDescriptor(
    session: vscode.DebugSession,
    executable: vscode.DebugAdapterExecutable | undefined
  ): vscode.ProviderResult<vscode.DebugAdapterDescriptor> {
    // Get configured path or use default
    const config = vscode.workspace.getConfiguration('whisker');
    let debuggerPath = config.get<string>('debug.adapterPath') || 'whisker-debug';

    // Check common locations if default
    if (debuggerPath === 'whisker-debug') {
      const possiblePaths = [
        '/usr/local/bin/whisker-debug',
        '/usr/bin/whisker-debug',
        path.join(process.env.HOME || '', '.luarocks/bin/whisker-debug'),
        path.join(this.context.extensionPath, 'server', 'whisker-debug'),
      ];

      for (const p of possiblePaths) {
        if (fs.existsSync(p)) {
          debuggerPath = p;
          break;
        }
      }
    }

    // Build arguments
    const args: string[] = ['--stdio'];

    return new DebugAdapterExecutable(debuggerPath, args, {
      env: {
        ...process.env,
        WHISKER_DEBUG_LOG: this.getLogPath()
      }
    });
  }

  private getLogPath(): string {
    const logDir = this.context.globalStorageUri.fsPath;
    if (!fs.existsSync(logDir)) {
      fs.mkdirSync(logDir, { recursive: true });
    }
    return path.join(logDir, 'whisker-debug.log');
  }

  dispose(): void {
    // Cleanup if needed
  }
}

/**
 * Debug configuration provider for Whisker stories
 */
export class WhiskerDebugConfigurationProvider implements vscode.DebugConfigurationProvider {
  /**
   * Resolve debug configuration before starting
   */
  resolveDebugConfiguration(
    folder: vscode.WorkspaceFolder | undefined,
    config: vscode.DebugConfiguration,
    token?: vscode.CancellationToken
  ): vscode.ProviderResult<vscode.DebugConfiguration> {
    // If no configuration, create default
    if (!config.type && !config.request && !config.name) {
      const editor = vscode.window.activeTextEditor;
      if (editor && this.isWhiskerFile(editor.document)) {
        config.type = 'whisker';
        config.name = 'Debug Story';
        config.request = 'launch';
        config.program = '${file}';
      }
    }

    // Ensure program is set
    if (!config.program) {
      const editor = vscode.window.activeTextEditor;
      if (editor && this.isWhiskerFile(editor.document)) {
        config.program = editor.document.uri.fsPath;
      } else {
        return vscode.window.showErrorMessage('No story file selected').then(() => undefined);
      }
    }

    // Expand variables
    if (config.program === '${file}') {
      const editor = vscode.window.activeTextEditor;
      if (editor) {
        config.program = editor.document.uri.fsPath;
      }
    }

    // Set defaults
    if (config.stopOnEntry === undefined) {
      config.stopOnEntry = false;
    }

    return config;
  }

  /**
   * Provide initial configurations for launch.json
   */
  provideDebugConfigurations(
    folder: vscode.WorkspaceFolder | undefined,
    token?: vscode.CancellationToken
  ): vscode.ProviderResult<vscode.DebugConfiguration[]> {
    return [
      {
        type: 'whisker',
        request: 'launch',
        name: 'Debug Story',
        program: '${file}',
        stopOnEntry: false
      },
      {
        type: 'whisker',
        request: 'launch',
        name: 'Debug Story (Stop on Entry)',
        program: '${file}',
        stopOnEntry: true
      }
    ];
  }

  private isWhiskerFile(document: vscode.TextDocument): boolean {
    const languageId = document.languageId;
    return languageId === 'ink' || languageId === 'wscript' || languageId === 'twee';
  }
}
