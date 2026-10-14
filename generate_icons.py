import os
from PIL import Image, ImageDraw

def create_icon(size):
    # Create image with RGBA
    img = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    draw = ImageDraw.Draw(img)
    
    # Outer circle coordinates
    padding = max(1, int(size * 0.06))
    bbox = [padding, padding, size - padding, size - padding]
    
    # Gradient or solid sleek vibrant background
    # We can draw multiple concentric rings or a rich violet/indigo gradient
    radius = (size - 2 * padding) / 2
    center = size / 2
    
    for r in range(int(radius), 0, -1):
        ratio = r / radius
        # Interpolate between deep indigo #4f46e5 (79, 70, 229) and vivid cyan #06b6d4 (6, 182, 212)
        r_col = int(79 * (1 - ratio) + 6 * ratio)
        g_col = int(70 * (1 - ratio) + 182 * ratio)
        b_col = int(229 * (1 - ratio) + 212 * ratio)
        draw.ellipse([center - r, center - r, center + r, center + r], fill=(r_col, g_col, b_col, 255))
        
    # Draw an AI sparkle / Shazam-like 'S' lightning in the center (white)
    # 4-pointed star or lightning/sparkle
    s = size / 128.0
    sparkle_points = [
        (64 * s, 26 * s),   # top tip
        (72 * s, 54 * s),
        (100 * s, 64 * s),  # right tip
        (72 * s, 74 * s),
        (64 * s, 102 * s),  # bottom tip
        (56 * s, 74 * s),
        (28 * s, 64 * s),   # left tip
        (56 * s, 54 * s),
    ]
    draw.polygon(sparkle_points, fill=(255, 255, 255, 250))
    
    # Smaller accent sparkle top right
    accent_points = [
        (88 * s, 34 * s),
        (91 * s, 42 * s),
        (99 * s, 45 * s),
        (91 * s, 48 * s),
        (88 * s, 56 * s),
        (85 * s, 48 * s),
        (77 * s, 45 * s),
        (85 * s, 42 * s),
    ]
    draw.polygon(accent_points, fill=(255, 255, 255, 230))
    
    return img

os.makedirs("extension/icons", exist_ok=True)
for sz in [16, 48, 128]:
    icon = create_icon(sz)
    icon.save(f"extension/icons/icon{sz}.png")
    print(f"Generated icon{sz}.png")
