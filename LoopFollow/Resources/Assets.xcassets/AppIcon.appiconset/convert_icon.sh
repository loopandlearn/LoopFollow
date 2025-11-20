#!/bin/bash
# Convert SVG icon to all required iOS app icon PNG sizes using Inkscape

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SVG_PATH="$SCRIPT_DIR/loopfollow-icon.svg"

if [ ! -f "$SVG_PATH" ]; then
    echo "Error: SVG file not found at $SVG_PATH"
    exit 1
fi

if ! command -v inkscape &> /dev/null; then
    echo "Error: Inkscape not found. Please install it first: brew install --cask inkscape"
    exit 1
fi

echo "Converting SVG to iOS app icon PNGs using Inkscape..."
echo "Source: $SVG_PATH"
echo ""

# iOS app icon sizes (filename size pairs)
icon_sizes=(
    "20.png 20"
    "29.png 29"
    "40.png 40"
    "40-1.png 40"
    "40-2.png 40"
    "58.png 58"
    "58-1.png 58"
    "60.png 60"
    "76.png 76"
    "80.png 80"
    "80-1.png 80"
    "87.png 87"
    "120.png 120"
    "120-1.png 120"
    "152.png 152"
    "167.png 167"
    "180.png 180"
    "1024.png 1024"
)

success_count=0
total_count=${#icon_sizes[@]}

for entry in "${icon_sizes[@]}"; do
    filename=$(echo $entry | cut -d' ' -f1)
    size=$(echo $entry | cut -d' ' -f2)
    png_path="$SCRIPT_DIR/$filename"
    
    # Inkscape export command
    if inkscape "$SVG_PATH" --export-filename="$png_path" --export-width=$size --export-height=$size --export-type=png 2>/dev/null; then
        echo "✓ Created $filename (${size}x${size})"
        ((success_count++))
    else
        echo "✗ Error creating $filename"
    fi
done

echo ""
echo "✓ Successfully created $success_count/$total_count icon files"

if [ $success_count -eq $total_count ]; then
    echo ""
    echo "All icons created successfully!"
    exit 0
else
    echo ""
    echo "Some icons failed to create. Please check errors above."
    exit 1
fi
