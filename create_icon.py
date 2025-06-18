#!/usr/bin/env python3
"""
Simple script to create an app icon for PortList
Creates a network-themed icon with nodes and connections
"""

import sys
import math

# Handle PIL import gracefully
try:
    from PIL import Image, ImageDraw  # type: ignore
    PIL_AVAILABLE = True
except ImportError:
    PIL_AVAILABLE = False
    # Create dummy classes to avoid runtime errors
    class Image:
        pass
    class ImageDraw:
        pass

def create_icon():
    """Create a simple network icon"""
    if not PIL_AVAILABLE:
        print("PIL (Pillow) not available. Install with: pip3 install Pillow")
        return False
    
    # Import PIL modules here since they're available
    from PIL import Image, ImageDraw
    
    # Create image with alpha channel
    size = 512
    img = Image.new('RGBA', (size, size), (0, 0, 0, 0))
    draw = ImageDraw.Draw(img)
    
    # Colors
    primary_color = (70, 130, 255, 255)  # Blue
    secondary_color = (255, 255, 255, 255)  # White
    accent_color = (255, 140, 0, 255)  # Orange
    
    # Background circle
    margin = 50
    draw.ellipse([margin, margin, size-margin, size-margin], fill=primary_color)
    
    # Central hub
    center = size // 2
    hub_radius = 30
    draw.ellipse([center-hub_radius, center-hub_radius, 
                  center+hub_radius, center+hub_radius], fill=secondary_color)
    
    # Connection nodes and lines
    node_radius = 20
    connection_radius = 150
    
    # Draw 6 nodes connected to center
    for i in range(6):
        angle = i * 60  # 60 degrees apart
        x = center + connection_radius * math.cos(math.radians(angle))
        y = center + connection_radius * math.sin(math.radians(angle))
        
        # Draw connection line
        draw.line([(center, center), (x, y)], fill=secondary_color, width=6)
        
        # Draw node
        node_color = accent_color if i % 2 == 0 else secondary_color
        draw.ellipse([x-node_radius, y-node_radius, 
                      x+node_radius, y+node_radius], fill=node_color)
    
    # Add some smaller connecting lines between outer nodes
    for i in range(6):
        angle1 = i * 60
        angle2 = ((i + 1) % 6) * 60
        
        x1 = center + connection_radius * math.cos(math.radians(angle1))
        y1 = center + connection_radius * math.sin(math.radians(angle1))
        x2 = center + connection_radius * math.cos(math.radians(angle2))
        y2 = center + connection_radius * math.sin(math.radians(angle2))
        
        # Draw thinner connecting lines
        draw.line([(x1, y1), (x2, y2)], fill=(255, 255, 255, 128), width=2)
    
    # Save as PNG
    img.save('Resources/AppIcon.png')
    print("✅ Created Resources/AppIcon.png")
    
    # Create smaller sizes for different resolutions
    sizes = [16, 32, 64, 128, 256, 512]
    for s in sizes:
        resized = img.resize((s, s), Image.Resampling.LANCZOS)
        resized.save(f'Resources/AppIcon_{s}x{s}.png')
    
    print("✅ Created multiple icon sizes")
    return True

def create_icns():
    """Convert PNG to ICNS format using system tools"""
    import subprocess
    import os
    
    if not os.path.exists('Resources/AppIcon.png'):
        print("❌ AppIcon.png not found")
        return False
    
    try:
        # Use sips to convert PNG to ICNS
        subprocess.run([
            'sips', '-s', 'format', 'icns', 
            'Resources/AppIcon.png', 
            '--out', 'Resources/AppIcon.icns'
        ], check=True, capture_output=True)
        print("✅ Created Resources/AppIcon.icns")
        return True
    except subprocess.CalledProcessError:
        print("⚠️  Could not create ICNS file (sips not available)")
        return False
    except FileNotFoundError:
        print("⚠️  Could not create ICNS file (sips not found)")
        return False

if __name__ == "__main__":
    print("🎨 Creating PortList app icon...")
    
    # Create Resources directory if it doesn't exist
    import os
    os.makedirs('Resources', exist_ok=True)
    
    if create_icon():
        create_icns()
        print("🎉 Icon creation complete!")
    else:
        print("❌ Icon creation failed")
        sys.exit(1)