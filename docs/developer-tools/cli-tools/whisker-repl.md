# whisker-repl: Interactive Playground

whisker-repl provides an interactive Read-Eval-Print Loop for testing and exploring stories.

## Installation

```bash
luarocks install whisker-repl
```

Verify installation:

```bash
whisker-repl --version
# whisker-repl 0.1.0
```

## Basic Usage

### Start REPL

```bash
whisker-repl
```

Output:
```
whisker-repl - Interactive Story Playground
Type :help for commands, :quit to exit

>
```

### Load and Play a Story

```bash
whisker-repl story.ink
```

Or load within the REPL:
```
> :load story.ink
Loaded: story.ink

=== Start ===
Welcome to the adventure!

1. Enter the cave
2. Climb the mountain

> 1

=== Cave ===
The cave is dark and mysterious...
```

## Command-Line Options

```
whisker-repl [options] [story-file]

Options:
  -h, --help       Show help message
  -v, --version    Show version
  --no-color       Disable colored output
```

## Navigation

### Making Choices

Enter the number to select a choice:

```
1. Enter the cave
2. Climb the mountain

> 1
```

### Continuing

Press Enter when there are no choices:

```
The sun sets in the west...

>
[presses Enter]

=== NextPassage ===
...
```

## REPL Commands

All commands start with `:` (colon):

| Command | Description |
|---------|-------------|
| `:help` | Show command help |
| `:load <file>` | Load a story file |
| `:reload` | Reload current story |
| `:restart` | Restart from beginning |
| `:state` | Show current state (variables) |
| `:passages` | List all passages |
| `:goto <passage>` | Jump to passage |
| `:set <var>=<val>` | Set variable value |
| `:history` | Show navigation history |
| `:save <file>` | Save current state |
| `:load-state <file>` | Load saved state |
| `:quit` | Exit REPL |

## Commands in Detail

### :load

Load a story file:

```
> :load src/story.ink
Loaded: src/story.ink
```

Supports: `.ink`, `.twee`, `.tw`, `.wscript`

### :reload

Reload the current story (preserves position):

```
> :reload
Reloaded
```

Useful after editing the file externally.

### :restart

Start the story from the beginning:

```
> :restart
Restarted

=== Start ===
Welcome back...
```

### :state

View all current variables:

```
> :state
Current state:
  player_health = 100
  player_name = "Hero"
  has_sword = true
  gold = 50
```

### :passages

List all passages in the story:

```
> :passages
Passages:
  Start *
  Cave
  Forest
  Battle
  Victory
  GameOver

(* = current)
```

### :goto

Jump directly to any passage:

```
> :goto Battle
[Story jumps to Battle passage]

=== Battle ===
The dragon awakens!
```

Useful for testing specific sections.

### :set

Modify variable values:

```
> :set player_health=200
player_health = 200

> :set has_sword=true
has_sword = true

> :set player_name="Warrior"
player_name = Warrior
```

Supports numbers, booleans, and strings.

### :history

View navigation history:

```
> :history
Navigation history:
  1. Start
  2. Cave
  3. Battle
  -> Victory (current)
```

### :save

Save current state to file:

```
> :save checkpoint.json
State saved to checkpoint.json
```

### :load-state

Restore saved state:

```
> :load-state checkpoint.json
State loaded from checkpoint.json
```

## Use Cases

### Story Testing

Quickly test story flow:

```bash
whisker-repl story.ink
> 1
> 2
> :goto Ending
> :state
```

### Variable Debugging

Test with different variable values:

```bash
whisker-repl story.ink
> :set player_health=1
> :goto Combat
# Test low-health behavior
```

### Path Exploration

Find all possible paths:

```bash
whisker-repl story.ink
> :goto Start
> 1  # First choice
> :restart
> 2  # Second choice
> :history
```

### Save Points

Create and restore checkpoints:

```bash
whisker-repl story.ink
> 1
> 2
> :save before_boss.json
> 1  # Fight boss
# If something goes wrong:
> :load-state before_boss.json
```

## Tips and Tricks

### Quick Testing Loop

```bash
# Terminal 1: Edit story
vim story.ink

# Terminal 2: Test changes
whisker-repl story.ink
> :reload  # After each edit
```

### Batch Testing

Pipe commands to REPL:

```bash
echo -e "1\n2\n3\n:state" | whisker-repl story.ink
```

### No Color Mode

For piping output:

```bash
whisker-repl --no-color story.ink > session.log
```

### State Persistence

Save state between sessions:

```bash
# End of session
> :save session.json
> :quit

# Next session
whisker-repl story.ink
> :load-state session.json
```

## Keyboard Shortcuts

| Key | Action |
|-----|--------|
| Enter | Continue/confirm |
| Ctrl+C | Cancel current action |
| Ctrl+D | Exit REPL |
| Up/Down | Command history (if readline available) |

## Output Colors

When color is enabled:

| Color | Meaning |
|-------|---------|
| Cyan | Passage headers |
| Yellow | Choice numbers |
| Green | Prompts and success |
| Red | Errors |
| Dim | Story end marker |

Disable with `--no-color`.

## Integration

### Script Testing

Create a test script:

```bash
#!/bin/bash
# test-story.sh

whisker-repl --no-color story.ink << EOF
1
2
:state
:quit
EOF

echo "Test completed"
```

### CI Testing

Basic playthrough test:

```bash
echo -e "1\n2\n3" | whisker-repl --no-color story.ink
if [ $? -eq 0 ]; then
  echo "Story playable"
fi
```

## Troubleshooting

### "Cannot open file"

Check file path is correct:
```bash
ls -la story.ink
```

### "Unknown file format"

Ensure supported extension: `.ink`, `.twee`, `.tw`, `.wscript`

### Colors Not Working

Check terminal supports ANSI colors. Use `--no-color` if issues persist.

### Command Not Recognized

Ensure command starts with `:`:
```
> help      # Wrong
> :help     # Correct
```
