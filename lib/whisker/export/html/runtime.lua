--- HTML Runtime Generator
-- Creates JavaScript runtime code for HTML exports
-- @module whisker.export.html.runtime
-- @author Whisker Core Team
-- @license MIT

local Runtime = {}

--- Get the runtime JavaScript code
-- @return string JavaScript runtime code (ES5 compatible)
function Runtime.get_runtime_code()
  return [[
(function() {
  'use strict';

  // Runtime state
  var story = WHISKER_STORY_DATA;
  var currentPassage = null;
  var history = [];
  var variables = {};

  // DOM elements
  var passageEl = document.getElementById('passage');
  var choicesEl = document.getElementById('choices');

  // Initialize story
  function init() {
    var startPassage = story.start || story.start_passage || 'start';
    showPassage(startPassage);
  }

  // Display a passage
  function showPassage(passageName) {
    var passage = findPassage(passageName);
    if (!passage) {
      console.error('Passage not found: ' + passageName);
      passageEl.innerHTML = '<div class="error">Error: Passage "' + escapeHtml(passageName) + '" not found.</div>';
      choicesEl.innerHTML = '';
      return;
    }

    // Update history
    if (currentPassage) {
      history.push(currentPassage.name);
    }
    currentPassage = passage;

    // Render passage text
    var text = passage.text || passage.content || '';
    passageEl.innerHTML = '<div class="passage-content">' + processText(text) + '</div>';

    // Render choices
    choicesEl.innerHTML = '';
    var choices = passage.choices || passage.links || [];

    if (choices.length > 0) {
      choices.forEach(function(choice, index) {
        // Check if choice should be shown (conditions)
        if (choice.condition && !evaluateCondition(choice.condition)) {
          return;
        }

        var li = document.createElement('li');
        var a = document.createElement('a');
        a.href = '#';
        a.className = 'choice-link';
        a.setAttribute('role', 'button');
        a.setAttribute('tabindex', '0');
        a.textContent = choice.text || choice.label || ('Choice ' + (index + 1));

        a.onclick = function(e) {
          e.preventDefault();
          var target = choice.target || choice.passage || choice.link;
          if (target) {
            showPassage(target);
          }
        };

        a.onkeydown = function(e) {
          if (e.key === 'Enter' || e.key === ' ') {
            e.preventDefault();
            a.click();
          }
        };

        li.appendChild(a);
        choicesEl.appendChild(li);
      });
    }

    // Scroll to top
    window.scrollTo(0, 0);

    // Focus first choice for keyboard navigation
    var firstChoice = choicesEl.querySelector('.choice-link');
    if (firstChoice) {
      firstChoice.focus();
    }
  }

  // Find passage by name
  function findPassage(name) {
    var passages = story.passages || [];
    for (var i = 0; i < passages.length; i++) {
      if (passages[i].name === name || passages[i].id === name) {
        return passages[i];
      }
    }
    return null;
  }

  // Process text with variable substitution
  function processText(text) {
    // Replace variable references like {variable} or {{variable}}
    text = text.replace(/\{\{?([^}]+)\}?\}/g, function(match, varName) {
      varName = varName.trim();
      if (variables.hasOwnProperty(varName)) {
        return escapeHtml(String(variables[varName]));
      }
      return match;
    });

    // Convert newlines to <br> tags
    text = text.replace(/\n/g, '<br>');

    return text;
  }

  // Evaluate a simple condition
  function evaluateCondition(condition) {
    if (typeof condition === 'boolean') {
      return condition;
    }
    if (typeof condition === 'string') {
      // Simple variable check
      return !!variables[condition];
    }
    if (typeof condition === 'function') {
      return condition(variables);
    }
    return true;
  }

  // Escape HTML
  function escapeHtml(text) {
    var div = document.createElement('div');
    div.textContent = text;
    return div.innerHTML;
  }

  // Go back in history
  function goBack() {
    if (history.length > 0) {
      var previousPassage = history.pop();
      currentPassage = null; // Don't add current to history again
      showPassage(previousPassage);
    }
  }

  // Set a variable
  function setVariable(name, value) {
    variables[name] = value;
  }

  // Get a variable
  function getVariable(name) {
    return variables[name];
  }

  // Restart the story
  function restart() {
    history = [];
    variables = {};
    currentPassage = null;
    init();
  }

  // Export public API
  window.whiskerRuntime = {
    showPassage: showPassage,
    goBack: goBack,
    restart: restart,
    setVariable: setVariable,
    getVariable: getVariable,
    getCurrentPassage: function() { return currentPassage; },
    getHistory: function() { return history.slice(); }
  };

  // Start story when DOM ready
  if (document.readyState === 'loading') {
    document.addEventListener('DOMContentLoaded', init);
  } else {
    init();
  }
})();
]]
end

--- Get minimal runtime code (stripped down version)
-- @return string Minimal JavaScript runtime
function Runtime.get_minimal_runtime_code()
  return [[
(function() {
  var story = WHISKER_STORY_DATA;
  var passageEl = document.getElementById('passage');
  var choicesEl = document.getElementById('choices');

  function show(name) {
    var p = null;
    for (var i = 0; i < story.passages.length; i++) {
      if (story.passages[i].name === name) { p = story.passages[i]; break; }
    }
    if (!p) { passageEl.textContent = 'Not found: ' + name; return; }
    passageEl.innerHTML = p.text || '';
    choicesEl.innerHTML = '';
    (p.choices || []).forEach(function(c) {
      var li = document.createElement('li');
      var a = document.createElement('a');
      a.href = '#';
      a.textContent = c.text;
      a.onclick = function(e) { e.preventDefault(); show(c.target); };
      li.appendChild(a);
      choicesEl.appendChild(li);
    });
  }

  show(story.start || 'start');
})();
]]
end

return Runtime
