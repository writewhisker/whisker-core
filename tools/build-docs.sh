#!/bin/bash
# Build documentation for whisker-core
# Usage: ./tools/build-docs.sh

set -e

echo "Building whisker-core documentation..."

# Check for ldoc
if ! command -v ldoc &> /dev/null; then
    echo "Warning: ldoc not found. Install with: luarocks install ldoc"
    echo "Skipping API documentation generation."
else
    echo "Generating API reference from source..."
    ldoc .

    if [ $? -eq 0 ]; then
        echo "✓ API documentation built successfully"
    else
        echo "✗ API documentation build failed"
        exit 1
    fi
fi

# Ensure output directory exists
mkdir -p docs/api

# Copy guides to output
if [ -d "docs/guides" ]; then
    cp -r docs/guides docs/api/
    echo "✓ Guides copied to docs/api/"
fi

echo ""
echo "✓ Documentation build complete"
echo "  View at: docs/api/index.html"
echo "  Guides at: docs/api/guides/"
