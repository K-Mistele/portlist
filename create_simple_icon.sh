#!/bin/bash

# Simple icon creation script that doesn't require PIL
echo "🎨 Creating simple PortList app icon..."

# Create Resources directory if it doesn't exist
mkdir -p Resources

# Create a simple SVG icon first
cat > Resources/icon.svg << 'EOF'
<svg width="512" height="512" xmlns="http://www.w3.org/2000/svg">
  <!-- Background circle -->
  <circle cx="256" cy="256" r="206" fill="#4682FF" stroke="#ffffff" stroke-width="8"/>
  
  <!-- Central hub -->
  <circle cx="256" cy="256" r="30" fill="#ffffff"/>
  
  <!-- Connection lines and nodes -->
  <g stroke="#ffffff" stroke-width="6" fill="#ffffff">
    <!-- Node 1 (top) -->
    <line x1="256" y1="256" x2="256" y2="106"/>
    <circle cx="256" cy="106" r="20" fill="#FF8C00"/>
    
    <!-- Node 2 (top-right) -->
    <line x1="256" y1="256" x2="386" y2="181"/>
    <circle cx="386" cy="181" r="20" fill="#ffffff"/>
    
    <!-- Node 3 (bottom-right) -->
    <line x1="256" y1="256" x2="386" y2="331"/>
    <circle cx="386" cy="331" r="20" fill="#FF8C00"/>
    
    <!-- Node 4 (bottom) -->
    <line x1="256" y1="256" x2="256" y2="406"/>
    <circle cx="256" cy="406" r="20" fill="#ffffff"/>
    
    <!-- Node 5 (bottom-left) -->
    <line x1="256" y1="256" x2="126" y2="331"/>
    <circle cx="126" cy="331" r="20" fill="#FF8C00"/>
    
    <!-- Node 6 (top-left) -->
    <line x1="256" y1="256" x2="126" y2="181"/>
    <circle cx="126" cy="181" r="20" fill="#ffffff"/>
  </g>
  
  <!-- Inter-node connections -->
  <g stroke="#ffffff" stroke-width="2" stroke-opacity="0.7">
    <line x1="256" y1="106" x2="386" y2="181"/>
    <line x1="386" y1="181" x2="386" y2="331"/>
    <line x1="386" y1="331" x2="256" y2="406"/>
    <line x1="256" y1="406" x2="126" y2="331"/>
    <line x1="126" y1="331" x2="126" y2="181"/>
    <line x1="126" y1="181" x2="256" y2="106"/>
  </g>
</svg>
EOF

echo "✅ Created SVG icon"

# Try to convert SVG to PNG using various available tools
if command -v rsvg-convert &> /dev/null; then
    echo "📸 Converting SVG to PNG using rsvg-convert..."
    rsvg-convert -w 512 -h 512 Resources/icon.svg -o Resources/AppIcon.png
    echo "✅ Created PNG icon"
elif command -v convert &> /dev/null; then
    echo "📸 Converting SVG to PNG using ImageMagick..."
    convert -background transparent Resources/icon.svg -resize 512x512 Resources/AppIcon.png
    echo "✅ Created PNG icon"
elif command -v inkscape &> /dev/null; then
    echo "📸 Converting SVG to PNG using Inkscape..."
    inkscape --export-png=Resources/AppIcon.png --export-width=512 --export-height=512 Resources/icon.svg
    echo "✅ Created PNG icon"
else
    echo "⚠️  No SVG conversion tools available. You'll need to manually convert the SVG to PNG."
    echo "   SVG file saved as Resources/icon.svg"
fi

# Create multiple sizes if we have the PNG
if [[ -f "Resources/AppIcon.png" ]]; then
    echo "🔄 Creating multiple icon sizes..."
    
    if command -v convert &> /dev/null; then
        for size in 16 32 64 128 256 512; do
            convert Resources/AppIcon.png -resize ${size}x${size} Resources/AppIcon_${size}x${size}.png
        done
        echo "✅ Created multiple icon sizes"
    fi
fi

echo "🎉 Icon creation complete!"
echo "📁 Icon files created in Resources/ directory"