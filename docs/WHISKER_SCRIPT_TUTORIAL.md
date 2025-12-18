# Whisker Script Tutorial

Welcome to Whisker Script! This tutorial will guide you through creating interactive fiction stories from the basics to advanced techniques.

## Table of Contents

1. [Your First Story](#1-your-first-story)
2. [Adding Choices](#2-adding-choices)
3. [Using Variables](#3-using-variables)
4. [Conditional Content](#4-conditional-content)
5. [Inline Expressions](#5-inline-expressions)
6. [Organizing Larger Stories](#6-organizing-larger-stories)
7. [Advanced Patterns](#7-advanced-patterns)
8. [Tips and Best Practices](#8-tips-and-best-practices)

---

## 1. Your First Story

Let's create the simplest possible interactive fiction story.

### Creating a Passage

Every story is made of **passages**. A passage starts with `::` followed by its name:

```whisker
:: Start
Welcome to my first story!
```

That's it! You've created a passage called "Start" with one line of text.

### Adding More Content

Text in a passage is displayed to the reader:

```whisker
:: Start
Welcome to my first story!

This is a simple adventure about exploring a mysterious house.

You stand before an old Victorian mansion.
```

Blank lines create paragraph breaks.

### Multiple Passages

Most stories have multiple passages:

```whisker
:: Start
You stand before an old Victorian mansion.
The door is slightly ajar.

:: Inside
You step inside. Dust motes dance in pale light.

:: Garden
The overgrown garden is full of wild roses.
```

### Connecting Passages with Diverts

Use `->` to navigate between passages:

```whisker
:: Start
You stand before an old Victorian mansion.
-> Inside

:: Inside
You step inside. Dust motes dance in pale light.
```

This automatically moves the reader from "Start" to "Inside".

### Adding Metadata

Add information about your story at the top:

```whisker
@@ title: The Old Mansion
@@ author: Your Name

:: Start
Welcome to The Old Mansion!
```

### Complete First Story

```whisker
@@ title: Hello World
@@ author: Tutorial

:: Start
Welcome to your first Whisker Script story!

This demonstrates the absolute basics.

-> End

:: End
Thank you for reading!

The End.
```

---

## 2. Adding Choices

Choices make stories interactive!

### Basic Choices

Use `+` to create a choice:

```whisker
:: Start
You're at a crossroads.

+ [Go north] -> NorthPath
+ [Go south] -> SouthPath

:: NorthPath
You travel north into the mountains.

:: SouthPath
You journey south toward the sea.
```

### Choice Syntax

```
+ [Text the reader sees] -> TargetPassage
```

- `+` marks this as a choice
- `[brackets]` contain the choice text
- `->` points to where the choice leads

### Multiple Choices

You can have as many choices as you want:

```whisker
:: Tavern
The tavern is busy tonight. What do you do?

+ [Talk to the bartender] -> Bartender
+ [Sit by the fire] -> Fireplace
+ [Challenge someone to cards] -> CardGame
+ [Leave] -> Street
```

### Choices with Inline Content

Choices can have content before the divert:

```whisker
:: Forest
You find a fork in the path.

+ [Take the left path]
  The left path winds through thick brambles.
  After some struggle, you emerge in a clearing.
  -> Clearing

+ [Take the right path]
  The right path follows a bubbling stream.
  The sound of water is soothing.
  -> Riverside
```

### One-Time Choices

Use `*` instead of `+` for choices that disappear after being chosen:

```whisker
:: TreasureRoom
The room glitters with gold!

* [Take the ruby necklace]
  You pocket the beautiful necklace.
  -> TreasureRoom

* [Take the gold coins]
  You fill your pockets with coins.
  -> TreasureRoom

+ [Leave the room] -> Hallway
```

After taking the necklace, that choice won't appear again.

---

## 3. Using Variables

Variables store information that changes during the story.

### Creating Variables

Use `~` to create and modify variables:

```whisker
:: Start
~ $gold = 100
~ $player_name = "Hero"
~ $has_sword = false

You begin your adventure!
```

### Variable Rules

- Variables start with `$`
- Names use letters, numbers, and underscores
- Values can be numbers, strings, booleans, or lists

### Displaying Variables

Use `{$variable}` to show a variable's value:

```whisker
:: Shop
You have {$gold} gold coins.

+ [Buy sword (50 gold)] -> BuySword
+ [Leave] -> Town
```

### Modifying Variables

```whisker
:: BuySword
~ $gold -= 50
~ $has_sword = true

You bought a sword! You now have {$gold} gold.
-> Town
```

### Compound Operators

```whisker
~ $gold += 50   # Add 50
~ $gold -= 10   # Subtract 10
~ $score *= 2   # Double the score
~ $shares /= 2  # Halve the shares
```

### Lists

Variables can hold lists:

```whisker
~ $inventory = []           # Empty list
~ $inventory[] = "sword"    # Add item
~ $inventory[] = "shield"   # Add another

You have {count($inventory)} items.
```

---

## 4. Conditional Content

Show different content based on conditions.

### If/Else Blocks

```whisker
:: Shop
{ $gold >= 50:
    The shopkeeper smiles. "What can I get you?"
- else:
    The shopkeeper frowns. "Come back when you have money."
}
```

### Multiple Branches

```whisker
:: CheckHealth
{ $health > 75:
    You feel strong and healthy!
- $health > 50:
    You're doing okay, but could use some rest.
- $health > 25:
    You're wounded and weak.
- else:
    You're barely alive...
}
```

### Conditional Choices

Only show choices when conditions are met:

```whisker
:: LockedDoor
A heavy wooden door blocks your path.

+ { $has_key } [Unlock the door] -> SecretRoom
+ [Try to force it open] -> ForceDoor
+ [Go back] -> Hallway
```

If the player doesn't have the key, they won't see that option.

### Combining Conditions

Use `and`, `or`, and `not`:

```whisker
{ $has_sword and $strength > 10:
    You're ready for battle!
}

{ $gold < 10 or $is_homeless:
    The innkeeper takes pity on you.
}

{ not $has_visited_castle:
    "You should visit the castle," says the guard.
}
```

---

## 5. Inline Expressions

Embed dynamic content directly in text.

### Variable Interpolation

```whisker
Hello, {$player_name}! You have {$gold} gold.
```

### Math in Text

```whisker
Two plus two equals {2 + 2}.
Half of your gold is {$gold / 2}.
```

### Inline Conditionals

Show one thing or another based on a condition:

```whisker
You feel { $health > 50: strong | weak }.

The door is { $locked: locked | unlocked }.
```

Format: `{ condition: if_true | if_false }`

### Function Calls

```whisker
Random number: {random(1, 10)}
You have {count($inventory)} items.
Your name in caps: {upper($player_name)}
```

### Complex Expressions

```whisker
{ $damage > 0:
    You take {$damage} damage and have {$health - $damage} health remaining.
}
```

---

## 6. Organizing Larger Stories

### Comments

Use `#` for comments that aren't shown to readers:

```whisker
:: Start
# This is the introduction
Welcome to the adventure!

~ $gold = 100  # Starting gold
```

### Passage Tags

Tag passages for organization:

```whisker
:: BossFight [combat, chapter3, important]
The dragon roars!

:: ShopScene [shop, optional]
Welcome to my humble shop.
```

### Tunnels (Subroutines)

Tunnels let you reuse content and return to where you were:

```whisker
:: Forest
You walk through the forest.

->-> DescribeWeather

After some time, you reach a clearing.

:: DescribeWeather
# This is a tunnel - it returns to the caller

{ $weather == "sunny":
    The sun shines through the leaves.
- $weather == "rainy":
    Rain drips from the branches above.
- else:
    The sky is overcast.
}

->->
```

The `->->` at the end returns to wherever the tunnel was called from.

### Include Files

Split large stories into multiple files:

```whisker
# main.wsk
@@ title: Epic Adventure

>> include "chapter1.wsk"
>> include "chapter2.wsk"

:: Start
Your journey begins...
-> Chapter1Start
```

---

## 7. Advanced Patterns

### State Machines

Track complex state with variables:

```whisker
~ $quest_stage = 0

:: QuestGiver
{ $quest_stage == 0:
    "I need you to find my lost cat!"
    + [Accept quest]
      ~ $quest_stage = 1
      -> QuestGiver
    + [Refuse] -> Town

- $quest_stage == 1:
    "Have you found my cat yet?"
    { $has_cat:
        + [Return the cat]
          ~ $quest_stage = 2
          ~ $gold += 50
          -> QuestGiver
    }
    + [Not yet] -> Town

- $quest_stage == 2:
    "Thank you so much for finding Whiskers!"
}
```

### Inventory System

```whisker
~ $inventory = []

:: PickUp
~ $inventory[] = $found_item
You picked up the {$found_item}.

:: CheckInventory
You are carrying:
{ count($inventory) > 0:
    { has($inventory, "sword"): - A sword }
    { has($inventory, "shield"): - A shield }
    { has($inventory, "potion"): - A healing potion }
- else:
    Nothing.
}
```

### Random Events

```whisker
:: WanderForest
~ $event = random(1, 5)

{ $event == 1:
    You find a gold coin!
    ~ $gold += 1
- $event == 2:
    A wolf appears!
    -> WolfEncounter
- $event == 3:
    You discover a hidden path.
    + [Follow it] -> SecretGlade
    + [Ignore it] -> WanderForest
- else:
    The forest is peaceful.
}

+ [Keep walking] -> WanderForest
+ [Return to town] -> Town
```

### Visit Tracking

The `visited()` function tracks how many times a passage has been seen:

```whisker
:: TownSquare
{ visited("TownSquare") == 1:
    The town square is bustling with activity.
    This is your first time here.
- visited("TownSquare") < 5:
    The familiar town square greets you.
- else:
    You know every cobblestone of this square by now.
}
```

### Threads (Parallel Content)

Threads run alongside the main narrative:

```whisker
:: HauntedHouse
<- CreepyAmbience

You enter the haunted house...

:: CreepyAmbience
# This content interleaves with the main story
A cold wind blows through the halls...
The floorboards creak beneath your feet...
Something skitters in the shadows...
```

---

## 8. Tips and Best Practices

### Naming Conventions

- **Passages**: Use PascalCase (`TownSquare`, `BossFight`)
- **Variables**: Use snake_case with $ prefix (`$player_name`, `$gold_count`)
- **Tags**: Use lowercase (`[important]`, `[chapter1]`)

### Passage Organization

1. Put `Start` passage first
2. Group related passages together
3. Use comments to mark sections

```whisker
# ============================================
# Chapter 1: The Village
# ============================================

:: Village
...

:: VillageShop
...

# ============================================
# Chapter 2: The Forest
# ============================================

:: ForestEntrance
...
```

### Error Prevention

1. **Test early and often** - Play through your story regularly
2. **Use consistent naming** - Typos in passage names cause errors
3. **Initialize variables** - Set default values at the start
4. **Check conditions** - Make sure conditional choices are reachable

### Common Mistakes

```whisker
# WRONG: Missing passage name
::
Content here

# RIGHT:
:: PassageName
Content here

# WRONG: Choice without brackets
+ Go north -> North

# RIGHT:
+ [Go north] -> North

# WRONG: Undefined variable
You have {$gold} gold.  # Error if $gold not set

# RIGHT:
~ $gold = 0  # Initialize first
You have {$gold} gold.
```

### Performance Tips

- Avoid deeply nested conditionals
- Use tunnels to avoid duplicating content
- Keep passages focused on one scene or decision

---

## Next Steps

Congratulations! You now know the essentials of Whisker Script.

- **Practice**: Start with a simple story and add complexity gradually
- **Reference**: See [WHISKER_SCRIPT.md](WHISKER_SCRIPT.md) for the full specification
- **Quick Reference**: See [WHISKER_SCRIPT_REFERENCE.md](WHISKER_SCRIPT_REFERENCE.md) for syntax lookup
- **Examples**: Check the `examples/script/` directory for complete stories

Happy writing!
