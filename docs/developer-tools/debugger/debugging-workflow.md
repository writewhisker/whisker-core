# Debugging Workflow

whisker-debug implements the Debug Adapter Protocol (DAP) for stepping through interactive fiction stories.

## Overview

The debugger allows you to:

- Set breakpoints on passages, choices, and diverts
- Step through story execution line by line
- Inspect variable state at any point
- View the navigation call stack
- Evaluate expressions during debugging

## Setup

### Prerequisites

1. Install whisker-debug:
   ```bash
   luarocks install whisker-debug
   ```

2. Verify installation:
   ```bash
   whisker-debug --version
   ```

### VSCode Configuration

Create `.vscode/launch.json`:

```json
{
  "version": "0.2.0",
  "configurations": [
    {
      "type": "whisker",
      "request": "launch",
      "name": "Debug Story",
      "program": "${file}"
    },
    {
      "type": "whisker",
      "request": "launch",
      "name": "Debug Story (Stop on Entry)",
      "program": "${file}",
      "stopOnEntry": true
    }
  ]
}
```

### Neovim Configuration (nvim-dap)

```lua
local dap = require('dap')

dap.adapters.whisker = {
  type = 'executable',
  command = 'whisker-debug',
  args = { '--stdio' }
}

dap.configurations.ink = {
  {
    type = 'whisker',
    request = 'launch',
    name = 'Debug Story',
    program = '${file}'
  }
}

-- Also for wscript and twee
dap.configurations.wscript = dap.configurations.ink
dap.configurations.twee = dap.configurations.ink
```

## Setting Breakpoints

### Line Breakpoints

Click the gutter (left margin) to toggle breakpoints on:

| Line Type | Example |
|-----------|---------|
| Passage header | `=== Combat ===` |
| Choice line | `* [Attack] -> Attack` |
| Divert line | `-> Chapter1` |
| Variable assignment | `~ health = 100` |

### Conditional Breakpoints

Stop only when a condition is true:

1. Right-click an existing breakpoint
2. Select "Edit Breakpoint"
3. Enter condition: `player_health < 10`

Example conditions:
- `player_health < 10`
- `visited_count > 3`
- `has_key == true`

### Hit Count Breakpoints

Stop after the line is hit N times:

1. Right-click breakpoint
2. Select "Edit Breakpoint"
3. Enter hit count: `5`

Useful for loops or frequently-visited passages.

## Debug Controls

### Toolbar Actions

| Button | Shortcut | Action |
|--------|----------|--------|
| Continue | `F5` | Run until next breakpoint |
| Step Over | `F10` | Execute current line |
| Step Into | `F11` | Follow divert into passage |
| Step Out | `Shift+F11` | Return to calling passage |
| Restart | `Ctrl+Shift+F5` | Restart from beginning |
| Stop | `Shift+F5` | End debug session |

### Stepping Behavior

**Step Over (`F10`)**:
- Executes the current line
- On a choice, moves to next line in same passage
- On a divert, moves to the target but doesn't pause inside

**Step Into (`F11`)**:
- On a divert `-> Target`, pauses at Target's first line
- On a choice, follows the choice and pauses at target

**Step Out (`Shift+F11`)**:
- Runs until returning to the calling passage
- Useful when stepping into a sub-passage

## Inspecting State

### Variables Pane

When paused, the Variables pane shows:

```
▼ Globals
    player_health: 100
    player_name: "Hero"
    has_sword: true
    gold: 50
▼ Locals
    choice_text: "Attack the dragon"
    damage: 25
```

**Scopes**:
- **Globals**: Persistent story variables
- **Locals**: Current passage/choice variables

### Watch Expressions

Add custom expressions to monitor:

1. Click "+" in Watch pane
2. Enter expression: `player_health - damage`
3. Value updates as you step

Example watch expressions:
- `player_health`
- `player_health / max_health`
- `inventory.length`

### Hover Inspection

Hover over any variable in the editor while paused to see its value.

## Call Stack

The Call Stack pane shows passage navigation:

```
PlayerWins (line 45) ← current
  ← Combat (line 23)
    ← Chapter1 (line 12)
      ← Start (line 1)
```

Click any frame to:
- View that passage in the editor
- See variables at that point
- Understand how you arrived here

## Debug Console

Execute expressions while paused:

```
> player_health
100

> player_health + 50
150

> visited("Combat")
true

> turns_remaining
3
```

The console supports:
- Variable reads
- Arithmetic expressions
- Function calls
- Comparisons

## Example Debug Session

### Scenario: Finding a Logic Bug

Your story has a bug where the player can attack with negative health.

1. **Set breakpoint** on line with `=== Combat ===`

2. **Start debugging** (`F5`)

3. **Play through** to reach Combat passage

4. **Execution pauses** at Combat breakpoint

5. **Check variables**:
   ```
   player_health: -5
   enemy_health: 100
   ```

6. **Found the bug!** Health should be checked before combat

7. **Step through** to see the flow:
   - `F10` to step over each line
   - Watch how health changes

8. **Fix the code** and verify by debugging again

### Scenario: Understanding Story Flow

Want to see all passages visited in a playthrough:

1. **Set breakpoints** on all passage headers

2. **Start with `stopOnEntry: true`**

3. **Press `F5`** to continue to each passage

4. **Watch the Call Stack** build up

5. **Export the flow** for documentation

## Best Practices

### Effective Breakpoint Placement

- **Critical decision points**: Where player choices matter
- **State changes**: Where important variables change
- **Problem areas**: Where bugs might occur
- **Loop entries**: To catch infinite loops

### Debugging Strategies

1. **Start broad**: Set breakpoints at key passages
2. **Narrow down**: Add more breakpoints near the problem
3. **Use conditions**: Don't stop every time, just when relevant
4. **Check the stack**: Understand how you got here

### Performance Tips

- Remove breakpoints when not needed
- Use conditional breakpoints for frequently-hit lines
- Consider `stopOnEntry: false` for faster startup

## Troubleshooting

### Breakpoints Not Hit

1. Verify breakpoint is on a valid line (not blank or comment)
2. Check that the passage is actually visited
3. Ensure whisker-debug is correctly configured

### Variables Not Showing

1. Make sure execution is paused (not running)
2. Expand the Globals/Locals nodes
3. Check Debug Console for errors

### Debugger Won't Start

1. Verify whisker-debug path:
   ```bash
   which whisker-debug
   ```

2. Check extension settings:
   ```json
   {
     "whisker.debug.adapterPath": "whisker-debug"
   }
   ```

3. View Debug Console for error messages

See [Troubleshooting Guide](../troubleshooting.md) for more solutions.
