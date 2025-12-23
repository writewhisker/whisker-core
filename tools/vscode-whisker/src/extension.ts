import * as vscode from 'vscode';
import { WhiskerLanguageClient } from './language-client';
import { StoryPreviewProvider } from './preview-provider';
import { GraphProvider } from './graph-provider';
import { registerCommands } from './commands';
import { WhiskerDebugAdapterFactory, WhiskerDebugConfigurationProvider } from './debug-adapter-factory';

let client: WhiskerLanguageClient | undefined;
let previewProvider: StoryPreviewProvider | undefined;
let graphProvider: GraphProvider | undefined;
let debugAdapterFactory: WhiskerDebugAdapterFactory | undefined;

// Extension activation
export function activate(context: vscode.ExtensionContext) {
  console.log('Whisker extension activating...');

  // Create and start language client
  client = new WhiskerLanguageClient(context);
  client.start();

  // Create providers
  previewProvider = new StoryPreviewProvider(context);
  graphProvider = new GraphProvider(context);

  // Register commands
  registerCommands(context, previewProvider, graphProvider);

  // Register restart command
  const restartCommand = vscode.commands.registerCommand(
    'whisker.restartServer',
    async () => {
      if (client) {
        await client.restart();
        vscode.window.showInformationMessage('Whisker language server restarted');
      }
    }
  );

  // Auto-refresh preview on save
  const saveListener = vscode.workspace.onDidSaveTextDocument(async (document) => {
    const languageId = document.languageId;
    if (languageId === 'ink' || languageId === 'wscript' || languageId === 'twee') {
      if (previewProvider) {
        await previewProvider.update();
      }
    }
  });

  // Register document change listener for live preview
  const changeListener = vscode.workspace.onDidChangeTextDocument(async (event) => {
    const config = vscode.workspace.getConfiguration('whisker');
    const livePreview = config.get<boolean>('preview.liveUpdate', false);

    if (livePreview && previewProvider) {
      const languageId = event.document.languageId;
      if (languageId === 'ink' || languageId === 'wscript' || languageId === 'twee') {
        // Debounce updates
        await previewProvider.update();
      }
    }
  });

  context.subscriptions.push(restartCommand, saveListener, changeListener);

  // Register debug adapter
  debugAdapterFactory = new WhiskerDebugAdapterFactory(context);
  const debugConfigProvider = new WhiskerDebugConfigurationProvider();

  context.subscriptions.push(
    vscode.debug.registerDebugAdapterDescriptorFactory('whisker', debugAdapterFactory),
    vscode.debug.registerDebugConfigurationProvider('whisker', debugConfigProvider)
  );

  console.log('Whisker extension activated');
}

// Extension deactivation
export async function deactivate(): Promise<void> {
  if (client) {
    await client.stop();
  }
}
