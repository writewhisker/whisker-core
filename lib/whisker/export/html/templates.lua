--- HTML Export Templates
-- Built-in HTML templates for export
-- @module whisker.export.html.templates
-- @author Whisker Core Team
-- @license MIT

local Templates = {}

--- Get the default template
-- @return string Default HTML template
function Templates.get_default()
  return [[<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <meta name="generator" content="whisker-core">
  <title>{{story.title}}</title>
  {{> styles}}
</head>
<body>
  <div id="story-container">
    {{> header}}
    <main id="story" role="main" aria-live="polite">
      <div id="passage"></div>
      <ul id="choices" class="choices" role="navigation" aria-label="Story choices"></ul>
    </main>
    {{> footer}}
  </div>

  <script>
    var WHISKER_STORY_DATA = {{{story_json}}};
    {{{runtime_js}}}
  </script>
</body>
</html>]]
end

--- Get the minimal template
-- @return string Minimal HTML template
function Templates.get_minimal()
  return [[<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <title>{{story.title}}</title>
  <style>
    body { font-family: sans-serif; max-width: 600px; margin: 50px auto; padding: 20px; }
    #passage { margin-bottom: 20px; }
    .choices { list-style: none; padding: 0; }
    .choice-link { color: #007bff; cursor: pointer; text-decoration: underline; }
    .choice-link:hover { color: #0056b3; }
  </style>
</head>
<body>
  <div id="passage"></div>
  <ul id="choices" class="choices"></ul>
  <script>
    var WHISKER_STORY_DATA = {{{story_json}}};
    {{{runtime_js}}}
  </script>
</body>
</html>]]
end

--- Get the accessible template (enhanced accessibility)
-- WCAG 2.1 Level AA compliant template with full accessibility support
-- @return string Accessible HTML template
function Templates.get_accessible()
  return [[<!DOCTYPE html>
<html lang="{{story.language}}">
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <meta name="generator" content="whisker-core">
  <meta name="description" content="{{story.description}}">
  <title>{{story.title}} - Interactive Story</title>
  <style>
    /* Reset and base */
    *, *::before, *::after { box-sizing: border-box; }

    body {
      font-family: Georgia, 'Times New Roman', serif;
      font-size: 1.125rem;
      max-width: 800px;
      margin: 0 auto;
      padding: 20px;
      line-height: 1.8;
      color: #1a1a1a;
      background: #fafafa;
    }

    #story-container {
      background: white;
      padding: 2em;
      border-radius: 4px;
      box-shadow: 0 2px 4px rgba(0,0,0,0.1);
    }

    /* Header */
    .story-header {
      border-bottom: 3px solid #0066cc;
      margin-bottom: 2em;
      padding-bottom: 1em;
    }

    .story-header h1 {
      margin: 0 0 0.5em;
      color: #0066cc;
      font-size: 2rem;
    }

    .author {
      margin: 0;
      color: #555;
      font-style: italic;
      font-size: 1rem;
    }

    /* Passage content */
    #passage {
      margin-bottom: 2em;
      min-height: 100px;
    }

    #passage h2 {
      font-size: 1.5rem;
      margin-top: 0;
      color: #333;
    }

    #passage p {
      margin-bottom: 1em;
    }

    /* Choices */
    .choices {
      list-style: none;
      padding: 0;
      margin: 0;
    }

    .choices li {
      margin: 1em 0;
    }

    .choice-link {
      display: inline-block;
      padding: 1em 2em;
      background: #0066cc;
      color: white;
      text-decoration: none;
      border-radius: 4px;
      border: 2px solid #0066cc;
      cursor: pointer;
      font-size: 1rem;
      transition: background-color 0.2s ease, border-color 0.2s ease;
    }

    .choice-link:hover {
      background: #004d99;
      border-color: #004d99;
    }

    .choice-link:focus {
      outline: 3px solid #ff6600;
      outline-offset: 3px;
    }

    .choice-link:focus:not(:focus-visible) {
      outline: none;
    }

    .choice-link:focus-visible {
      outline: 3px solid #ff6600;
      outline-offset: 3px;
    }

    .choice-link[aria-selected="true"] {
      background: #004d99;
      border-color: #ff6600;
    }

    /* Footer */
    .story-footer {
      margin-top: 3em;
      padding-top: 1em;
      border-top: 1px solid #ddd;
      text-align: center;
      color: #666;
      font-size: 0.9rem;
    }

    /* Screen reader only */
    .sr-only {
      position: absolute;
      width: 1px;
      height: 1px;
      padding: 0;
      margin: -1px;
      overflow: hidden;
      clip: rect(0, 0, 0, 0);
      white-space: nowrap;
      border-width: 0;
    }

    /* Skip link */
    .skip-link {
      position: absolute;
      top: -40px;
      left: 0;
      background: #000;
      color: #fff;
      padding: 8px 16px;
      text-decoration: none;
      z-index: 100;
      font-weight: bold;
    }

    .skip-link:focus {
      top: 0;
    }

    /* Live region announcements */
    #announcements {
      position: absolute;
      width: 1px;
      height: 1px;
      overflow: hidden;
      clip: rect(0, 0, 0, 0);
    }

    /* Navigation controls */
    .story-controls {
      display: flex;
      gap: 1em;
      margin-bottom: 1.5em;
      padding: 1em;
      background: #f5f5f5;
      border-radius: 4px;
    }

    .story-controls button {
      padding: 0.5em 1em;
      background: #fff;
      border: 1px solid #ccc;
      border-radius: 4px;
      cursor: pointer;
      font-size: 0.9rem;
    }

    .story-controls button:hover {
      background: #e9e9e9;
    }

    .story-controls button:focus {
      outline: 2px solid #0066cc;
      outline-offset: 2px;
    }

    /* High contrast mode (Windows) */
    @media (forced-colors: active) {
      .choice-link {
        border: 2px solid currentColor;
      }

      .choice-link:focus {
        outline: 3px solid Highlight;
      }

      .story-controls button {
        border: 2px solid currentColor;
      }
    }

    /* Prefer high contrast */
    @media (prefers-contrast: more) {
      body {
        color: #000;
        background: #fff;
      }

      .choice-link {
        border-width: 3px;
      }

      *:focus {
        outline-width: 4px;
      }
    }

    /* Prefer low contrast */
    @media (prefers-contrast: less) {
      body {
        color: #333;
        background: #f5f5f5;
      }
    }

    /* Reduced motion */
    @media (prefers-reduced-motion: reduce) {
      *,
      *::before,
      *::after {
        animation-duration: 0.01ms !important;
        animation-iteration-count: 1 !important;
        transition-duration: 0.01ms !important;
        scroll-behavior: auto !important;
      }
    }

    /* Print styles */
    @media print {
      .skip-link,
      .story-controls,
      .story-footer {
        display: none;
      }

      body {
        max-width: none;
        padding: 0;
        background: white;
      }

      #story-container {
        box-shadow: none;
      }
    }
  </style>
</head>
<body>
  <!-- Skip link for keyboard users -->
  <a href="#passage" class="skip-link">Skip to story content</a>

  <!-- Live region for screen reader announcements -->
  <div id="announcements" aria-live="polite" aria-atomic="true"></div>
  <div id="announcements-assertive" aria-live="assertive" aria-atomic="true" class="sr-only"></div>

  <div id="story-container">
    <!-- Story header -->
    <header class="story-header" role="banner">
      <h1>{{story.title}}</h1>
      {{#if story.author}}
      <p class="author">by {{story.author}}</p>
      {{/if}}
    </header>

    <!-- Navigation controls -->
    <nav class="story-controls" aria-label="Story controls">
      <button type="button" id="restart-btn" aria-label="Restart story from beginning">Restart</button>
    </nav>

    <!-- Main story content -->
    <main id="story" role="main" aria-label="Story content">
      <article id="passage" tabindex="-1" aria-live="polite" aria-atomic="true">
        <!-- Passage content inserted here -->
      </article>

      <nav aria-label="Available choices">
        <h2 class="sr-only">Choices</h2>
        <ul id="choices" class="choices" role="listbox" aria-label="Story choices"></ul>
      </nav>
    </main>

    <!-- Footer -->
    <footer class="story-footer" role="contentinfo">
      <p><small>Created with <a href="https://github.com/writewhisker/whisker-core">whisker-core</a> |
      <a href="#accessibility-info">Accessibility info</a></small></p>
    </footer>
  </div>

  <!-- Accessibility information (hidden by default) -->
  <section id="accessibility-info" class="sr-only">
    <h2>Accessibility Information</h2>
    <p>This story is accessible with keyboard navigation and screen readers.</p>
    <h3>Keyboard Shortcuts</h3>
    <ul>
      <li>Tab: Move between choices</li>
      <li>Enter or Space: Select a choice</li>
      <li>Arrow Up/Down: Navigate choices</li>
    </ul>
  </section>

  <script>
    var WHISKER_STORY_DATA = {{{story_json}}};
    {{{runtime_js}}}
  </script>
</body>
</html>]]
end

--- Get the header partial
-- @return string Header partial template
function Templates.get_partial_header()
  return [[<header class="story-header">
      <h1>{{story.title}}</h1>
      {{#if story.author}}
      <p class="author">by {{story.author}}</p>
      {{/if}}
    </header>]]
end

--- Get the footer partial
-- @return string Footer partial template
function Templates.get_partial_footer()
  return [[<footer class="story-footer">
      <p><small>Created with <a href="https://github.com/writewhisker/whisker-core">whisker-core</a></small></p>
    </footer>]]
end

--- Get the styles partial
-- @return string Styles partial template
function Templates.get_partial_styles()
  return [[<style>
    * { box-sizing: border-box; }
    body {
      font-family: Georgia, 'Times New Roman', serif;
      max-width: 800px;
      margin: 0 auto;
      padding: 20px;
      line-height: 1.6;
      color: #333;
      background: #f9f9f9;
    }
    #story-container {
      background: white;
      padding: 2em;
      border-radius: 4px;
      box-shadow: 0 2px 4px rgba(0,0,0,0.1);
    }
    .story-header {
      border-bottom: 2px solid #007bff;
      margin-bottom: 2em;
      padding-bottom: 1em;
    }
    .story-header h1 {
      margin: 0 0 0.5em;
      color: #007bff;
    }
    .author {
      margin: 0;
      color: #666;
      font-style: italic;
    }
    #passage {
      margin-bottom: 2em;
      min-height: 100px;
    }
    .choices {
      list-style: none;
      padding: 0;
      margin: 0;
    }
    .choices li {
      margin: 0.5em 0;
    }
    .choice-link {
      display: inline-block;
      padding: 0.75em 1.5em;
      background: #007bff;
      color: white;
      text-decoration: none;
      border-radius: 4px;
      border: none;
      cursor: pointer;
      font-size: 1em;
      transition: background 0.2s ease;
    }
    .choice-link:hover {
      background: #0056b3;
    }
    .choice-link:focus {
      outline: 3px solid #0056b3;
      outline-offset: 2px;
    }
    .story-footer {
      margin-top: 3em;
      padding-top: 1em;
      border-top: 1px solid #ddd;
      text-align: center;
      color: #666;
      font-size: 0.9em;
    }
  </style>]]
end

--- Get a template by name
-- @param name string Template name (default, minimal, accessible)
-- @return string|nil Template content or nil
function Templates.get(name)
  local templates = {
    default = Templates.get_default,
    minimal = Templates.get_minimal,
    accessible = Templates.get_accessible,
  }

  local getter = templates[name]
  if getter then
    return getter()
  end
  return nil
end

--- Get a partial by name
-- @param name string Partial name (header, footer, styles)
-- @return string|nil Partial content or nil
function Templates.get_partial(name)
  local partials = {
    header = Templates.get_partial_header,
    footer = Templates.get_partial_footer,
    styles = Templates.get_partial_styles,
  }

  local getter = partials[name]
  if getter then
    return getter()
  end
  return nil
end

--- Get list of available template names
-- @return table Array of template names
function Templates.get_available()
  return {"default", "minimal", "accessible"}
end

return Templates
