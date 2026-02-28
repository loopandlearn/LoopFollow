#!/bin/bash
# Convert SVG icon to required iOS app icon PNG sizes (light, dark, tinted) using Inkscape

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SVG_PATH="$SCRIPT_DIR/loopfollow-icon.svg"
CONTENTS_PATH="$SCRIPT_DIR/Contents.json"

if [ ! -f "$SVG_PATH" ]; then
    echo "Error: SVG file not found at $SVG_PATH"
    exit 1
fi

if ! command -v inkscape &> /dev/null; then
    echo "Error: Inkscape not found. Please install it first: brew install --cask inkscape"
    exit 1
fi

TMP_DIR="$(mktemp -d)"
trap 'rm -rf "$TMP_DIR"' EXIT

LIGHT_SVG="$TMP_DIR/light.svg"
DARK_SVG="$TMP_DIR/dark.svg"
TINTED_SVG="$TMP_DIR/tinted.svg"

cp "$SVG_PATH" "$LIGHT_SVG"
cp "$SVG_PATH" "$DARK_SVG"
cp "$SVG_PATH" "$TINTED_SVG"

echo "Preparing dark/tinted SVG variants without changing geometry..."

# Dark mode: keep geometry unchanged, use dark gray surfaces, and suppress bright edge glare.
sed -i '' 's/#F8F9FA/#1A2330/g' "$DARK_SVG"
sed -i '' 's/#FFFFFF/#2B3545/g' "$DARK_SVG"
sed -i '' 's/#F0F2F5/#1A2330/g' "$DARK_SVG"
sed -i '' '/r="315"/{n;s/fill="#2B3545"/fill="#232D3B"/;}' "$DARK_SVG"
sed -i '' '/r="200"/{n;s/fill="#2B3545"/fill="#232D3B"/;}' "$DARK_SVG"
sed -i '' 's/fill="url(#glassBg)"/fill="none"/g' "$DARK_SVG"
sed -i '' 's/fill="url(#topHighlight)"/fill="none"/g' "$DARK_SVG"
sed -i '' 's/opacity="0.8"/opacity="0"/g' "$DARK_SVG"
sed -i '' 's/opacity="0.7"/opacity="0"/g' "$DARK_SVG"
sed -i '' 's/opacity="0.6"/opacity="0"/g' "$DARK_SVG"
sed -i '' 's/opacity="0.98"/opacity="1"/g' "$DARK_SVG"
sed -i '' 's/opacity="0.95"/opacity="1"/g' "$DARK_SVG"
sed -i '' 's/opacity="0.25"/opacity="0"/g' "$DARK_SVG"
sed -i '' 's/opacity="0.05"/opacity="0"/g' "$DARK_SVG"
sed -i '' 's/stop-opacity:0.6/stop-opacity:0/g' "$DARK_SVG"
sed -i '' 's/stop-opacity:0.5/stop-opacity:0.04/g' "$DARK_SVG"
sed -i '' 's/stop-opacity:0.4/stop-opacity:0.06/g' "$DARK_SVG"
sed -i '' 's/stop-opacity:0.3/stop-opacity:0/g' "$DARK_SVG"
sed -i '' 's/stop-opacity:0.25/stop-opacity:0.08/g' "$DARK_SVG"
sed -i '' 's/stop-opacity:0.2/stop-opacity:0.04/g' "$DARK_SVG"
sed -i '' 's/stop-opacity:0.15/stop-opacity:0.08/g' "$DARK_SVG"
sed -i '' 's/stop-opacity:0.1/stop-opacity:0.03/g' "$DARK_SVG"
sed -i '' 's/stop-opacity:0.08/stop-opacity:0/g' "$DARK_SVG"
sed -i '' 's/stop-opacity:0.05/stop-opacity:0.02/g' "$DARK_SVG"

# Tinted mode: true high-contrast monochrome source so iOS tinting is visibly distinct.
sed -i '' 's/#F8F9FA/#000000/g' "$TINTED_SVG"
sed -i '' 's/#FFFFFF/#0A0A0A/g' "$TINTED_SVG"
sed -i '' 's/#F0F2F5/#000000/g' "$TINTED_SVG"
sed -i '' 's/opacity="0.8"/opacity="0"/g' "$TINTED_SVG"
sed -i '' 's/opacity="0.25"/opacity="0"/g' "$TINTED_SVG"
sed -i '' 's/#5BA3F5/#FFFFFF/g' "$TINTED_SVG"
sed -i '' 's/#4A90E2/#FFFFFF/g' "$TINTED_SVG"
sed -i '' 's/#3A7BC8/#FFFFFF/g' "$TINTED_SVG"
sed -i '' 's/stop-opacity:0.6/stop-opacity:0/g' "$TINTED_SVG"
sed -i '' 's/stop-opacity:0.5/stop-opacity:0/g' "$TINTED_SVG"
sed -i '' 's/stop-opacity:0.4/stop-opacity:0.02/g' "$TINTED_SVG"
sed -i '' 's/stop-opacity:0.3/stop-opacity:0/g' "$TINTED_SVG"
sed -i '' 's/stop-opacity:0.25/stop-opacity:0/g' "$TINTED_SVG"
sed -i '' 's/stop-opacity:0.2/stop-opacity:0/g' "$TINTED_SVG"
sed -i '' 's/stop-opacity:0.15/stop-opacity:0/g' "$TINTED_SVG"
sed -i '' 's/stop-opacity:0.1/stop-opacity:0/g' "$TINTED_SVG"
sed -i '' 's/stop-opacity:0.08/stop-opacity:0/g' "$TINTED_SVG"
sed -i '' 's/stop-opacity:0.05/stop-opacity:0/g' "$TINTED_SVG"

echo "Converting SVG variants to iOS app icon PNGs using Inkscape..."
echo "Source: $SVG_PATH"
echo ""

ICON_SIZE=1024
OUTPUT_LIGHT="$SCRIPT_DIR/1024.png"
OUTPUT_DARK="$SCRIPT_DIR/1024-dark.png"
OUTPUT_TINTED="$SCRIPT_DIR/1024-tinted.png"

# Remove only generated app icon files.
rm -f "$OUTPUT_LIGHT" "$OUTPUT_DARK" "$OUTPUT_TINTED"

success_count=0
total_count=3

export_png() {
    local source_svg="$1"
    local output_path="$2"
    local output_name
    output_name="$(basename "$output_path")"

    if inkscape "$source_svg" --export-filename="$output_path" --export-width="$ICON_SIZE" --export-height="$ICON_SIZE" --export-type=png 2>/dev/null; then
        echo "✓ Created $output_name (${ICON_SIZE}x${ICON_SIZE})"
        ((success_count+=1))
    else
        echo "✗ Error creating $output_name"
    fi
}

export_png "$LIGHT_SVG" "$OUTPUT_LIGHT"
export_png "$DARK_SVG" "$OUTPUT_DARK"
export_png "$TINTED_SVG" "$OUTPUT_TINTED"

echo ""
echo "✓ Successfully created $success_count/$total_count icon files"

if [ "$success_count" -ne "$total_count" ]; then
    echo ""
    echo "Some icons failed to create. Please check errors above."
    exit 1
fi

echo ""
echo "Regenerating $CONTENTS_PATH in iOS single-size Any/Dark/Tinted format..."

cat > "$CONTENTS_PATH" << 'EOF'
{
    "images" : [
        {
            "filename" : "1024.png",
            "idiom" : "universal",
            "platform" : "ios",
            "scale" : "1x",
            "size" : "1024x1024"
        },
        {
            "appearances" : [
                {
                    "appearance" : "luminosity",
                    "value" : "dark"
                }
            ],
            "filename" : "1024-dark.png",
            "idiom" : "universal",
            "platform" : "ios",
            "scale" : "1x",
            "size" : "1024x1024"
        },
        {
            "appearances" : [
                {
                    "appearance" : "luminosity",
                    "value" : "tinted"
                }
            ],
            "filename" : "1024-tinted.png",
            "idiom" : "universal",
            "platform" : "ios",
            "scale" : "1x",
            "size" : "1024x1024"
        }
    ],
    "info" : {
        "author" : "xcode",
        "version" : 1
    }
}
EOF

echo ""
echo "All icons and appearance mappings created successfully."
