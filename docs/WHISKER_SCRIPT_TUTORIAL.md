# Whisker Script Tutorial

**Version:** 1.0

Welcome to Whisker Script! This tutorial will teach you how to write interactive fiction using Whisker Script's simple, author-friendly syntax.

## Table of Contents

1. [Introduction](#introduction)
2. [Your First Story](#your-first-story)
3. [Passages](#passages)
4. [Choices](#choices)
5. [Variables](#variables)
6. [Conditionals](#conditionals)
7. [Conditional Choices](#conditional-choices)
8. [Expressions](#expressions)
9. [Comments](#comments)
10. [Embedded Lua](#embedded-lua)
11. [Best Practices](#best-practices)
12. [Common Patterns](#common-patterns)
13. [Error Messages](#error-messages)
14. [Quick Reference](#quick-reference)

## Introduction

Whisker Script is a simple language for writing interactive fiction. If you can write prose, you can write Whisker Script.

**Key Features:**

- **Simple syntax:** Focus on your story, not code
- **Variables:** Track player choices and game state
- **Conditions:** Show content based on what happened before
- **Choices:** Let readers make decisions

## Your First Story

Create a file called `first-story.ws`:

```whisker
:: Start
You wake up in a mysterious room. The door is locked.

+ [Look around] -> Examine
+ [Try the door] -> Door

:: Examine
You find a key under the bed!

$has_key = true

+ [Return to the room] -> Start

:: Door
{ $has_key }
You unlock the door and escape. Congratulations!
{ / }

{ !$has_key }
The door is locked. You need a key.
+ [Go back] -> Start
{ / }
```

**Compile it:**

```bash
whiskerc compile first-story.ws -o first-story.lua
```

This creates a Lua file that can run with whisker-core.

## Passages

Passages are sections of your story. They start with `::` and a name:

```whisker
:: PassageName
Content goes here.
Multiple lines are fine.

This is still part of the same passage.

:: AnotherPassage
This is a different passage.
```

### Passage Names

- Start with a letter or underscore
- Can contain letters, numbers, and underscores
- Are case-sensitive (`Start` and `start` are different)

**Good names:**
```whisker
:: Start
:: CaveEntrance
:: boss_fight_2
:: _hidden_ending
```

**Bad names (will cause errors):**
```whisker
:: 123Start        // Can't start with number
:: My Passage      // No spaces allowed
:: hello-world     // No hyphens
```

## Choices

Choices let readers make decisions. They use `+ [text] -> target`:

```whisker
:: Crossroads
You stand at a crossroads.

+ [Go north] -> NorthPath
+ [Go south] -> SouthPath
+ [Go east] -> EastPath
+ [Rest here] -> Rest
```

### Choice Syntax

```
+ [choice text] -> TargetPassage
```

- `+` marks the start of a choice
- `[text]` is what the reader sees
- `->` points to where the choice leads
- `TargetPassage` is the destination passage name

### Variable Interpolation in Choices

You can include variables in choice text:

```whisker
+ [Buy sword ($gold gold)] -> BuySword
+ [You have $health HP - Rest] -> Rest
```

## Variables

Variables store information about your story's state.

### Creating Variables

Use `$name = value` to create or set a variable:

```whisker
$gold = 100
$player_name = "Alice"
$has_sword = true
$health = 100.5
```

**Variable types:**

- **Numbers:** `$gold = 100`, `$price = 19.99`
- **Strings:** `$name = "Alice"`, `$title = "King"`
- **Booleans:** `$has_key = true`, `$door_locked = false`

### Modifying Variables

```whisker
$gold += 50        // Add to variable
$health -= 10      // Subtract from variable
$visits += 1       // Increment counter
```

### Using Variables in Text

Variables automatically expand in passage content:

```whisker
:: Status
You have $gold gold coins.
Your health is $health.
Welcome, $player_name!
```

## Conditionals

Show content only when conditions are true.

### Basic Syntax

```whisker
{ condition }
Content shown when condition is true.
{ / }
```

### Examples

```whisker
:: TreasureRoom
You enter the treasure room.

{ $has_key }
You use your key to open the chest!
$gold += 100
{ / }

{ !$has_key }
The chest is locked. You need a key.
{ / }

+ [Leave] -> Exit
```

### Nested Conditionals

You can nest conditionals:

```whisker
{ $has_sword }
  You have a weapon.
  { $level >= 5 }
    You're strong enough to fight!
  { / }
  { $level < 5 }
    But you need more training.
  { / }
{ / }
```

## Conditional Choices

Show choices only when conditions are met:

```whisker
:: Shop
Welcome to my shop!

+ { $gold >= 50 } [Buy sword ($50)] -> BuySword
+ { $gold >= 20 } [Buy potion ($20)] -> BuyPotion
+ { $has_coupon } [Use coupon] -> UseCoupon
+ [Leave] -> Village
```

Readers only see choices whose conditions are true.

## Expressions

Conditions can use various operators.

### Comparison Operators

| Operator | Meaning |
|----------|---------|
| `==` | Equal to |
| `!=` | Not equal to |
| `<` | Less than |
| `>` | Greater than |
| `<=` | Less than or equal |
| `>=` | Greater than or equal |

```whisker
{ $gold == 100 }       // Exactly 100 gold
{ $name != "Alice" }   // Name is not Alice
{ $level < 5 }         // Level is below 5
{ $health > 0 }        // Still alive
{ $age <= 18 }         // 18 or younger
{ $score >= 1000 }     // 1000 or more points
```

### Logical Operators

| Operator | Meaning |
|----------|---------|
| `&&` | AND (both must be true) |
| `\|\|` | OR (either can be true) |
| `!` | NOT (reverses true/false) |

```whisker
// AND: both conditions must be true
{ $has_sword && $level >= 5 }
You're ready to fight the dragon!
{ / }

// OR: either condition can be true
{ $has_key || $has_lockpick }
You can open the door.
{ / }

// NOT: condition must be false
{ !$visited_cave }
You've never been to the cave before.
{ / }
```

### Combining Operators

```whisker
{ ($gold >= 100 || $has_coupon) && !$already_bought }
You can afford this item!
{ / }
```

Use parentheses to control order of evaluation.

### Truthy Values

Variables can be used directly as conditions:

```whisker
{ $has_key }        // True if has_key is true or a truthy value
{ !$has_key }       // True if has_key is false, nil, or 0
```

## Comments

Add notes to yourself that don't appear in the story.

### Line Comments

```whisker
// This is a comment
$gold = 100  // Initialize starting gold
```

### Block Comments

```whisker
/* This is a
   multi-line comment
   that spans several lines */

/* Temporarily disable this section
:: OldPassage
This content won't be compiled.
*/
```

## Embedded Lua

For complex logic, you can embed Lua code.

### Inline Lua

```whisker
$random_gold = {{ math.random(10, 100) }}
$current_time = {{ os.time() }}
```

### Block Lua

```whisker
{{
  -- Complex logic here
  local bonus = 0
  if whisker.state:get("vip_member") then
    bonus = 50
  end
  whisker.state:set("gold", whisker.state:get("gold") + bonus)
}}
```

**Note:** Use embedded Lua sparingly. Most stories don't need it.

## Best Practices

### 1. Use Descriptive Passage Names

**Good:**
```whisker
:: CaveEntrance
:: ThroneRoom
:: FinalBattle
```

**Bad:**
```whisker
:: p1
:: scene2
:: x
```

### 2. Initialize Variables Early

Set starting values in your first passage:

```whisker
:: Start
// Initialize game state
$gold = 100
$health = 100
$level = 1
$has_sword = false

Welcome to the adventure!

+ [Begin] -> Village
```

### 3. Use Meaningful Variable Names

**Good:**
```whisker
$player_health
$quest_completed
$times_visited_shop
```

**Bad:**
```whisker
$h
$q
$t
```

### 4. Keep Passages Focused

Each passage should be a single scene or moment:

**Good:**
```whisker
:: MeetMerchant
The merchant greets you warmly.
"Welcome to my shop!"

+ [Browse wares] -> ShopInventory
+ [Ask about rumors] -> MerchantRumors
+ [Leave] -> Village
```

**Bad:**
```whisker
:: Everything
You meet the merchant, browse his wares, buy a sword,
hear about rumors, fight a dragon, save the princess...
```

### 5. Test Your Story

Use the check command to find errors:

```bash
whiskerc check story.ws
```

## Common Patterns

### Inventory System

```whisker
:: FindSword
You discover a rusty sword!

$has_sword = true

+ [Take it] -> Continue

:: Battle
{ $has_sword }
You fight with your sword and win!
{ / }

{ !$has_sword }
You have no weapon. You flee!
{ / }
```

### Visit Counting

```whisker
:: Town
{ $town_visits == 0 }
You arrive at the town for the first time.
{ / }

{ $town_visits > 0 && $town_visits < 5 }
You return to the familiar town.
{ / }

{ $town_visits >= 5 }
The townspeople recognize you now.
{ / }

$town_visits += 1

+ [Visit shop] -> Shop
+ [Leave] -> Wilderness
```

### Stat Tracking

```whisker
:: GainExperience
You defeated the monster!

$exp += 50
$kills += 1

{ $exp >= 100 }
$level += 1
$exp = 0
Level up! You are now level $level!
{ / }

+ [Continue] -> NextArea
```

### Branching Paths

```whisker
:: AllianceChoice
You must choose an alliance.

+ [Join the Warriors] -> JoinWarriors
+ [Join the Mages] -> JoinMages
+ [Remain neutral] -> StayNeutral

:: JoinWarriors
$alliance = "warriors"
The warriors welcome you as one of their own.
+ [Continue] -> NextChapter

:: JoinMages
$alliance = "mages"
The mages accept you into their order.
+ [Continue] -> NextChapter

:: Crossroads
{ $alliance == "warriors" }
The warriors salute you.
{ / }

{ $alliance == "mages" }
The mages bow respectfully.
{ / }

{ !$alliance }
No one recognizes you here.
{ / }
```

### Shop System

```whisker
:: Shop
Welcome to the shop! You have $gold gold.

+ { $gold >= 100 } [Buy Iron Sword (100g)] -> BuyIronSword
+ { $gold >= 50 } [Buy Leather Armor (50g)] -> BuyLeatherArmor
+ { $gold >= 25 } [Buy Health Potion (25g)] -> BuyPotion
+ [Leave] -> Village

:: BuyIronSword
$gold -= 100
$has_iron_sword = true
You bought an Iron Sword!
+ [Continue shopping] -> Shop

:: BuyPotion
$gold -= 25
$potions += 1
You bought a Health Potion! You now have $potions potions.
+ [Continue shopping] -> Shop
```

## Error Messages

Whisker Script provides helpful error messages.

### Common Errors

**Missing arrow:**
```
error: story.ws:5:3: expected -> after choice text
  |
5 | + [Go north] North
  |             ^
  |
help: choices need an arrow -> followed by target passage name
```

**Unclosed conditional:**
```
error: story.ws:10:1: expected { / } to close conditional
  |
10 | :: NextPassage
   | ^
   |
help: conditional blocks need to be closed with { / }
```

**Unknown passage:**
```
error: story.ws:3:20: unknown passage: Nroth
  |
3 | + [Go north] -> Nroth
  |                 ^^^^^
  |
help: check that the passage 'Nroth' is defined (did you mean 'North'?)
```

### Checking for Errors

```bash
# Check syntax without compiling
whiskerc check story.ws

# See verbose output during compilation
whiskerc compile story.ws -o story.lua --verbose
```

## Quick Reference

```whisker
// PASSAGES
:: PassageName
Content here.

// CHOICES
+ [Text] -> Target
+ { condition } [Text] -> Target

// VARIABLES
$var = value        // Set
$var += value       // Add
$var -= value       // Subtract

// CONDITIONALS
{ condition }
  Content when true.
{ / }

// COMPARISON
==   equal
!=   not equal
<    less than
>    greater than
<=   less or equal
>=   greater or equal

// LOGICAL
&&   and
||   or
!    not

// COMMENTS
// Single line comment
/* Multi-line
   comment */

// EMBEDDED LUA
{{ lua_expression }}
{{
  lua_block
}}
```

---

## Next Steps

- Read the [Syntax Reference](WHISKER_GRAMMAR.ebnf)
- Explore the [Language Design](LANGUAGE_DESIGN.md)
- Check out example stories in `examples/`

Happy writing!
