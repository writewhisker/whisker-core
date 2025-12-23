// First Story - A Simple Adventure
// This example demonstrates the core features of Whisker Script

:: Start
// Initialize game state
$gold = 50
$health = 100
$has_key = false
$has_sword = false

Welcome to the Mysterious Cave!
You stand at the entrance of a dark cave.
The air is cold and damp.

+ [Enter the cave] -> CaveEntrance
+ [Look for supplies first] -> SupplySearch

:: SupplySearch
You search the area outside the cave.

{ !$found_supplies }
You find an old backpack with 25 gold pieces!
$gold += 25
$found_supplies = true
{ / }

{ $found_supplies }
You've already searched this area.
{ / }

+ [Enter the cave] -> CaveEntrance

:: CaveEntrance
You step into the cave. The darkness swallows you.

{ $has_torch }
Your torch illuminates the path ahead.
{ / }

{ !$has_torch }
It's hard to see, but you can make out two passages.
{ / }

+ [Take the left passage] -> LeftPassage
+ [Take the right passage] -> RightPassage
+ { $has_key } [Use your key on the locked door] -> TreasureRoom

:: LeftPassage
The left passage leads to a small chamber.
You find an old chest here!

{ !$opened_left_chest }
$opened_left_chest = true
$gold += 30
Inside you find 30 gold pieces!
{ / }

{ $opened_left_chest }
The chest is empty - you already took everything.
{ / }

+ [Go back] -> CaveEntrance

:: RightPassage
The right passage is narrow and winding.
You hear something up ahead...

{ $has_sword }
With your sword ready, you feel confident.
{ / }

{ !$has_sword }
You wish you had a weapon.
{ / }

+ [Continue forward] -> MonsterRoom
+ [Go back] -> CaveEntrance

:: MonsterRoom
A goblin jumps out from the shadows!

{ $has_sword }
You defeat the goblin with your sword!
$gold += 50
$has_key = true
The goblin drops a golden key!
+ [Take the key and go back] -> CaveEntrance
{ / }

{ !$has_sword }
Without a weapon, you have no choice but to flee!
$health -= 20
You take some damage while escaping. Health: $health
+ [Run back to safety] -> CaveEntrance
{ / }

:: TreasureRoom
You use the golden key on the locked door.
It swings open to reveal the treasure chamber!

Piles of gold and jewels fill the room.
$gold += 500

Congratulations! You found the treasure!
You finish with $gold gold and $health health.

+ [THE END - Play again?] -> Start

/*
   Shop passage - demonstrates the shop pattern
*/

:: Shop
// This would be accessible from CaveEntrance if we added a choice
Welcome to the Cave Shop!
You have $gold gold.

+ { $gold >= 40 && !$has_sword } [Buy Sword (40g)] -> BuySword
+ { $gold >= 20 && !$has_torch } [Buy Torch (20g)] -> BuyTorch
+ { $gold >= 30 } [Buy Health Potion (30g)] -> BuyPotion
+ [Leave shop] -> CaveEntrance

:: BuySword
$gold -= 40
$has_sword = true
You bought a sword! Now you can fight monsters.
+ [Continue shopping] -> Shop

:: BuyTorch
$gold -= 20
$has_torch = true
You bought a torch! The cave won't be so dark now.
+ [Continue shopping] -> Shop

:: BuyPotion
$gold -= 30
$health += 50
{ $health > 100 }
$health = 100
{ / }
You drink the potion. Health restored to $health!
+ [Continue shopping] -> Shop
