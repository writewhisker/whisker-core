import * as vscode from 'vscode';
import * as path from 'path';
import * as fs from 'fs';
import { spawn, ChildProcess } from 'child_process';

/**
 * Manages the whisker-lsp server process lifecycle.
 * Handles spawning, monitoring, and terminating the server.
 */
export class ServerManager {
  private serverProcess: ChildProcess | undefined;
  private context: vscode.ExtensionContext;
  private outputChannel: vscode.OutputChannel;

  constructor(context: vscode.ExtensionContext) {
    this.context = context;
    this.outputChannel = vscode.window.createOutputChannel('Whisker LSP Server');
  }

  /**
   * Find the whisker-lsp executable
   */
  findServerExecutable(): string | undefined {
    const config = vscode.workspace.getConfiguration('whisker.lsp');
    const configuredPath = config.get<string>('serverPath');

    // If user configured a path, use it directly
    if (configuredPath && configuredPath !== 'whisker-lsp') {
      if (fs.existsSync(configuredPath)) {
        return configuredPath;
      }
      this.outputChannel.appendLine(`Configured server path not found: ${configuredPath}`);
    }

    // Check common locations
    const possiblePaths = [
      // LuaRocks install location
      '/usr/local/bin/whisker-lsp',
      '/usr/bin/whisker-lsp',
      // Homebrew on macOS
      '/opt/homebrew/bin/whisker-lsp',
      // User local
      path.join(process.env.HOME || '', '.luarocks/bin/whisker-lsp'),
      // Windows common paths
      'C:\\Program Files\\LuaRocks\\bin\\whisker-lsp.bat',
      // Extension bundled (future)
      path.join(this.context.extensionPath, 'server', 'whisker-lsp'),
    ];

    for (const serverPath of possiblePaths) {
      if (fs.existsSync(serverPath)) {
        return serverPath;
      }
    }

    // Fallback to hoping it's in PATH
    return 'whisker-lsp';
  }

  /**
   * Spawn the server process
   */
  async spawnServer(): Promise<ChildProcess | undefined> {
    const serverPath = this.findServerExecutable();
    if (!serverPath) {
      vscode.window.showErrorMessage(
        'Could not find whisker-lsp executable. Please install it via `luarocks install whisker-lsp` or configure whisker.lsp.serverPath.'
      );
      return undefined;
    }

    this.outputChannel.appendLine(`Starting whisker-lsp from: ${serverPath}`);

    try {
      const config = vscode.workspace.getConfiguration('whisker.lsp');
      const logLevel = config.get<string>('logLevel') || 'info';

      this.serverProcess = spawn(serverPath, [], {
        env: {
          ...process.env,
          WHISKER_LSP_LOG_LEVEL: logLevel,
          WHISKER_LSP_LOG: this.getLogPath()
        },
        stdio: ['pipe', 'pipe', 'pipe']
      });

      // Capture stderr for debugging
      this.serverProcess.stderr?.on('data', (data: Buffer) => {
        this.outputChannel.appendLine(`[stderr] ${data.toString()}`);
      });

      this.serverProcess.on('error', (err: Error) => {
        this.outputChannel.appendLine(`Server error: ${err.message}`);
        vscode.window.showErrorMessage(`Whisker LSP server error: ${err.message}`);
      });

      this.serverProcess.on('exit', (code: number | null, signal: string | null) => {
        this.outputChannel.appendLine(`Server exited with code ${code}, signal ${signal}`);
        this.serverProcess = undefined;
      });

      this.outputChannel.appendLine('Server process started');
      return this.serverProcess;

    } catch (err) {
      const error = err as Error;
      this.outputChannel.appendLine(`Failed to start server: ${error.message}`);
      vscode.window.showErrorMessage(`Failed to start whisker-lsp: ${error.message}`);
      return undefined;
    }
  }

  /**
   * Stop the server process
   */
  async stopServer(): Promise<void> {
    if (this.serverProcess) {
      this.outputChannel.appendLine('Stopping server...');
      this.serverProcess.kill('SIGTERM');

      // Wait for graceful shutdown
      await new Promise<void>((resolve) => {
        const timeout = setTimeout(() => {
          if (this.serverProcess) {
            this.serverProcess.kill('SIGKILL');
          }
          resolve();
        }, 5000);

        this.serverProcess?.on('exit', () => {
          clearTimeout(timeout);
          resolve();
        });
      });

      this.serverProcess = undefined;
      this.outputChannel.appendLine('Server stopped');
    }
  }

  /**
   * Check if server is running
   */
  isRunning(): boolean {
    return this.serverProcess !== undefined && !this.serverProcess.killed;
  }

  /**
   * Get the log file path
   */
  private getLogPath(): string {
    const logDir = this.context.globalStorageUri.fsPath;

    // Ensure log directory exists
    if (!fs.existsSync(logDir)) {
      fs.mkdirSync(logDir, { recursive: true });
    }

    return path.join(logDir, 'whisker-lsp.log');
  }

  /**
   * Show the output channel
   */
  showOutput(): void {
    this.outputChannel.show();
  }

  /**
   * Dispose resources
   */
  dispose(): void {
    this.stopServer();
    this.outputChannel.dispose();
  }
}
