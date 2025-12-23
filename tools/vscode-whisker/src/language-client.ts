import * as vscode from 'vscode';
import * as path from 'path';
import {
  LanguageClient,
  LanguageClientOptions,
  ServerOptions,
  Executable
} from 'vscode-languageclient/node';

export class WhiskerLanguageClient {
  private client: LanguageClient | undefined;
  private context: vscode.ExtensionContext;

  constructor(context: vscode.ExtensionContext) {
    this.context = context;
  }

  async start(): Promise<void> {
    const serverOptions = this.getServerOptions();
    const clientOptions = this.getClientOptions();

    this.client = new LanguageClient(
      'whisker-lsp',
      'Whisker Language Server',
      serverOptions,
      clientOptions
    );

    // Start the client (also starts the server)
    await this.client.start();

    console.log('Whisker language server started');
  }

  async stop(): Promise<void> {
    if (this.client) {
      await this.client.stop();
      this.client = undefined;
      console.log('Whisker language server stopped');
    }
  }

  async restart(): Promise<void> {
    await this.stop();
    await this.start();
  }

  private getServerOptions(): ServerOptions {
    const config = vscode.workspace.getConfiguration('whisker.lsp');
    const serverPath = config.get<string>('serverPath') || 'whisker-lsp';

    // Check if server is in PATH or use absolute path
    const executable: Executable = {
      command: serverPath,
      args: [],
      options: {
        env: {
          ...process.env,
          WHISKER_LSP_LOG: this.getLogPath()
        }
      }
    };

    return executable;
  }

  private getClientOptions(): LanguageClientOptions {
    const config = vscode.workspace.getConfiguration('whisker.lsp');

    return {
      documentSelector: [
        { scheme: 'file', language: 'ink' },
        { scheme: 'file', language: 'wscript' },
        { scheme: 'file', language: 'twee' }
      ],
      synchronize: {
        fileEvents: vscode.workspace.createFileSystemWatcher('**/*.{ink,wscript,twee}')
      },
      outputChannelName: 'Whisker Language Server',
      revealOutputChannelOn: 2, // Never (0=Never, 1=Info, 2=Warn, 3=Error)
      initializationOptions: {
        logLevel: config.get<string>('logLevel') || 'info'
      },
      markdown: {
        isTrusted: true,
        supportHtml: true
      }
    };
  }

  private getLogPath(): string {
    // Use extension global storage for logs
    const logDir = this.context.globalStorageUri.fsPath;
    return path.join(logDir, 'whisker-lsp.log');
  }

  getClient(): LanguageClient | undefined {
    return this.client;
  }
}
