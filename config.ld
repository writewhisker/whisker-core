-- LDoc Configuration for whisker-core
-- Run: ldoc .

project = 'whisker-core'
title = 'Whisker-Core API Reference'
description = 'Lua-based interactive fiction framework'

file = {
  'lib/whisker',
  exclude = {
    'lib/whisker/vendor',
    'lib/whisker/test',
  }
}

format = 'markdown'
output = 'docs/api'
dir = 'docs/api'

readme = 'README.md'

examples = {
  'examples'
}

-- Custom tags
custom_tags = {
  {
    'pure',
    title = 'Pure Function',
    format = 'This function has no side effects'
  },
  {
    'idempotent',
    title = 'Idempotent',
    format = 'Calling this function multiple times with same input produces same result'
  },
  {
    'ensure',
    title = 'Post-condition',
    format = nil
  },
  {
    'interface',
    title = 'Interface',
    format = nil
  }
}

-- Don't show private members (starting with _)
all = false

-- Sort items alphabetically
sort = true

-- Merge module documentation from the file header with module table
merge = true

-- Use pretty names for modules
prettify_files = true
