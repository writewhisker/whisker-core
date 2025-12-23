# whisker-core Electron Template

Desktop application template for whisker-core using Electron.

## Features

- Cross-platform: Windows, macOS, Linux
- Native menus and keyboard shortcuts
- File system access for saves
- Auto-update support
- Dark mode support

## Project Structure

```
whisker-electron/
├── package.json
├── main.js                 # Main process
├── preload.js              # Preload script (context bridge)
├── renderer/
│   ├── index.html          # Main window HTML
│   ├── renderer.js         # Renderer process
│   └── styles.css          # Styles
├── lua/                    # whisker-core Lua files
│   ├── main.lua
│   └── lib/whisker/
├── build/
│   ├── icon.icns           # macOS icon
│   ├── icon.ico            # Windows icon
│   └── icon.png            # Linux icon
└── forge.config.js         # Electron Forge config
```

## Quick Start

### 1. Create Project

```bash
npm init
npm install electron --save-dev
npm install @electron-forge/cli --save-dev
npx electron-forge import
```

### 2. Main Process

**main.js:**

```javascript
const { app, BrowserWindow, Menu, ipcMain } = require('electron');
const path = require('path');
const fs = require('fs');

let mainWindow;

function createWindow() {
  mainWindow = new BrowserWindow({
    width: 1200,
    height: 800,
    webPreferences: {
      preload: path.join(__dirname, 'preload.js'),
      contextIsolation: true,
      nodeIntegration: false,
    },
  });

  mainWindow.loadFile('renderer/index.html');
  createMenu();
}

function createMenu() {
  const template = [
    {
      label: 'File',
      submenu: [
        {
          label: 'New Game',
          accelerator: 'CmdOrCtrl+N',
          click: () => mainWindow.webContents.send('menu:new-game'),
        },
        {
          label: 'Save Game',
          accelerator: 'CmdOrCtrl+S',
          click: () => mainWindow.webContents.send('menu:save'),
        },
        {
          label: 'Load Game',
          accelerator: 'CmdOrCtrl+O',
          click: () => mainWindow.webContents.send('menu:load'),
        },
        { type: 'separator' },
        { role: 'quit' },
      ],
    },
    {
      label: 'Edit',
      submenu: [
        { role: 'undo' },
        { role: 'redo' },
        { type: 'separator' },
        { role: 'cut' },
        { role: 'copy' },
        { role: 'paste' },
      ],
    },
    {
      label: 'View',
      submenu: [
        { role: 'reload' },
        { role: 'forceReload' },
        { role: 'toggleDevTools' },
        { type: 'separator' },
        { role: 'resetZoom' },
        { role: 'zoomIn' },
        { role: 'zoomOut' },
        { type: 'separator' },
        { role: 'togglefullscreen' },
      ],
    },
    {
      label: 'Help',
      submenu: [
        {
          label: 'About',
          click: () => {
            // Show about dialog
          },
        },
      ],
    },
  ];

  const menu = Menu.buildFromTemplate(template);
  Menu.setApplicationMenu(menu);
}

// IPC handlers for storage
const savesDir = path.join(app.getPath('userData'), 'saves');

ipcMain.handle('storage:save', async (event, key, data) => {
  try {
    if (!fs.existsSync(savesDir)) {
      fs.mkdirSync(savesDir, { recursive: true });
    }
    const filePath = path.join(savesDir, `${key}.json`);
    fs.writeFileSync(filePath, data, 'utf8');
    return true;
  } catch (error) {
    console.error('Save error:', error);
    return false;
  }
});

ipcMain.handle('storage:load', async (event, key) => {
  try {
    const filePath = path.join(savesDir, `${key}.json`);
    if (fs.existsSync(filePath)) {
      return fs.readFileSync(filePath, 'utf8');
    }
    return null;
  } catch (error) {
    console.error('Load error:', error);
    return null;
  }
});

ipcMain.handle('storage:delete', async (event, key) => {
  try {
    const filePath = path.join(savesDir, `${key}.json`);
    if (fs.existsSync(filePath)) {
      fs.unlinkSync(filePath);
    }
    return true;
  } catch (error) {
    console.error('Delete error:', error);
    return false;
  }
});

ipcMain.handle('platform:get-locale', async () => {
  return app.getLocale();
});

ipcMain.handle('platform:has-capability', async (event, cap) => {
  const capabilities = {
    persistent_storage: true,
    filesystem: true,
    network: true,
    touch: false,
    mouse: true,
    keyboard: true,
    gamepad: true,
    clipboard: true,
    notifications: true,
    audio: true,
    camera: false,
    geolocation: false,
    vibration: false,
  };
  return capabilities[cap] || false;
});

app.whenReady().then(createWindow);

app.on('window-all-closed', () => {
  if (process.platform !== 'darwin') {
    app.quit();
  }
});

app.on('activate', () => {
  if (BrowserWindow.getAllWindows().length === 0) {
    createWindow();
  }
});
```

### 3. Preload Script

**preload.js:**

```javascript
const { contextBridge, ipcRenderer } = require('electron');

// Expose safe APIs to renderer
contextBridge.exposeInMainWorld('whiskerPlatform', {
  // Storage
  save: (key, data) => ipcRenderer.invoke('storage:save', key, data),
  load: (key) => ipcRenderer.invoke('storage:load', key),
  delete: (key) => ipcRenderer.invoke('storage:delete', key),

  // Platform
  getLocale: () => ipcRenderer.invoke('platform:get-locale'),
  hasCapability: (cap) => ipcRenderer.invoke('platform:has-capability', cap),

  // Menu events
  onNewGame: (callback) => ipcRenderer.on('menu:new-game', callback),
  onSave: (callback) => ipcRenderer.on('menu:save', callback),
  onLoad: (callback) => ipcRenderer.on('menu:load', callback),
});
```

### 4. Renderer

**renderer/index.html:**

```html
<!DOCTYPE html>
<html>
<head>
  <meta charset="UTF-8">
  <title>Whisker Story</title>
  <link rel="stylesheet" href="styles.css">
  <meta http-equiv="Content-Security-Policy" content="default-src 'self'; script-src 'self'">
</head>
<body>
  <div id="app">
    <div id="story-text"></div>
    <div id="choices"></div>
  </div>
  <script src="renderer.js"></script>
</body>
</html>
```

**renderer/renderer.js:**

```javascript
// Platform bridge for Lua
window.electron_save = async (key, json) => {
  return await window.whiskerPlatform.save(key, json);
};

window.electron_load = async (key) => {
  return await window.whiskerPlatform.load(key);
};

window.electron_delete = async (key) => {
  return await window.whiskerPlatform.delete(key);
};

window.electron_get_locale = async () => {
  return await window.whiskerPlatform.getLocale();
};

window.electron_has_capability = async (cap) => {
  return await window.whiskerPlatform.hasCapability(cap);
};

// Initialize story display
const storyText = document.getElementById('story-text');
const choicesContainer = document.getElementById('choices');

function updateUI(text, choices) {
  storyText.textContent = text;

  choicesContainer.innerHTML = '';
  choices.forEach((choice, index) => {
    const button = document.createElement('button');
    button.className = 'choice-button';
    button.textContent = choice.text;
    button.onclick = () => makeChoice(index);
    choicesContainer.appendChild(button);
  });
}

function makeChoice(index) {
  // Call Lua engine
  window.luaEngine.selectChoice(index);
}

// Menu handlers
window.whiskerPlatform.onNewGame(() => {
  window.luaEngine.restart();
});

window.whiskerPlatform.onSave(() => {
  window.luaEngine.save('quicksave');
});

window.whiskerPlatform.onLoad(() => {
  window.luaEngine.load('quicksave');
});

// Initialize on load
window.addEventListener('DOMContentLoaded', () => {
  // Load Lua engine (via Fengari or native module)
  console.log('Whisker Story initialized');
});
```

**renderer/styles.css:**

```css
* {
  box-sizing: border-box;
  margin: 0;
  padding: 0;
}

body {
  font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif;
  background: var(--background);
  color: var(--text);
  line-height: 1.6;
}

:root {
  --background: #ffffff;
  --text: #1a1a1a;
  --primary: #0066cc;
  --border: #e0e0e0;
}

@media (prefers-color-scheme: dark) {
  :root {
    --background: #1a1a1a;
    --text: #f0f0f0;
    --primary: #4da6ff;
    --border: #404040;
  }
}

#app {
  max-width: 800px;
  margin: 0 auto;
  padding: 40px 20px;
  min-height: 100vh;
  display: flex;
  flex-direction: column;
}

#story-text {
  flex: 1;
  font-size: 18px;
  white-space: pre-wrap;
  margin-bottom: 40px;
}

#choices {
  display: flex;
  flex-direction: column;
  gap: 12px;
}

.choice-button {
  padding: 16px 24px;
  font-size: 16px;
  text-align: left;
  border: 1px solid var(--border);
  border-radius: 8px;
  background: transparent;
  color: var(--text);
  cursor: pointer;
  transition: all 0.2s;
}

.choice-button:hover {
  background: var(--primary);
  color: white;
  border-color: var(--primary);
}

.choice-button:focus {
  outline: 2px solid var(--primary);
  outline-offset: 2px;
}
```

### 5. Package Configuration

**package.json:**

```json
{
  "name": "whisker-story",
  "version": "1.0.0",
  "main": "main.js",
  "scripts": {
    "start": "electron .",
    "package": "electron-forge package",
    "make": "electron-forge make"
  },
  "devDependencies": {
    "@electron-forge/cli": "^7.0.0",
    "@electron-forge/maker-deb": "^7.0.0",
    "@electron-forge/maker-dmg": "^7.0.0",
    "@electron-forge/maker-squirrel": "^7.0.0",
    "@electron-forge/maker-zip": "^7.0.0",
    "electron": "^28.0.0"
  }
}
```

**forge.config.js:**

```javascript
module.exports = {
  packagerConfig: {
    icon: './build/icon',
    asar: true,
    name: 'Whisker Story',
    executableName: 'whisker-story',
  },
  rebuildConfig: {},
  makers: [
    {
      name: '@electron-forge/maker-squirrel',
      config: {
        name: 'WhiskerStory',
        authors: 'Your Name',
        description: 'Interactive fiction powered by whisker-core',
      },
    },
    {
      name: '@electron-forge/maker-zip',
      platforms: ['darwin', 'linux'],
    },
    {
      name: '@electron-forge/maker-deb',
      config: {
        options: {
          maintainer: 'Your Name',
          homepage: 'https://example.com',
        },
      },
    },
    {
      name: '@electron-forge/maker-dmg',
      config: {
        format: 'ULFO',
      },
    },
  ],
};
```

## Building

```bash
# Development
npm start

# Package for current platform
npm run package

# Create distributable for current platform
npm run make

# Create for all platforms (requires cross-platform build tools)
npm run make -- --platform=win32
npm run make -- --platform=darwin
npm run make -- --platform=linux
```

## Auto-Update

Add electron-updater for auto-updates:

```bash
npm install electron-updater
```

**main.js (add):**

```javascript
const { autoUpdater } = require('electron-updater');

app.whenReady().then(() => {
  createWindow();
  autoUpdater.checkForUpdatesAndNotify();
});

autoUpdater.on('update-available', () => {
  mainWindow.webContents.send('update:available');
});

autoUpdater.on('update-downloaded', () => {
  mainWindow.webContents.send('update:downloaded');
});
```

## Keyboard Shortcuts

Default keyboard shortcuts:

| Shortcut | Action |
|----------|--------|
| Cmd/Ctrl+N | New Game |
| Cmd/Ctrl+S | Save |
| Cmd/Ctrl+O | Load |
| Cmd/Ctrl+Q | Quit |
| Cmd/Ctrl++ | Zoom In |
| Cmd/Ctrl+- | Zoom Out |
| F11 | Fullscreen |

## License

MIT
