--- CSS Variables for Theming
-- Standard CSS custom properties for consistent theming across Whisker stories
-- @module whisker.export.html.css_variables
-- @author Whisker Core Team
-- @license MIT

local CSSVariables = {}

-- Base CSS variables (light theme default)
CSSVariables.BASE = [[
:root {
    /* === Colors === */
    --ws-bg-color: #ffffff;
    --ws-text-color: #333333;
    --ws-muted-color: #666666;

    /* Links */
    --ws-link-color: #0066cc;
    --ws-link-visited-color: #551a8b;
    --ws-link-hover-color: #0044aa;

    /* === Choices === */
    --ws-choice-bg: #f5f5f5;
    --ws-choice-hover-bg: #e0e0e0;
    --ws-choice-active-bg: #d0d0d0;
    --ws-choice-text-color: var(--ws-text-color);
    --ws-choice-border-color: #cccccc;
    --ws-choice-border-radius: 4px;

    /* === Typography === */
    --ws-font-family: system-ui, -apple-system, "Segoe UI", Roboto, sans-serif;
    --ws-font-size: 16px;
    --ws-line-height: 1.6;
    --ws-heading-font-family: var(--ws-font-family);

    /* === Spacing === */
    --ws-passage-padding: 1.5rem;
    --ws-passage-max-width: 45rem;
    --ws-choice-margin: 0.5rem;
    --ws-choice-padding: 0.75rem 1rem;
    --ws-paragraph-margin: 1em;

    /* === Effects === */
    --ws-transition-duration: 0.2s;
    --ws-focus-outline: 2px solid var(--ws-link-color);
    --ws-focus-outline-offset: 2px;

    /* === Media === */
    --ws-media-max-width: 100%;
    --ws-media-border-radius: 4px;
}
]]

-- Dark theme overrides
CSSVariables.DARK_THEME = [[
:root.whisker-theme-dark,
.whisker-theme-dark {
    --ws-bg-color: #1a1a2e;
    --ws-text-color: #e8e8e8;
    --ws-muted-color: #a0a0a0;

    --ws-link-color: #6eb5ff;
    --ws-link-visited-color: #b4a7d6;
    --ws-link-hover-color: #9eceff;

    --ws-choice-bg: #16213e;
    --ws-choice-hover-bg: #1f3460;
    --ws-choice-active-bg: #2a4580;
    --ws-choice-border-color: #3a5080;
}
]]

-- Light theme (explicit, for when you want to force light)
CSSVariables.LIGHT_THEME = [[
:root.whisker-theme-light,
.whisker-theme-light {
    --ws-bg-color: #ffffff;
    --ws-text-color: #333333;
    --ws-muted-color: #666666;

    --ws-link-color: #0066cc;
    --ws-link-visited-color: #551a8b;
    --ws-link-hover-color: #0044aa;

    --ws-choice-bg: #f5f5f5;
    --ws-choice-hover-bg: #e0e0e0;
    --ws-choice-active-bg: #d0d0d0;
    --ws-choice-border-color: #cccccc;
}
]]

-- High contrast theme for accessibility
CSSVariables.HIGH_CONTRAST_THEME = [[
:root.whisker-theme-high-contrast,
.whisker-theme-high-contrast {
    --ws-bg-color: #000000;
    --ws-text-color: #ffffff;
    --ws-muted-color: #cccccc;

    --ws-link-color: #ffff00;
    --ws-link-visited-color: #ff00ff;
    --ws-link-hover-color: #00ffff;

    --ws-choice-bg: #333333;
    --ws-choice-hover-bg: #444444;
    --ws-choice-active-bg: #555555;
    --ws-choice-border-color: #ffffff;
    --ws-choice-border-radius: 0;

    --ws-focus-outline: 3px solid #ffff00;
}
]]

-- Sepia theme for reading comfort
CSSVariables.SEPIA_THEME = [[
:root.whisker-theme-sepia,
.whisker-theme-sepia {
    --ws-bg-color: #f4ecd8;
    --ws-text-color: #5c4b37;
    --ws-muted-color: #8b7355;

    --ws-link-color: #8b4513;
    --ws-link-visited-color: #654321;
    --ws-link-hover-color: #a0522d;

    --ws-choice-bg: #e8dcc8;
    --ws-choice-hover-bg: #ddd0b8;
    --ws-choice-active-bg: #d0c4a8;
    --ws-choice-border-color: #c4b89c;
}
]]

-- Component styles that use the CSS variables
CSSVariables.COMPONENT_STYLES = [[
body {
    background-color: var(--ws-bg-color);
    color: var(--ws-text-color);
    font-family: var(--ws-font-family);
    font-size: var(--ws-font-size);
    line-height: var(--ws-line-height);
    transition: background-color var(--ws-transition-duration), color var(--ws-transition-duration);
}

.whisker-passage {
    max-width: var(--ws-passage-max-width);
    margin: 0 auto;
    padding: var(--ws-passage-padding);
}

.whisker-passage p {
    margin-bottom: var(--ws-paragraph-margin);
}

.whisker-choice {
    display: block;
    background: var(--ws-choice-bg);
    color: var(--ws-choice-text-color);
    padding: var(--ws-choice-padding);
    margin: var(--ws-choice-margin) 0;
    border: 1px solid var(--ws-choice-border-color);
    border-radius: var(--ws-choice-border-radius);
    cursor: pointer;
    text-decoration: none;
    transition: background-color var(--ws-transition-duration);
}

.whisker-choice:hover {
    background: var(--ws-choice-hover-bg);
}

.whisker-choice:active {
    background: var(--ws-choice-active-bg);
}

.whisker-choice:focus {
    outline: var(--ws-focus-outline);
    outline-offset: var(--ws-focus-outline-offset);
}

a {
    color: var(--ws-link-color);
    transition: color var(--ws-transition-duration);
}

a:visited {
    color: var(--ws-link-visited-color);
}

a:hover {
    color: var(--ws-link-hover-color);
}

/* Media elements */
.whisker-media {
    max-width: var(--ws-media-max-width);
    border-radius: var(--ws-media-border-radius);
}

.whisker-audio,
.whisker-video {
    width: 100%;
    max-width: var(--ws-media-max-width);
}

.whisker-embed {
    max-width: var(--ws-media-max-width);
    border: none;
    border-radius: var(--ws-media-border-radius);
}
]]

-- Get all built-in theme CSS
-- @param themes table Array of theme names to include
-- @return string Combined CSS for all specified themes
function CSSVariables.get_theme_css(themes)
  local css_parts = { CSSVariables.BASE }

  themes = themes or {}
  for _, theme in ipairs(themes) do
    if theme == "dark" then
      table.insert(css_parts, CSSVariables.DARK_THEME)
    elseif theme == "light" then
      table.insert(css_parts, CSSVariables.LIGHT_THEME)
    elseif theme == "high-contrast" then
      table.insert(css_parts, CSSVariables.HIGH_CONTRAST_THEME)
    elseif theme == "sepia" then
      table.insert(css_parts, CSSVariables.SEPIA_THEME)
    end
  end

  table.insert(css_parts, CSSVariables.COMPONENT_STYLES)

  return table.concat(css_parts, "\n")
end

-- Get theme classes for HTML root element
-- @param themes table Array of theme names
-- @return string Space-separated CSS classes
function CSSVariables.get_theme_classes(themes)
  local classes = {}
  themes = themes or {}

  for _, theme in ipairs(themes) do
    table.insert(classes, "whisker-theme-" .. theme)
  end

  return table.concat(classes, " ")
end

-- Get list of available built-in themes
-- @return table Array of theme names
function CSSVariables.get_available_themes()
  return {"light", "dark", "high-contrast", "sepia"}
end

return CSSVariables
