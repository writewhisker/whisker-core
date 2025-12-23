# whisker-core iOS Integration Guide

This guide walks through integrating whisker-core into an iOS application using Swift and SwiftUI.

## Prerequisites

- Xcode 14+ with iOS 15+ deployment target
- Swift 5.7+
- Basic iOS development knowledge
- CocoaPods or Swift Package Manager (optional)

## Architecture Overview

```
┌─────────────────────────────────────────────────────┐
│                    iOS App (Swift)                   │
│  ┌─────────────┐  ┌─────────────┐  ┌─────────────┐  │
│  │  SwiftUI    │  │  ViewModel  │  │   Bridge    │  │
│  │   Views     │  │             │  │             │  │
│  └──────┬──────┘  └──────┬──────┘  └──────┬──────┘  │
│         │                │                │         │
│         └────────────────┼────────────────┘         │
│                          │                          │
│  ┌───────────────────────▼──────────────────────┐   │
│  │              LuaBridge (Swift)                │   │
│  │   - lua_State management                      │   │
│  │   - Swift ↔ Lua function calls               │   │
│  │   - Error handling                           │   │
│  └───────────────────────┬──────────────────────┘   │
│                          │                          │
│  ┌───────────────────────▼──────────────────────┐   │
│  │              IOSPlatform (Swift)              │   │
│  │   - UserDefaults storage                      │   │
│  │   - Locale detection                          │   │
│  │   - Capability detection                      │   │
│  └───────────────────────────────────────────────┘   │
└─────────────────────────────────────────────────────┘
                          │
                          ▼
┌─────────────────────────────────────────────────────┐
│                whisker-core (Lua)                    │
│   - Game engine                                      │
│   - Story parsing                                    │
│   - Save/load system                                 │
└─────────────────────────────────────────────────────┘
```

## Quick Start

### Step 1: Add Lua to Your Project

Download Lua 5.4 source from lua.org and add to your project:

```
YourApp/
├── YourApp/
│   ├── Lua/
│   │   ├── lua.h
│   │   ├── lualib.h
│   │   ├── lauxlib.h
│   │   └── *.c files
```

Create a bridging header:

```objc
// YourApp-Bridging-Header.h
#include "lua.h"
#include "lualib.h"
#include "lauxlib.h"
```

### Step 2: Create LuaBridge

```swift
// LuaBridge.swift
import Foundation

class LuaBridge {
    static let shared = LuaBridge()

    private var L: OpaquePointer?
    private let platform: IOSPlatform

    private init() {
        platform = IOSPlatform()
        initializeLua()
    }

    private func initializeLua() {
        L = luaL_newstate()
        luaL_openlibs(L)

        // Register platform bridge functions
        registerPlatformFunctions()

        // Load whisker-core
        loadWhiskerCore()
    }

    private func registerPlatformFunctions() {
        // ios_platform_save
        lua_pushcfunction(L) { L in
            guard let key = String(cString: lua_tostring(L, 1), encoding: .utf8),
                  let json = String(cString: lua_tostring(L, 2), encoding: .utf8) else {
                lua_pushboolean(L, 0)
                return 1
            }

            let result = IOSPlatform.shared.save(key: key, json: json)
            lua_pushboolean(L, result ? 1 : 0)
            return 1
        }
        lua_setglobal(L, "ios_platform_save")

        // ios_platform_load
        lua_pushcfunction(L) { L in
            guard let key = String(cString: lua_tostring(L, 1), encoding: .utf8) else {
                lua_pushnil(L)
                return 1
            }

            if let json = IOSPlatform.shared.load(key: key) {
                lua_pushstring(L, json)
            } else {
                lua_pushnil(L)
            }
            return 1
        }
        lua_setglobal(L, "ios_platform_load")

        // ios_platform_get_locale
        lua_pushcfunction(L) { L in
            let locale = IOSPlatform.shared.getLocale()
            lua_pushstring(L, locale)
            return 1
        }
        lua_setglobal(L, "ios_platform_get_locale")

        // ios_platform_has_capability
        lua_pushcfunction(L) { L in
            guard let cap = String(cString: lua_tostring(L, 1), encoding: .utf8) else {
                lua_pushboolean(L, 0)
                return 1
            }

            let result = IOSPlatform.shared.hasCapability(cap)
            lua_pushboolean(L, result ? 1 : 0)
            return 1
        }
        lua_setglobal(L, "ios_platform_has_capability")
    }

    private func loadWhiskerCore() {
        // Set environment
        execute("ENVIRONMENT = 'ios'")

        // Load main entry point
        if let mainPath = Bundle.main.path(forResource: "main", ofType: "lua", inDirectory: "Lua") {
            luaL_dofile(L, mainPath)
        }
    }

    func execute(_ code: String) throws {
        if luaL_dostring(L, code) != LUA_OK {
            let error = String(cString: lua_tostring(L, -1))
            lua_pop(L, 1)
            throw LuaError.executionFailed(error)
        }
    }

    func startStory() throws {
        try execute("engine:start()")
    }

    func getCurrentText() throws -> String {
        try execute("__result = engine:get_current_text()")
        lua_getglobal(L, "__result")
        defer { lua_pop(L, 1) }
        return String(cString: lua_tostring(L, -1))
    }

    func getCurrentChoices() throws -> [Choice] {
        try execute("__result = engine:get_choices_json()")
        lua_getglobal(L, "__result")
        defer { lua_pop(L, 1) }

        let json = String(cString: lua_tostring(L, -1))
        return try JSONDecoder().decode([Choice].self, from: json.data(using: .utf8)!)
    }

    func selectChoice(_ index: Int) throws {
        try execute("engine:select_choice(\(index))")
    }

    func save(to slot: String) throws {
        try execute("engine:save_game('\(slot)')")
    }

    func load(from slot: String) throws {
        try execute("engine:load_game('\(slot)')")
    }

    func saveExists(_ slot: String) -> Bool {
        return platform.saveExists(slot)
    }

    deinit {
        if let L = L {
            lua_close(L)
        }
    }
}

enum LuaError: Error {
    case executionFailed(String)
}

struct Choice: Codable, Identifiable {
    let id: Int
    let text: String
}
```

### Step 3: Create IOSPlatform

```swift
// IOSPlatform.swift
import Foundation
import UIKit

class IOSPlatform {
    static let shared = IOSPlatform()

    private let defaults = UserDefaults.standard
    private let storagePrefix = "whisker_"

    // MARK: - Storage

    func save(key: String, json: String) -> Bool {
        defaults.set(json, forKey: storagePrefix + key)
        return true
    }

    func load(key: String) -> String? {
        return defaults.string(forKey: storagePrefix + key)
    }

    func delete(key: String) -> Bool {
        defaults.removeObject(forKey: storagePrefix + key)
        return true
    }

    func saveExists(_ slot: String) -> Bool {
        return defaults.object(forKey: storagePrefix + slot) != nil
    }

    // MARK: - Locale

    func getLocale() -> String {
        return Locale.current.identifier.replacingOccurrences(of: "_", with: "-")
    }

    // MARK: - Capabilities

    func hasCapability(_ cap: String) -> Bool {
        switch cap {
        case "persistent_storage":
            return true
        case "filesystem":
            return true
        case "network":
            return true
        case "touch":
            return true
        case "mouse":
            // iPad with trackpad
            if #available(iOS 14.0, *) {
                return UIDevice.current.userInterfaceIdiom == .pad
            }
            return false
        case "keyboard":
            return true
        case "gamepad":
            return true
        case "clipboard":
            return true
        case "notifications":
            return true
        case "audio":
            return true
        case "camera":
            return UIImagePickerController.isSourceTypeAvailable(.camera)
        case "geolocation":
            return true
        case "vibration":
            return true
        default:
            return false
        }
    }
}
```

### Step 4: Create SwiftUI Views

```swift
// StoryView.swift
import SwiftUI

struct StoryView: View {
    @StateObject private var viewModel = StoryViewModel()

    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Story text
                ScrollView {
                    Text(viewModel.currentText)
                        .font(.body)
                        .padding()
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .frame(maxHeight: .infinity)

                Divider()

                // Choices
                VStack(spacing: 12) {
                    ForEach(viewModel.choices) { choice in
                        Button(action: { viewModel.selectChoice(choice.id) }) {
                            HStack {
                                Image(systemName: "chevron.right")
                                Text(choice.text)
                                Spacer()
                            }
                            .padding()
                            .background(Color.accentColor.opacity(0.1))
                            .cornerRadius(8)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding()
            }
            .navigationTitle("Story")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Menu {
                        Button("Save") { viewModel.save() }
                        Button("Load") { viewModel.load() }
                        Button("Restart") { viewModel.restart() }
                    } label: {
                        Image(systemName: "ellipsis.circle")
                    }
                }
            }
        }
    }
}
```

### Step 5: Create ViewModel

```swift
// StoryViewModel.swift
import Foundation
import Combine

class StoryViewModel: ObservableObject {
    @Published var currentText: String = ""
    @Published var choices: [Choice] = []
    @Published var isLoading: Bool = false
    @Published var errorMessage: String?

    private let bridge = LuaBridge.shared

    init() {
        loadStory()
    }

    func loadStory() {
        isLoading = true
        defer { isLoading = false }

        do {
            try bridge.startStory()
            updateUI()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func selectChoice(_ index: Int) {
        do {
            try bridge.selectChoice(index)
            updateUI()

            // Haptic feedback
            let impact = UIImpactFeedbackGenerator(style: .light)
            impact.impactOccurred()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func save() {
        do {
            try bridge.save(to: "quicksave")
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func load() {
        do {
            try bridge.load(from: "quicksave")
            updateUI()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func restart() {
        loadStory()
    }

    private func updateUI() {
        do {
            currentText = try bridge.getCurrentText()
            choices = try bridge.getCurrentChoices()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
```

## App Lifecycle

Handle backgrounding to auto-save:

```swift
// YourApp.swift
@main
struct YourApp: App {
    @Environment(\.scenePhase) private var scenePhase

    var body: some Scene {
        WindowGroup {
            StoryView()
        }
        .onChange(of: scenePhase) { phase in
            if phase == .background {
                // Auto-save when entering background
                try? LuaBridge.shared.save(to: "autosave")
            }
        }
    }
}
```

## Best Practices

1. **Thread Safety**: Run Lua on main thread or use a dedicated queue
2. **Memory Management**: Clean up lua_State on deinit
3. **Error Handling**: Wrap all Lua calls in try/catch
4. **Haptic Feedback**: Add UIImpactFeedbackGenerator for touch interactions
5. **Dark Mode**: Support both light and dark themes with system colors
6. **Dynamic Type**: Use `.font(.body)` and other dynamic type styles
7. **Accessibility**: Add accessibilityLabel and accessibilityHint

## Testing

```swift
// LuaBridgeTests.swift
import XCTest

class LuaBridgeTests: XCTestCase {
    func testPlatformSaveLoad() {
        let platform = IOSPlatform.shared

        XCTAssertTrue(platform.save(key: "test", json: "{\"value\":42}"))

        let loaded = platform.load(key: "test")
        XCTAssertEqual(loaded, "{\"value\":42}")

        XCTAssertTrue(platform.delete(key: "test"))
        XCTAssertNil(platform.load(key: "test"))
    }

    func testCapabilities() {
        let platform = IOSPlatform.shared

        XCTAssertTrue(platform.hasCapability("touch"))
        XCTAssertTrue(platform.hasCapability("persistent_storage"))
    }
}
```

## Resources

- [Lua 5.4 Reference Manual](https://www.lua.org/manual/5.4/)
- [Apple Human Interface Guidelines](https://developer.apple.com/design/human-interface-guidelines/)
- [SwiftUI Documentation](https://developer.apple.com/documentation/swiftui)
