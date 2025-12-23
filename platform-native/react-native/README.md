# react-native-whisker-core

React Native wrapper for whisker-core interactive fiction engine.

## Installation

```bash
npm install react-native-whisker-core
# or
yarn add react-native-whisker-core
```

### iOS

```bash
cd ios && pod install
```

### Android

No additional setup required.

## Quick Start

```typescript
import { useWhiskerStory } from 'react-native-whisker-core';

function StoryScreen() {
  const { storyState, loading, error, makeChoice, save, load, restart } = useWhiskerStory();

  if (loading) return <Text>Loading...</Text>;
  if (error) return <Text>Error: {error.message}</Text>;

  return (
    <View style={styles.container}>
      <ScrollView style={styles.textArea}>
        <Text style={styles.storyText}>{storyState.text}</Text>
      </ScrollView>

      <View style={styles.choicesArea}>
        {storyState.choices.map((choice, index) => (
          <Button
            key={index}
            title={choice.text}
            onPress={() => makeChoice(index)}
          />
        ))}
      </View>

      <View style={styles.toolbar}>
        <Button title="Save" onPress={() => save()} />
        <Button title="Load" onPress={() => load()} />
        <Button title="Restart" onPress={restart} />
      </View>
    </View>
  );
}
```

## API Reference

### WhiskerCore (Low-Level API)

```typescript
import WhiskerCore from 'react-native-whisker-core';

// Initialize the engine
await WhiskerCore.initialize();

// Execute Lua code
const result = await WhiskerCore.execute('return engine:get_current_text()');

// Get current story state
const state = await WhiskerCore.getStoryState();

// Make a choice
await WhiskerCore.makeChoice(0);

// Save/load game
await WhiskerCore.save('slot1');
await WhiskerCore.load('slot1');

// Restart story
await WhiskerCore.restart();
```

### useWhiskerStory Hook (Recommended)

```typescript
const {
  storyState,    // { text: string, choices: Choice[] }
  loading,       // boolean
  error,         // Error | null
  makeChoice,    // (index: number) => Promise<void>
  save,          // (slot?: string) => Promise<void>
  load,          // (slot?: string) => Promise<void>
  restart,       // () => Promise<void>
} = useWhiskerStory();
```

### Types

```typescript
interface StoryState {
  text: string;
  choices: Choice[];
}

interface Choice {
  text: string;
  index: number;
}
```

## Project Structure

```
react-native-whisker-core/
├── package.json
├── index.js                    # Main entry point
├── index.d.ts                  # TypeScript definitions
├── src/
│   ├── WhiskerCore.ts          # Core API wrapper
│   ├── useWhiskerStory.ts      # React hook
│   └── types.ts                # TypeScript types
├── ios/
│   ├── WhiskerCore.swift       # iOS native module
│   ├── WhiskerCore.m           # Obj-C bridge
│   └── WhiskerCore.podspec     # CocoaPods spec
├── android/
│   ├── src/main/java/com/whiskernative/
│   │   ├── WhiskerCoreModule.kt
│   │   └── WhiskerCorePackage.kt
│   ├── src/main/cpp/
│   │   ├── luabridge.cpp
│   │   └── CMakeLists.txt
│   └── build.gradle
└── example/                    # Example app
```

## Implementation Details

### iOS Native Module

```swift
// ios/WhiskerCore.swift
import Foundation

@objc(WhiskerCore)
class WhiskerCore: NSObject {
    private let bridge = LuaBridge.shared

    @objc
    func initialize(_ resolve: @escaping RCTPromiseResolveBlock,
                    reject: @escaping RCTPromiseRejectBlock) {
        do {
            try bridge.initialize()
            resolve(true)
        } catch {
            reject("INIT_ERROR", error.localizedDescription, error)
        }
    }

    @objc
    func execute(_ code: String,
                 resolve: @escaping RCTPromiseResolveBlock,
                 reject: @escaping RCTPromiseRejectBlock) {
        do {
            let result = try bridge.execute(code)
            resolve(result)
        } catch {
            reject("EXEC_ERROR", error.localizedDescription, error)
        }
    }

    @objc
    func save(_ slot: String,
              resolve: @escaping RCTPromiseResolveBlock,
              reject: @escaping RCTPromiseRejectBlock) {
        do {
            try bridge.save(to: slot)
            resolve(true)
        } catch {
            reject("SAVE_ERROR", error.localizedDescription, error)
        }
    }

    @objc
    func load(_ slot: String,
              resolve: @escaping RCTPromiseResolveBlock,
              reject: @escaping RCTPromiseRejectBlock) {
        do {
            try bridge.load(from: slot)
            resolve(true)
        } catch {
            reject("LOAD_ERROR", error.localizedDescription, error)
        }
    }

    @objc
    static func requiresMainQueueSetup() -> Bool {
        return false
    }
}
```

### Android Native Module

```kotlin
// android/src/main/java/com/whiskernative/WhiskerCoreModule.kt
package com.whiskernative

import com.facebook.react.bridge.*
import com.whisker.LuaBridge

class WhiskerCoreModule(reactContext: ReactApplicationContext) :
    ReactContextBaseJavaModule(reactContext) {

    private val bridge = LuaBridge(reactContext)

    override fun getName() = "WhiskerCore"

    @ReactMethod
    fun initialize(promise: Promise) {
        try {
            bridge.execute("ENVIRONMENT = 'react-native'")
            bridge.execute("require('main')")
            promise.resolve(true)
        } catch (e: Exception) {
            promise.reject("INIT_ERROR", e.message, e)
        }
    }

    @ReactMethod
    fun execute(code: String, promise: Promise) {
        try {
            val result = bridge.execute(code)
            promise.resolve(result)
        } catch (e: Exception) {
            promise.reject("EXEC_ERROR", e.message, e)
        }
    }

    @ReactMethod
    fun save(slot: String, promise: Promise) {
        try {
            bridge.execute("engine:save_game('$slot')")
            promise.resolve(true)
        } catch (e: Exception) {
            promise.reject("SAVE_ERROR", e.message, e)
        }
    }

    @ReactMethod
    fun load(slot: String, promise: Promise) {
        try {
            bridge.execute("engine:load_game('$slot')")
            promise.resolve(true)
        } catch (e: Exception) {
            promise.reject("LOAD_ERROR", e.message, e)
        }
    }
}
```

### JavaScript API

```typescript
// src/WhiskerCore.ts
import { NativeModules } from 'react-native';

const { WhiskerCore: NativeWhiskerCore } = NativeModules;

class WhiskerCore {
  private initialized = false;

  async initialize(): Promise<void> {
    if (this.initialized) return;
    await NativeWhiskerCore.initialize();
    this.initialized = true;
  }

  async execute(code: string): Promise<string> {
    if (!this.initialized) {
      throw new Error('WhiskerCore not initialized');
    }
    return NativeWhiskerCore.execute(code);
  }

  async getStoryState(): Promise<StoryState> {
    const result = await this.execute('return engine:get_state_json()');
    return JSON.parse(result);
  }

  async makeChoice(index: number): Promise<void> {
    await this.execute(`engine:select_choice(${index})`);
  }

  async save(slot = 'autosave'): Promise<void> {
    await NativeWhiskerCore.save(slot);
  }

  async load(slot = 'autosave'): Promise<void> {
    await NativeWhiskerCore.load(slot);
  }

  async restart(): Promise<void> {
    await this.execute('engine:restart()');
  }
}

export default new WhiskerCore();
```

### React Hook

```typescript
// src/useWhiskerStory.ts
import { useState, useEffect } from 'react';
import WhiskerCore, { StoryState } from './WhiskerCore';

export function useWhiskerStory() {
  const [storyState, setStoryState] = useState<StoryState | null>(null);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<Error | null>(null);

  useEffect(() => {
    initializeStory();
  }, []);

  const initializeStory = async () => {
    try {
      setLoading(true);
      await WhiskerCore.initialize();
      const state = await WhiskerCore.getStoryState();
      setStoryState(state);
    } catch (err) {
      setError(err as Error);
    } finally {
      setLoading(false);
    }
  };

  const makeChoice = async (index: number) => {
    try {
      await WhiskerCore.makeChoice(index);
      const state = await WhiskerCore.getStoryState();
      setStoryState(state);
    } catch (err) {
      setError(err as Error);
    }
  };

  const save = async (slot?: string) => {
    try {
      await WhiskerCore.save(slot);
    } catch (err) {
      setError(err as Error);
    }
  };

  const load = async (slot?: string) => {
    try {
      await WhiskerCore.load(slot);
      const state = await WhiskerCore.getStoryState();
      setStoryState(state);
    } catch (err) {
      setError(err as Error);
    }
  };

  const restart = async () => {
    try {
      await WhiskerCore.restart();
      const state = await WhiskerCore.getStoryState();
      setStoryState(state);
    } catch (err) {
      setError(err as Error);
    }
  };

  return {
    storyState,
    loading,
    error,
    makeChoice,
    save,
    load,
    restart,
  };
}
```

## Publishing

```bash
# Build
npm run prepare

# Test locally
npm pack

# Publish to npm
npm publish
```

## Example App

See the `example/` directory for a complete React Native app using this wrapper.

```bash
cd example
npm install
npm run ios   # or npm run android
```

## License

MIT
