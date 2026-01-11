--[[
  HTML Export System
  
  Exports whisker stories to standalone HTML player.
  
  Features:
  - Self-contained single HTML file
  - No external dependencies
  - Responsive design
  - LocalStorage save/load
  - Keyboard shortcuts
  
  Usage:
    local HTMLExporter = require("whisker.export.html")
    local exporter = HTMLExporter.new()
    local html = exporter:export(story, { title = "My Story" })
]]

local HTMLExporter = {}
HTMLExporter.__index = HTMLExporter

function HTMLExporter.new(options)
  options = options or {}
  
  local self = setmetatable({
    options = options,
    template = options.template or "default"
  }, HTMLExporter)
  
  return self
end

--[[
  Export story to HTML
  
  @param story Story Story object to export
  @param options table Export options
  @return string HTML content
]]
function HTMLExporter:export(story, options)
  options = options or {}
  
  local json = require("cjson")
  local story_json = json.encode({
    metadata = story.metadata,
    passages = story.passages,
    start_passage = story.start_passage
  })
  
  local html = self:build_html(story, story_json, options)
  
  return html
end

--[[
  Build complete HTML document
]]
function HTMLExporter:build_html(story, story_json, options)
  local title = options.title or story.metadata.title or "Whisker Story"
  
  return string.format([[
<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <title>%s</title>
  <style>
    %s
  </style>
</head>
<body>
  <div id="app">
    <header>
      <h1 id="story-title">%s</h1>
      <div id="controls">
        <button onclick="saveGame()">Save</button>
        <button onclick="loadGame()">Load</button>
        <button onclick="restartStory()">Restart</button>
      </div>
    </header>
    
    <main id="passage-container">
      <div id="passage-text"></div>
      <div id="choices"></div>
    </main>
    
    <footer>
      <div id="stats"></div>
    </footer>
  </div>
  
  <script>
    const STORY_DATA = %s;
    %s
  </script>
</body>
</html>
]], title, self:get_css(), title, story_json, self:get_javascript())
end

--[[
  Get CSS styles
]]
function HTMLExporter:get_css()
  return [[
    * { margin: 0; padding: 0; box-sizing: border-box; }
    
    body {
      font-family: 'Georgia', serif;
      line-height: 1.6;
      color: #333;
      background: #f5f5f5;
      padding: 20px;
    }
    
    #app {
      max-width: 800px;
      margin: 0 auto;
      background: white;
      padding: 40px;
      box-shadow: 0 2px 10px rgba(0,0,0,0.1);
      border-radius: 8px;
    }
    
    header {
      margin-bottom: 40px;
      padding-bottom: 20px;
      border-bottom: 2px solid #eee;
    }
    
    #story-title {
      font-size: 2.5em;
      color: #2c3e50;
      margin-bottom: 15px;
    }
    
    #controls {
      display: flex;
      gap: 10px;
    }
    
    button {
      padding: 10px 20px;
      border: none;
      background: #3498db;
      color: white;
      border-radius: 4px;
      cursor: pointer;
      font-size: 14px;
      transition: background 0.3s;
    }
    
    button:hover {
      background: #2980b9;
    }
    
    #passage-text {
      font-size: 1.2em;
      margin-bottom: 30px;
      line-height: 1.8;
    }
    
    #choices {
      display: flex;
      flex-direction: column;
      gap: 15px;
    }
    
    .choice {
      padding: 15px 25px;
      background: #ecf0f1;
      border: 2px solid transparent;
      border-radius: 6px;
      cursor: pointer;
      transition: all 0.3s;
      font-size: 1.1em;
    }
    
    .choice:hover {
      background: #3498db;
      color: white;
      border-color: #2980b9;
      transform: translateX(5px);
    }
    
    footer {
      margin-top: 40px;
      padding-top: 20px;
      border-top: 2px solid #eee;
      color: #7f8c8d;
      font-size: 0.9em;
    }
    
    @media (max-width: 600px) {
      body { padding: 10px; }
      #app { padding: 20px; }
      #story-title { font-size: 1.8em; }
      #passage-text { font-size: 1em; }
    }
  ]]
end

--[[
  Get JavaScript code
]]
function HTMLExporter:get_javascript()
  return [[
    // Story state
    let currentPassage = STORY_DATA.start_passage;
    let history = [];
    let variables = {};
    
    // Initialize
    function init() {
      showPassage(currentPassage);
    }
    
    // Show passage
    function showPassage(passageId) {
      const passage = STORY_DATA.passages.find(p => p.id === passageId);
      if (!passage) {
        document.getElementById('passage-text').textContent = 'Passage not found: ' + passageId;
        return;
      }
      
      // Update current passage
      currentPassage = passageId;
      history.push(passageId);
      
      // Render passage text
      document.getElementById('passage-text').innerHTML = formatText(passage.text);
      
      // Render choices
      const choicesDiv = document.getElementById('choices');
      choicesDiv.innerHTML = '';
      
      if (passage.choices && passage.choices.length > 0) {
        passage.choices.forEach(choice => {
          const btn = document.createElement('div');
          btn.className = 'choice';
          btn.textContent = choice.text;
          btn.onclick = () => showPassage(choice.target);
          choicesDiv.appendChild(btn);
        });
      } else {
        const endMsg = document.createElement('div');
        endMsg.style.textAlign = 'center';
        endMsg.style.fontStyle = 'italic';
        endMsg.style.color = '#7f8c8d';
        endMsg.textContent = 'The End';
        choicesDiv.appendChild(endMsg);
      }
      
      // Update stats
      updateStats();
    }
    
    // Format text (basic markdown-like)
    function formatText(text) {
      return text
        .replace(/\*\*([^*]+)\*\*/g, '<strong>$1</strong>')
        .replace(/\*([^*]+)\*/g, '<em>$1</em>')
        .replace(/\n\n/g, '</p><p>')
        .replace(/^(.+)$/, '<p>$1</p>');
    }
    
    // Update stats
    function updateStats() {
      document.getElementById('stats').textContent = 
        'Passages visited: ' + history.length;
    }
    
    // Save game
    function saveGame() {
      const saveData = {
        currentPassage,
        history,
        variables,
        timestamp: new Date().toISOString()
      };
      localStorage.setItem('whisker_save', JSON.stringify(saveData));
      alert('Game saved!');
    }
    
    // Load game
    function loadGame() {
      const saveData = localStorage.getItem('whisker_save');
      if (!saveData) {
        alert('No saved game found!');
        return;
      }
      
      const data = JSON.parse(saveData);
      currentPassage = data.currentPassage;
      history = data.history;
      variables = data.variables;
      
      showPassage(currentPassage);
      alert('Game loaded!');
    }
    
    // Restart story
    function restartStory() {
      if (confirm('Restart story? Current progress will be lost.')) {
        currentPassage = STORY_DATA.start_passage;
        history = [];
        variables = {};
        showPassage(currentPassage);
      }
    }
    
    // Keyboard shortcuts
    document.addEventListener('keydown', (e) => {
      if (e.ctrlKey || e.metaKey) {
        if (e.key === 's') {
          e.preventDefault();
          saveGame();
        } else if (e.key === 'l') {
          e.preventDefault();
          loadGame();
        } else if (e.key === 'r') {
          e.preventDefault();
          restartStory();
        }
      }
    });
    
    // Start
    init();
  ]]
end

--[[
  Export to file
  
  @param story Story Story object
  @param filepath string Output file path
  @param options table Export options
  @return boolean Success
  @return string|nil Error message
]]
function HTMLExporter:export_to_file(story, filepath, options)
  local html = self:export(story, options)
  
  local file = io.open(filepath, "w")
  if not file then
    return false, "Could not open file for writing: " .. filepath
  end
  
  file:write(html)
  file:close()
  
  return true, nil
end

return HTMLExporter
