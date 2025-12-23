// Sample WhiskerScript file

passage "Start" {
  Welcome to the WhiskerScript adventure!

  var name = "Player"
  var health = 100

  * [Enter the dungeon] -> Dungeon
  * [Visit the shop] -> Shop
}

passage "Dungeon" {
  You enter a dark dungeon.

  if health > 50 then
    You feel strong enough to continue.
  else
    You should rest first.
  endif

  -> Start
}

passage "Shop" {
  The shopkeeper greets you, {name}!

  <<buy_item "sword">>

  -> Start
}
