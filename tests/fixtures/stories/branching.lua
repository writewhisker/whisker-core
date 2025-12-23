-- Branching story fixture for testing
-- A story with multiple branches and choices

return {
  title = "Branching Story",
  author = "Test Author",
  start_passage = "start",
  passages = {
    {
      name = "start",
      text = "You are standing at a crossroads. The path ahead splits into three directions.",
      choices = {
        { text = "Take the left path", target = "left" },
        { text = "Go straight ahead", target = "center" },
        { text = "Follow the right path", target = "right" },
      }
    },
    {
      name = "left",
      text = "The left path leads you through a dark forest. After a while, you emerge into a sunny meadow.",
      choices = {
        { text = "Rest in the meadow", target = "meadow" },
        { text = "Continue walking", target = "ending_peaceful" },
      }
    },
    {
      name = "center",
      text = "The center path takes you to an ancient stone bridge over a rushing river.",
      choices = {
        { text = "Cross the bridge", target = "ending_adventure" },
        { text = "Turn back", target = "start" },
      }
    },
    {
      name = "right",
      text = "The right path winds up a hill. At the top, you can see for miles.",
      choices = {
        { text = "Enjoy the view", target = "ending_peaceful" },
        { text = "Climb down the other side", target = "ending_adventure" },
      }
    },
    {
      name = "meadow",
      text = "You lie down in the soft grass and watch the clouds drift by. It's a perfect day.",
      choices = {
        { text = "Take a nap", target = "ending_peaceful" },
        { text = "Keep exploring", target = "center" },
      }
    },
    {
      name = "ending_peaceful",
      text = "You find a quiet spot and reflect on your journey. Sometimes the best adventures are the peaceful ones.\n\nTHE END",
      choices = {},
    },
    {
      name = "ending_adventure",
      text = "Your journey continues beyond the horizon. Who knows what adventures await?\n\nTHE END",
      choices = {},
    },
  }
}
