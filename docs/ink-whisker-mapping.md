# Ink to whisker-core Mapping Reference

Detailed mapping between Ink concepts and whisker-core structures.

---

## Structural Mappings

| Ink Concept | whisker-core Component | Mapping Strategy |
|-------------|------------------------|------------------|
| Story | Story | Wrap InkStory, extract metadata from global tags |
| Knot | Passage | Each knot → Passage with `type: "knot"` |
| Stitch | Passage | Each stitch → Passage with `parent` reference to knot |
| Choice (*) | Choice | `{ once: true, sticky: false }` |
| Choice (+) | Choice | `{ once: false, sticky: true }` |
| Divert (->) | Link/target | Target passage reference in Choice |
| Gather | Passage | Junction passage for converging paths |
| Tunnel (->->) | Passage + metadata | Special passage type with return tracking |
| Thread (<-) | GatheredContent | Parallel evaluation aggregation |

---

## Path Mapping

Ink uses dot-notation paths. These map to whisker passage IDs:

| Ink Path | whisker Passage ID | Notes |
|----------|-------------------|-------|
| `knot_name` | `"knot_name"` | Simple knot |
| `knot.stitch` | `"knot.stitch"` | Stitch within knot |
| `knot.stitch.gather` | Internal | Handled by engine |
| `-> DONE` | Special | End current section |
| `-> END` | Special | End story entirely |

---

## Variable Mappings

| Ink Type | whisker Type | Conversion |
|----------|--------------|------------|
| `VAR x = 5` | Variable (number) | Direct mapping |
| `VAR s = "text"` | Variable (string) | Direct mapping |
| `VAR b = true` | Variable (boolean) | Direct mapping |
| `VAR f = 3.14` | Variable (number) | Float preserved |
| `temp x = 1` | Scoped variable | Lifecycle managed by engine |
| `LIST` | Variable (table) | Special list handling |

---

## Choice Type Preservation

| Ink Syntax | whisker Choice Properties |
|------------|--------------------------|
| `* choice text` | `{ once: true, sticky: false }` |
| `+ sticky choice` | `{ once: false, sticky: true }` |
| `* {condition} text` | `{ once: true, condition: {...} }` |
| `+ {condition} text` | `{ sticky: true, condition: {...} }` |
| `* -> fallback` | `{ fallback: true, auto: true }` |

---

## Operator Mappings

| Ink Operator | whisker Condition Operator |
|--------------|---------------------------|
| `==` | `"=="` |
| `!=` | `"!="` |
| `<` | `"<"` |
| `>` | `">"` |
| `<=` | `"<="` |
| `>=` | `">="` |
| `&&` / `and` | `"and"` |
| `||` / `or` | `"or"` |
| `!` / `not` | `"not"` |
| `+`, `-`, `*`, `/`, `%` | Evaluated at runtime |

---

## Tag Mappings

| Ink Tag | whisker Metadata |
|---------|-----------------|
| `# speaker: name` | `passage.metadata.speaker` |
| `# mood: happy` | `passage.metadata.mood` |
| `# audio: sound.mp3` | `passage.metadata.audio` |
| Global `# title: Name` | `story.title` |
| Global `# author: Name` | `story.author` |

---

## Control Flow Mappings

| Ink Control | whisker Equivalent |
|-------------|-------------------|
| `-> knot` | Navigation to passage |
| `-> knot.stitch` | Navigation to nested passage |
| `->->` (tunnel call) | Push to history, navigate |
| `->->` (tunnel return) | Pop from history, return |
| `<- knot` (thread) | Gather content from passage |
| `{ condition: }` | Conditional passage content |
| `{ - else: }` | Else branch handling |

---

## State Mappings

| tinta State | whisker IState |
|-------------|---------------|
| `variablesState[name]` | `state:get(name)` |
| `SetGlobal(name, val)` | `state:set(name, val)` |
| `GlobalVariableExistsWithName(name)` | `state:has(name)` |
| `state:save()` | `state:snapshot()` |
| `state:load(data)` | `state:restore(snapshot)` |

---

## Event Mappings

| tinta Callback | whisker Event |
|----------------|--------------|
| After `Continue()` | `ink.story.continued` |
| After `ChooseChoiceIndex()` | `ink.choice.made` |
| `ObserveVariable` callback | `ink.variable.changed` |
| External function call | `ink.external.called` |
| Story loaded | `ink.story.loaded` |

---

## Content Mappings

| Ink Content | whisker Representation |
|-------------|----------------------|
| Plain text | `passage.content` (string) |
| `{variable}` | Template substitution |
| `<>` (glue) | Whitespace control flag |
| `[]` (choice-only text) | `choice.text` vs `choice.content` |
| `//` (comment) | Not preserved |
| `/* */` (comment) | Not preserved |

---

## Sequence Mappings

| Ink Sequence | whisker Handling |
|--------------|-----------------|
| `{~a|b|c}` | Shuffle - random selection |
| `{&a|b|c}` | Cycle - round-robin |
| `{!a|b|c}` | Once - each once then empty |
| `{a|b|c}` | Stopping - use last after exhausted |

---

## API Method Mappings

| tinta Method | whisker-core Method |
|--------------|-------------------|
| `Story(def)` | `InkFormat:import(json)` |
| `story:Continue()` | `engine:continue()` (internal) |
| `story:canContinue()` | `engine:can_continue()` |
| `story:currentChoices()` | `engine:get_available_choices()` |
| `story:ChooseChoiceIndex(i)` | `engine:make_choice(i)` |
| `story:currentText()` | `engine:get_current_text()` |
| `story:currentTags()` | `engine:get_current_tags()` |
| `story:BindExternalFunction()` | `engine:bind_function()` |
| `story:ObserveVariable()` | Event subscription |

---

## Limitations and Notes

### Full Support
- Basic narrative flow (knots, stitches, choices)
- Variables (global and temporary)
- Conditionals and logic
- Tags and metadata
- Save/load state
- External functions
- Variable observers
- Multiple flows

### Partial Support
- Threads: Basic gathering supported, complex patterns may need runtime
- Lists: Basic support, advanced list operations limited

### Not Preserved in Conversion
- Comments (removed during Ink compilation)
- Source formatting
- Original Ink syntax (only JSON available)
