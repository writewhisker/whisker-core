# Storage Sync System

The Whisker Storage Sync System provides cross-device synchronization for interactive fiction stories. It enables seamless collaboration and multi-device workflows by keeping story data synchronized across different devices and platforms.

## Table of Contents

1. [Quick Start](#quick-start)
2. [Architecture](#architecture)
3. [Configuration](#configuration)
4. [Usage](#usage)
5. [Conflict Resolution](#conflict-resolution)
6. [Transports](#transports)
7. [API Reference](#api-reference)
8. [Examples](#examples)
9. [Troubleshooting](#troubleshooting)

---

## Quick Start

### Installation

The sync system is included with whisker-core. No additional installation is required.

### Basic Setup

1. **Configure sync:**

```bash
lua bin/whisker.lua sync config \
  --url https://api.example.com/sync \
  --key YOUR_API_KEY
```

2. **Force a sync:**

```bash
lua bin/whisker.lua sync now
```

3. **Check status:**

```bash
lua bin/whisker.lua sync status
```

### First Sync

```lua
-- Programmatic setup
local SyncEngine = require("whisker.storage.sync.engine")
local HTTPTransport = require("whisker.storage.sync.transports.http")
local Storage = require("whisker.storage")

-- Create storage
local storage = Storage.new({
  backend = "filesystem",
  path = ".whisker-storage"
})
storage:initialize()

-- Create transport
local transport = HTTPTransport.new({
  base_url = "https://api.example.com/sync",
  api_key = "YOUR_API_KEY"
})

-- Create sync engine
local engine = SyncEngine.new({
  storage = storage,
  transport = transport,
  device_id = "my-device-123",
  sync_interval = 60000  -- 1 minute
})

-- Start syncing
engine:start_sync()

-- Or sync once
local success, err = engine:sync_now()
if not success then
  print("Sync failed:", err)
end
```

---

## Architecture

### Overview

The sync system consists of four main components:

```
┌──────────────────────────────────────────────────┐
│                                                  │
│                  SyncEngine                      │
│   (Orchestrates synchronization)                 │
│                                                  │
└────────┬─────────────────────┬──────────────────┘
         │                     │
         │                     │
    ┌────▼─────┐         ┌────▼─────────┐
    │          │         │              │
    │ Protocol │         │  Transport   │
    │          │         │  (HTTP/WS)   │
    └────┬─────┘         └────┬─────────┘
         │                     │
         │                     │
    ┌────▼─────────────────────▼────┐
    │                               │
    │       StateManager            │
    │   (Persistent state)          │
    │                               │
    └───────────────────────────────┘
```

### Components

#### 1. Protocol (`lib/whisker/storage/sync/protocol.lua`)

Defines the synchronization protocol including:
- Operation types (CREATE, UPDATE, DELETE, METADATA_UPDATE)
- Conflict detection using version vectors
- Conflict resolution strategies
- Delta generation and application

**Key Functions:**
- `create_operation()` - Create sync operations
- `detect_conflicts()` - Find conflicting changes
- `resolve_conflict()` - Apply resolution strategy
- `generate_delta()` - Create minimal change sets
- `apply_delta()` - Apply changes

#### 2. SyncEngine (`lib/whisker/storage/sync/engine.lua`)

Orchestrates the synchronization process:
- Fetches remote operations
- Pushes local changes
- Resolves conflicts
- Emits events
- Manages auto-sync

**Key Methods:**
- `sync_now()` - Force immediate sync
- `start_sync()` - Begin auto-sync
- `stop_sync()` - Stop auto-sync
- `get_sync_status()` - Query current state

#### 3. Transports

Provide network communication:

**HTTP Transport** (`lib/whisker/storage/sync/transports/http.lua`)
- RESTful API communication
- Retry logic with exponential backoff
- Bearer token authentication
- Works with luasocket/luasec

**WebSocket Transport** (`lib/whisker/storage/sync/transports/websocket.lua`)
- Real-time bidirectional communication
- Auto-reconnect on disconnect
- Keep-alive ping/pong
- Push notifications for instant updates

#### 4. StateManager (`lib/whisker/storage/sync/state_manager.lua`)

Persists sync metadata:
- Device ID (UUID)
- Last sync timestamp
- Version vectors
- Pending operations queue
- Sync statistics
- Error tracking

---

## Configuration

### CLI Configuration

```bash
whisker sync config [OPTIONS]
```

**Options:**

| Option | Description | Default |
|--------|-------------|---------|
| `--url <url>` | Sync server URL | Required |
| `--key <key>` | API key for authentication | Required |
| `--transport <type>` | Transport: `http` or `websocket` | `http` |
| `--interval <ms>` | Auto-sync interval (milliseconds) | `60000` |
| `--device-name <name>` | Human-readable device name | `"Unknown Device"` |
| `--strategy <strategy>` | Conflict resolution strategy | `last_write_wins` |

**Example:**

```bash
whisker sync config \
  --url wss://sync.whisker.app/api \
  --key sk_1234567890abcdef \
  --transport websocket \
  --interval 30000 \
  --device-name "My Laptop" \
  --strategy auto_merge
```

### Configuration File

Configuration is stored in `.whisker-sync-config.json`:

```json
{
  "url": "https://api.example.com/sync",
  "api_key": "YOUR_API_KEY",
  "transport": "http",
  "sync_interval": 60000,
  "device_name": "My Laptop",
  "conflict_strategy": "last_write_wins"
}
```

### Programmatic Configuration

```lua
local config = {
  storage = storage_instance,
  transport = transport_instance,
  device_id = "device-uuid",
  sync_interval = 60000,
  conflict_strategy = "last_write_wins",
  on_conflict = function(conflict)
    -- Custom conflict handler
    return resolved_data
  end
}

local engine = SyncEngine.new(config)
```

---

## Usage

### CLI Commands

#### Configure Sync

```bash
whisker sync config --url URL --key KEY
```

Sets up synchronization with a remote server.

#### Start Auto-Sync

```bash
whisker sync start
```

Starts background synchronization at configured interval.

#### Stop Sync

```bash
whisker sync stop
```

Stops background synchronization.

#### Force Immediate Sync

```bash
whisker sync now
```

Performs a single sync operation immediately.

#### Check Status

```bash
whisker sync status
```

Displays current sync state:
- Status (idle, syncing, error)
- Last sync time
- Device ID
- Pending operations
- Last error (if any)

**Example Output:**

```
Sync Status
───────────
Status: idle
Last sync: 5 minutes ago
Device: My Laptop (550e8400-e29b-41d4-a716-446655440000)
Pending: 0 operations
```

#### View Statistics

```bash
whisker sync stats
```

Shows sync statistics:
- Total syncs performed
- Last sync duration
- Conflicts resolved
- Bandwidth usage

**Example Output:**

```
Sync Statistics
───────────────
Total syncs: 42
Last sync duration: 234ms
Conflicts resolved: 5
Bandwidth: ↓ 1.2 MB, ↑ 0.8 MB
```

#### Reset State

```bash
whisker sync reset
```

Resets all sync state (preserves device ID). Requires confirmation.

### Programmatic API

#### Basic Sync

```lua
local SyncEngine = require("whisker.storage.sync.engine")
local HTTPTransport = require("whisker.storage.sync.transports.http")

local engine = SyncEngine.new({
  storage = storage,
  transport = HTTPTransport.new({
    base_url = "https://api.example.com/sync",
    api_key = "YOUR_API_KEY"
  }),
  device_id = "device-123"
})

-- Sync once
local success, err = engine:sync_now()
if not success then
  print("Error:", err)
end
```

#### Auto-Sync

```lua
-- Start auto-sync every 60 seconds
engine:start_sync()

-- Later...
engine:stop_sync()
```

#### Event Handlers

```lua
engine:on("sync_started", function(data)
  print("Sync started")
end)

engine:on("sync_progress", function(data)
  print(string.format("Progress: %d/%d", data.current, data.total))
end)

engine:on("sync_completed", function(data)
  print(string.format("Synced %d operations, resolved %d conflicts",
    data.operations_applied, data.conflicts_resolved))
end)

engine:on("sync_failed", function(data)
  print("Sync failed:", data.error)
end)

engine:on("conflict_detected", function(data)
  print("Conflict:", data.conflict.local_version, "vs", data.conflict.remote_version)
end)
```

#### State Management

```lua
local StateManager = require("whisker.storage.sync.state_manager")

local state_mgr = StateManager.new(storage)

-- Get device ID
local device_id = state_mgr:get_device_id()

-- Check pending operations
local pending = state_mgr:get_pending_operations()
print("Pending:", #pending)

-- Get stats
local stats = state_mgr:get_stats()
print("Total syncs:", stats.total_syncs)

-- Check error state
if state_mgr:has_error() then
  local err = state_mgr:get_last_error()
  print("Last error:", err.message)
end
```

---

## Conflict Resolution

### Strategies

The sync system supports multiple conflict resolution strategies:

#### 1. Last Write Wins (default)

The most recent modification wins based on timestamp.

```lua
conflict_strategy = "last_write_wins"
```

**Pros:**
- Simple and predictable
- No user intervention required

**Cons:**
- May lose data if concurrent edits
- Relies on accurate timestamps

#### 2. Auto Merge

Attempts to automatically merge non-conflicting changes.

```lua
conflict_strategy = "auto_merge"
```

**Pros:**
- Preserves more changes
- Smart field-level merging

**Cons:**
- May produce unexpected results
- Complex conflicts still need manual resolution

#### 3. Keep Both

Creates separate copies when conflicts occur.

```lua
conflict_strategy = "keep_both"
```

**Pros:**
- Never loses data
- User can manually merge later

**Cons:**
- Creates duplicate stories
- Requires manual cleanup

#### 4. Manual Resolution

Prompts for user intervention.

```lua
conflict_strategy = "manual"
```

**Pros:**
- User has full control
- Most accurate resolution

**Cons:**
- Requires user interaction
- Slower sync process

### Custom Resolvers

You can provide a custom conflict resolver:

```lua
local engine = SyncEngine.new({
  storage = storage,
  transport = transport,
  device_id = "device-123",
  on_conflict = function(conflict)
    -- conflict.local_version - Local data
    -- conflict.remote_version - Remote data
    -- conflict.base_version - Common ancestor (if available)
    
    -- Custom resolution logic
    local resolved = {}
    resolved.title = conflict.local_version.title -- Keep local title
    resolved.author = conflict.remote_version.author -- Take remote author
    resolved.passages = merge_passages(
      conflict.local_version.passages,
      conflict.remote_version.passages
    )
    
    return resolved
  end
})
```

### Conflict Detection

Conflicts are detected using version vectors:

```lua
local Protocol = require("whisker.storage.sync.protocol")

local local_ops = {...}
local remote_ops = {...}

local conflicts = Protocol.detect_conflicts(local_ops, remote_ops)

for _, conflict in ipairs(conflicts) do
  print("Conflict on story:", conflict.story_id)
  print("Local version:", conflict.local_version)
  print("Remote version:", conflict.remote_version)
end
```

---

## Transports

### HTTP Transport

RESTful API-based synchronization.

#### Setup

```lua
local HTTPTransport = require("whisker.storage.sync.transports.http")

local transport = HTTPTransport.new({
  base_url = "https://api.example.com/sync",
  api_key = "YOUR_API_KEY",
  timeout = 30000  -- 30 seconds
})
```

#### API Endpoints

The HTTP transport expects the following endpoints:

**Fetch Operations:**
```
GET /operations?device={device_id}&since={version}

Response:
{
  "operations": [
    {
      "type": "UPDATE",
      "story_id": "story-1",
      "data": {...},
      "timestamp": 1234567890,
      "version": 42
    }
  ],
  "version": 42,
  "has_more": false
}
```

**Push Operations:**
```
POST /operations
Content-Type: application/json

Body:
{
  "device_id": "device-123",
  "operations": [...]
}

Response:
{
  "success": true,
  "conflicts": [],
  "version": 43
}
```

**Get Server Version:**
```
GET /version?device={device_id}

Response:
{
  "version": 42
}
```

### WebSocket Transport

Real-time bidirectional synchronization.

#### Setup

```lua
local WebSocketTransport = require("whisker.storage.sync.transports.websocket")

local transport = WebSocketTransport.new({
  ws_url = "wss://api.example.com/sync",
  api_key = "YOUR_API_KEY",
  reconnect = true,
  ping_interval = 30000  -- 30 seconds
})

-- Connect
transport:connect()

-- Listen for events
transport:on("connected", function()
  print("Connected to sync server")
end)

transport:on("remote_change", function(data)
  print("Remote change detected:", data.operation.story_id)
end)
```

#### Message Protocol

**Client → Server:**

```json
{
  "type": "sync_request",
  "device_id": "device-123",
  "since_version": 42,
  "operations": []
}
```

```json
{
  "type": "push_operations",
  "device_id": "device-123",
  "operations": [...]
}
```

**Server → Client:**

```json
{
  "type": "sync_response",
  "operations": [...],
  "version": 43,
  "conflicts": []
}
```

```json
{
  "type": "remote_change",
  "operation": {
    "type": "UPDATE",
    "story_id": "story-1",
    "data": {...}
  }
}
```

**Keep-Alive:**

```json
{"type": "ping"}
{"type": "pong"}
```

### Custom Transports

Implement the transport interface:

```lua
local MyTransport = {}

function MyTransport.new(config)
  local self = setmetatable({}, {__index = MyTransport})
  -- Initialize transport
  return self
end

function MyTransport:fetch_operations(device_id, since_version)
  -- Fetch operations from server
  return {
    operations = {...},
    version = 42,
    has_more = false
  }
end

function MyTransport:push_operations(device_id, operations)
  -- Push operations to server
  return {
    success = true,
    conflicts = {},
    version = 43
  }
end

function MyTransport:get_server_version()
  return {version = 42}
end

function MyTransport:is_available()
  return true
end

return MyTransport
```

---

## API Reference

### SyncEngine

#### Constructor

```lua
SyncEngine.new(config)
```

**Parameters:**
- `config.storage` (table) - Storage service instance
- `config.transport` (table) - Transport adapter
- `config.device_id` (string) - Unique device identifier
- `config.sync_interval` (number) - Auto-sync interval in ms (optional)
- `config.conflict_strategy` (string) - Conflict resolution strategy (optional)
- `config.on_conflict` (function) - Custom conflict resolver (optional)

#### Methods

##### sync_now()

```lua
local success, error = engine:sync_now()
```

Performs immediate synchronization.

**Returns:**
- `success` (boolean) - True if sync succeeded
- `error` (string|nil) - Error message if failed

##### start_sync()

```lua
engine:start_sync()
```

Starts automatic synchronization at configured interval.

##### stop_sync()

```lua
engine:stop_sync()
```

Stops automatic synchronization.

##### get_sync_status()

```lua
local status = engine:get_sync_status()
```

Returns current sync status.

**Returns:**
- `status` (table) - {status, last_sync_time}

##### on(event, callback)

```lua
engine:on("sync_completed", function(data)
  -- Handle event
end)
```

Register event listener.

**Events:**
- `sync_started` - Sync initiated
- `sync_progress` - Sync in progress
- `sync_completed` - Sync finished successfully
- `sync_failed` - Sync failed
- `conflict_detected` - Conflict detected

### Protocol

#### create_operation(type, story_id, data, metadata)

Creates a sync operation.

**Parameters:**
- `type` (string) - Operation type (CREATE, UPDATE, DELETE, METADATA_UPDATE)
- `story_id` (string) - Story identifier
- `data` (table) - Operation data
- `metadata` (table) - Operation metadata (optional)

**Returns:**
- `operation` (table) - Sync operation

#### detect_conflicts(local_ops, remote_ops)

Detects conflicts between local and remote operations.

**Returns:**
- `conflicts` (table[]) - Array of conflicts

#### resolve_conflict(conflict, strategy, resolver_fn)

Resolves a conflict using specified strategy.

**Returns:**
- `resolved_data` (table) - Resolved data

### StateManager

#### new(storage_service)

Creates state manager instance.

#### get_device_id()

Returns unique device identifier.

#### get_pending_operations()

Returns queued operations.

#### get_stats()

Returns sync statistics.

---

## Examples

### Example 1: Basic Sync Setup

```lua
local Storage = require("whisker.storage")
local SyncEngine = require("whisker.storage.sync.engine")
local HTTPTransport = require("whisker.storage.sync.transports.http")

-- Create storage
local storage = Storage.new({
  backend = "filesystem",
  path = ".whisker-storage"
})
storage:initialize()

-- Create sync engine
local engine = SyncEngine.new({
  storage = storage,
  transport = HTTPTransport.new({
    base_url = "https://sync.example.com/api",
    api_key = "sk_test_123"
  }),
  device_id = "my-laptop",
  sync_interval = 60000
})

-- Sync now
local success, err = engine:sync_now()
if success then
  print("✓ Sync complete")
else
  print("✗ Sync failed:", err)
end
```

### Example 2: Real-Time Sync with WebSocket

```lua
local WebSocketTransport = require("whisker.storage.sync.transports.websocket")

local transport = WebSocketTransport.new({
  ws_url = "wss://sync.example.com/ws",
  api_key = "sk_test_123",
  reconnect = true
})

-- Listen for real-time updates
transport:on("remote_change", function(data)
  print("📡 Remote update:", data.operation.story_id)
end)

local engine = SyncEngine.new({
  storage = storage,
  transport = transport,
  device_id = "my-laptop"
})

transport:connect()
engine:start_sync()
```

### Example 3: Custom Conflict Resolution

```lua
local engine = SyncEngine.new({
  storage = storage,
  transport = transport,
  device_id = "device-123",
  on_conflict = function(conflict)
    -- Always prefer local changes for title
    -- Always prefer remote changes for author
    -- Merge passages
    
    local resolved = {
      title = conflict.local_version.title,
      author = conflict.remote_version.author,
      passages = {}
    }
    
    -- Merge passages by ID
    local passage_map = {}
    
    for _, p in ipairs(conflict.local_version.passages or {}) do
      passage_map[p.id] = p
    end
    
    for _, p in ipairs(conflict.remote_version.passages or {}) do
      if passage_map[p.id] then
        -- Keep local if exists
      else
        -- Add remote if new
        passage_map[p.id] = p
      end
    end
    
    for _, p in pairs(passage_map) do
      table.insert(resolved.passages, p)
    end
    
    return resolved
  end
})
```

---

## Troubleshooting

### Common Issues

#### Sync Fails with "Connection Refused"

**Cause:** Cannot connect to sync server.

**Solution:**
1. Verify server URL is correct
2. Check network connectivity
3. Verify server is running
4. Check firewall settings

#### "Authentication Failed" Error

**Cause:** Invalid API key.

**Solution:**
1. Verify API key is correct
2. Check if API key has expired
3. Regenerate API key if needed

#### Sync Never Completes

**Cause:** Network timeout or server issue.

**Solution:**
1. Increase timeout: `transport = HTTPTransport.new({timeout = 60000})`
2. Check server logs
3. Verify no large files blocking sync

#### Conflicts Keep Occurring

**Cause:** Multiple devices editing same story simultaneously.

**Solution:**
1. Use `auto_merge` strategy instead of `last_write_wins`
2. Implement custom conflict resolver
3. Coordinate edits across devices

#### "Pending Operations Not Syncing"

**Cause:** Operations queued but not being sent.

**Solution:**
1. Force sync: `engine:sync_now()`
2. Check sync status: `whisker sync status`
3. Clear and re-sync: `whisker sync reset`

### Debugging

Enable verbose logging:

```lua
local engine = SyncEngine.new({
  storage = storage,
  transport = transport,
  device_id = "device-123"
})

engine:on("sync_progress", function(data)
  print(string.format("[DEBUG] Syncing %d/%d: %s",
    data.current, data.total, data.operation.type))
end)

engine:on("conflict_detected", function(data)
  print("[DEBUG] Conflict:", data.conflict)
end)

engine:on("sync_failed", function(data)
  print("[ERROR]", data.error)
end)
```

### Performance Tuning

#### Reduce Sync Frequency

```lua
sync_interval = 300000  -- 5 minutes instead of 1 minute
```

#### Batch Operations

```lua
-- Queue multiple changes
state_mgr:queue_operations_batch(operations)

-- Sync once
engine:sync_now()
```

#### Use WebSocket for Real-Time

WebSocket provides instant updates without polling:

```lua
local transport = WebSocketTransport.new({
  ws_url = "wss://sync.example.com/ws",
  api_key = "YOUR_API_KEY"
})
```

---

## FAQ

**Q: Can I sync across different platforms (Lua and JavaScript)?**

A: Yes! The sync protocol is platform-agnostic. A TypeScript/JavaScript implementation can sync with the Lua implementation as long as they follow the same protocol.

**Q: What happens if I'm offline?**

A: Operations are queued locally and synced when connection is restored.

**Q: How do I reset everything?**

A: Use `whisker sync reset` to clear all sync state (preserves device ID).

**Q: Can I sync between more than 2 devices?**

A: Yes! The sync system supports unlimited devices. All devices sync through a central server.

**Q: How much bandwidth does sync use?**

A: Sync uses delta operations, sending only changed data. Use `whisker sync stats` to monitor bandwidth usage.

**Q: Is my data encrypted?**

A: Transport encryption (HTTPS/WSS) is supported. Data is transmitted over secure connections.

**Q: What if my device ID changes?**

A: The device ID is persisted in sync state. If lost, a new ID is generated and the device appears as new.

**Q: Can I sync only specific stories?**

A: Currently, sync applies to all stories in storage. Selective sync is a planned feature.

---

## Additional Resources

- [Phase 7 Implementation Plan](../PHASE7_IMPLEMENTATION_PLAN.md)
- [Storage API Documentation](STORAGE_API.md)
- [Collaboration Features](COLLABORATION.md)

---

**Last Updated:** January 11, 2026  
**Version:** 1.0.0
