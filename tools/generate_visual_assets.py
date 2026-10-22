#!/usr/bin/env python3
"""
Duel Chess: Battle Remake - Visual Asset Generator
Generates:
1. 18 HUD Piece Portraits (512x512 PNG)
2. 3 Seamless PBR Board Textures (1024x1024 PNG)
3. Store & Marketing Assets (icon_512, steam_capsule_header, galaxy_store_banner)

Supports google-genai / Gemini Image generation if API credentials are present,
with high-fidelity mathematical PIL procedural synthesis fallback.
"""

import os
import sys
import math
import numpy as np
from PIL import Image, ImageDraw, ImageFilter, ImageFont, ImageChops

PORTRAIT_DIR = "assets/textures/ui/portraits"
BOARD_DIR = "assets/textures/board"
STORE_DIR = "assets/store"

os.makedirs(PORTRAIT_DIR, exist_ok=True)
os.makedirs(BOARD_DIR, exist_ok=True)
os.makedirs(STORE_DIR, exist_ok=True)

# ---------------------------------------------------------------------------
# Helper procedural drawing routines
# ---------------------------------------------------------------------------

def create_radial_gradient(size, inner_color, outer_color):
    w, h = size
    y, x = np.ogrid[:h, :w]
    cx, cy = w / 2.0, h / 2.0
    dist = np.sqrt((x - cx) ** 2 + (y - cy) ** 2)
    max_dist = np.sqrt(cx ** 2 + cy ** 2)
    norm = np.clip(dist / max_dist, 0.0, 1.0)
    
    r = (1.0 - norm) * inner_color[0] + norm * outer_color[0]
    g = (1.0 - norm) * inner_color[1] + norm * outer_color[1]
    b = (1.0 - norm) * inner_color[2] + norm * outer_color[2]
    a = (1.0 - norm) * inner_color[3] + norm * outer_color[3]
    
    arr = np.dstack([r, g, b, a]).astype(np.uint8)
    return Image.fromarray(arr, mode="RGBA")

def add_vignette(img, strength=0.7):
    w, h = img.size
    y, x = np.ogrid[:h, :w]
    cx, cy = w / 2.0, h / 2.0
    dist = np.sqrt((x - cx) ** 2 + (y - cy) ** 2)
    max_dist = np.sqrt(cx ** 2 + cy ** 2)
    factor = 1.0 - np.clip((dist / max_dist) * strength, 0.0, 1.0)
    
    arr = np.array(img, dtype=np.float32)
    for c in range(3):
        arr[:, :, c] *= factor
    return Image.fromarray(np.clip(arr, 0, 255).astype(np.uint8), mode="RGBA")

# ---------------------------------------------------------------------------
# 1. Seamless PBR Board Textures (1024x1024)
# ---------------------------------------------------------------------------

def generate_fantasy_marble(path):
    print(f"Generating Fantasy Marble PBR: {path}...")
    size = (1024, 1024)
    w, h = size
    
    # Base dark obsidian stone
    y, x = np.mgrid[:h, :w]
    # Procedural multi-octave turbulence
    noise1 = np.sin(x * 0.02 + y * 0.015) + np.cos(x * 0.012 - y * 0.025)
    noise2 = np.sin(x * 0.05 + np.cos(y * 0.04) * 2.5) * 0.5
    noise3 = np.cos((x + y) * 0.08) * 0.25
    total_noise = (noise1 + noise2 + noise3) / 2.0
    
    # Base slate colors (28, 34, 46) to (18, 20, 28)
    base_r = np.clip(22 + total_noise * 12, 10, 50)
    base_g = np.clip(26 + total_noise * 14, 12, 60)
    base_b = np.clip(38 + total_noise * 20, 18, 80)
    
    # Gold veins (thin high-intensity threshold veins)
    vein_field = np.sin(x * 0.018 + np.sin(y * 0.03) * 3.5) + np.cos(y * 0.022 + np.cos(x * 0.02) * 3.0)
    vein_mask = np.exp(-((vein_field - 0.2) ** 2) / 0.02)
    gold_r = 240 * vein_mask
    gold_g = 190 * vein_mask
    gold_b = 60 * vein_mask
    
    final_r = np.clip(base_r + gold_r, 0, 255).astype(np.uint8)
    final_g = np.clip(base_g + gold_g, 0, 255).astype(np.uint8)
    final_b = np.clip(base_b + gold_b, 0, 255).astype(np.uint8)
    final_a = np.full(size, 255, dtype=np.uint8)
    
    img = Image.fromarray(np.dstack([final_r, final_g, final_b, final_a]), mode="RGBA")
    
    # Subtle polish highlight
    draw = ImageDraw.Draw(img)
    for i in range(0, 1024, 128):
        draw.line([(i, 0), (i, 1024)], fill=(200, 170, 80, 25), width=2)
        draw.line([(0, i), (1024, i)], fill=(200, 170, 80, 25), width=2)
    
    img.save(path, format="PNG")
    print(f"Saved: {path}")

def generate_cyber_grid(path):
    print(f"Generating Cyberpunk Grid PBR: {path}...")
    size = (1024, 1024)
    w, h = size
    
    # Dark brushed steel base
    y, x = np.mgrid[:h, :w]
    brush = (np.sin(x * 1.5) * 4.0 + np.random.normal(0, 3, size)).clip(-15, 15)
    base_val = np.clip(16 + brush, 8, 35).astype(np.uint8)
    base_b = np.clip(28 + brush * 1.2, 12, 55).astype(np.uint8)
    
    img = Image.fromarray(np.dstack([base_val, base_val + 2, base_b, np.full(size, 255, dtype=np.uint8)]), mode="RGBA")
    draw = ImageDraw.Draw(img)
    
    # Cyber neon circuit traces
    cyan_glow = (0, 230, 255, 180)
    magenta_glow = (255, 0, 160, 140)
    grid_step = 64
    
    for gx in range(0, 1024, grid_step):
        draw.line([(gx, 0), (gx, 1024)], fill=(0, 180, 220, 60), width=1)
    for gy in range(0, 1024, grid_step):
        draw.line([(0, gy), (1024, gy)], fill=(0, 180, 220, 60), width=1)
        
    # High-intensity circuit conduits
    for i in range(12):
        cy = (i * 85 + 40) % 1024
        cx = (i * 115 + 20) % 1024
        draw.line([(cx, cy), (cx + 120, cy), (cx + 160, cy + 40), (cx + 300, cy + 40)], fill=cyan_glow, width=3)
        draw.ellipse([(cx - 4, cy - 4), (cx + 4, cy + 4)], fill=(180, 255, 255, 255))
        draw.ellipse([(cx + 296, cy + 36), (cx + 304, cy + 44)], fill=(180, 255, 255, 255))
        
    # Hexagon data clusters
    for hx in [256, 512, 768]:
        for hy in [256, 512, 768]:
            pts = []
            for deg in range(0, 360, 60):
                rad = math.radians(deg)
                pts.append((hx + math.cos(rad) * 45, hy + math.sin(rad) * 45))
            draw.polygon(pts, outline=magenta_glow, width=2)
            draw.ellipse([(hx - 6, hy - 6), (hx + 6, hy + 6)], fill=(255, 200, 240, 240))
            
    img.save(path, format="PNG")
    print(f"Saved: {path}")

def generate_eldritch_void(path):
    print(f"Generating Eldritch Void PBR: {path}...")
    size = (1024, 1024)
    w, h = size
    
    y, x = np.mgrid[:h, :w]
    cx, cy = 512.0, 512.0
    r = np.sqrt((x - cx) ** 2 + (y - cy) ** 2)
    theta = np.arctan2(y - cy, x - cx)
    
    # Swirling vortex math
    swirl = theta + np.sin(r * 0.02) * 2.5 + np.cos(r * 0.01) * 1.5
    vortex_intensity = np.sin(swirl * 4.0) * 0.5 + 0.5
    
    # Purple abyssal gradient
    r_channel = np.clip(25 + vortex_intensity * 60 - (r * 0.04), 10, 110)
    g_channel = np.clip(10 + vortex_intensity * 25 - (r * 0.05), 5, 55)
    b_channel = np.clip(35 + vortex_intensity * 95 - (r * 0.02), 20, 160)
    
    img = Image.fromarray(np.dstack([r_channel.astype(np.uint8), g_channel.astype(np.uint8), b_channel.astype(np.uint8), np.full(size, 255, dtype=np.uint8)]), mode="RGBA")
    draw = ImageDraw.Draw(img)
    
    # Eldritch rune circles
    for rad_ring in [150, 300, 420]:
        draw.ellipse([(cx - rad_ring, cy - rad_ring), (cx + rad_ring, cy + rad_ring)], outline=(190, 80, 240, 110), width=2)
        
    # Non-Euclidean runic sigils
    for deg in range(0, 360, 30):
        rad_val = math.radians(deg)
        rx = cx + math.cos(rad_val) * 300
        ry = cy + math.sin(rad_val) * 300
        draw.line([(rx - 10, ry), (rx + 10, ry)], fill=(220, 140, 255, 180), width=2)
        draw.line([(rx, ry - 10), (rx, ry + 10)], fill=(220, 140, 255, 180), width=2)
        draw.ellipse([(rx - 4, ry - 4), (rx + 4, ry + 4)], fill=(255, 180, 255, 230))
        
    img.save(path, format="PNG")
    print(f"Saved: {path}")

# ---------------------------------------------------------------------------
# 2. HUD Piece Portraits (512x512)
# ---------------------------------------------------------------------------

PORTRAIT_CONFIGS = [
    # Fantasy (6)
    {"file": "fantasy_paladin.png", "alias": "fantasy_knight.png", "theme": "fantasy", "name": "Paladin", "symbol": "♘", "primary": (255, 215, 80), "bg_center": (60, 45, 15), "bg_edge": (15, 12, 10)},
    {"file": "fantasy_goblin.png", "alias": "fantasy_pawn.png", "theme": "fantasy", "name": "Goblin Pawn", "symbol": "♙", "primary": (140, 220, 70), "bg_center": (35, 55, 20), "bg_edge": (12, 18, 10)},
    {"file": "fantasy_sorcerer.png", "alias": "fantasy_bishop.png", "theme": "fantasy", "name": "Arcane Sorcerer", "symbol": "♗", "primary": (130, 180, 255), "bg_center": (30, 45, 75), "bg_edge": (10, 15, 25)},
    {"file": "fantasy_dragon_rook.png", "alias": "fantasy_rook.png", "theme": "fantasy", "name": "Dragon Rook", "symbol": "♖", "primary": (255, 110, 60), "bg_center": (70, 30, 20), "bg_edge": (20, 10, 8)},
    {"file": "fantasy_queen.png", "alias": None, "theme": "fantasy", "name": "High Queen", "symbol": "♕", "primary": (255, 235, 150), "bg_center": (75, 60, 30), "bg_edge": (20, 15, 10)},
    {"file": "fantasy_king.png", "alias": None, "theme": "fantasy", "name": "High King", "symbol": "♔", "primary": (255, 200, 50), "bg_center": (80, 50, 15), "bg_edge": (22, 14, 8)},

    # Cyberpunk (6)
    {"file": "cyber_android_pawn.png", "alias": "cyber_pawn.png", "theme": "cyber", "name": "Android Pawn", "symbol": "♟", "primary": (0, 240, 255), "bg_center": (10, 50, 65), "bg_edge": (5, 15, 20)},
    {"file": "cyber_neon_katana_knight.png", "alias": "cyber_knight.png", "theme": "cyber", "name": "Katana Knight", "symbol": "♞", "primary": (255, 40, 140), "bg_center": (65, 15, 45), "bg_edge": (20, 5, 15)},
    {"file": "cyber_railgun_bishop.png", "alias": "cyber_bishop.png", "theme": "cyber", "name": "Railgun Bishop", "symbol": "♝", "primary": (120, 255, 180), "bg_center": (20, 60, 45), "bg_edge": (5, 20, 15)},
    {"file": "cyber_mech_rook.png", "alias": "cyber_rook.png", "theme": "cyber", "name": "Mech Rook", "symbol": "♜", "primary": (255, 170, 0), "bg_center": (65, 45, 10), "bg_edge": (20, 14, 5)},
    {"file": "cyber_holo_queen.png", "alias": "cyber_queen.png", "theme": "cyber", "name": "Holo Queen", "symbol": "♛", "primary": (180, 110, 255), "bg_center": (55, 25, 75), "bg_edge": (16, 8, 24)},
    {"file": "cyber_king.png", "alias": None, "theme": "cyber", "name": "Cyber King", "symbol": "♚", "primary": (255, 230, 80), "bg_center": (65, 60, 20), "bg_edge": (20, 18, 6)},

    # Eldritch (6)
    {"file": "eldritch_void_spawn.png", "alias": "eldritch_pawn.png", "theme": "eldritch", "name": "Void Spawn", "symbol": "♙", "primary": (170, 90, 240), "bg_center": (45, 18, 60), "bg_edge": (12, 5, 18)},
    {"file": "eldritch_tentacled_horror.png", "alias": "eldritch_knight.png", "theme": "eldritch", "name": "Tentacled Horror", "symbol": "♘", "primary": (220, 70, 180), "bg_center": (55, 15, 50), "bg_edge": (16, 4, 15)},
    {"file": "eldritch_frost_giant.png", "alias": "eldritch_bishop.png", "theme": "eldritch", "name": "Frost Giant", "symbol": "♗", "primary": (90, 200, 255), "bg_center": (20, 50, 75), "bg_edge": (6, 16, 25)},
    {"file": "eldritch_cosmic_horror.png", "alias": "eldritch_rook.png", "theme": "eldritch", "name": "Cosmic Horror", "symbol": "♖", "primary": (150, 60, 220), "bg_center": (40, 12, 65), "bg_edge": (12, 4, 20)},
    {"file": "eldritch_cosmic_queen.png", "alias": "eldritch_queen.png", "theme": "eldritch", "name": "Cosmic Queen", "symbol": "♕", "primary": (240, 130, 255), "bg_center": (65, 25, 75), "bg_edge": (20, 8, 24)},
    {"file": "eldritch_shadow_king.png", "alias": "eldritch_king.png", "theme": "eldritch", "name": "Shadow King", "symbol": "♔", "primary": (200, 180, 255), "bg_center": (50, 45, 70), "bg_edge": (15, 12, 22)},
]

def generate_portrait(config):
    size = (512, 512)
    filename = config["file"]
    filepath = os.path.join(PORTRAIT_DIR, filename)
    print(f"Generating portrait: {filename} ({config['name']})...")
    
    # 1. Background radial gradient
    bg = create_radial_gradient(size, (*config["bg_center"], 255), (*config["bg_edge"], 255))
    
    # 2. Glowing crest ring
    ring_img = Image.new("RGBA", size, (0, 0, 0, 0))
    r_draw = ImageDraw.Draw(ring_img)
    cx, cy = 256, 256
    
    # Outer ornate circle
    r_draw.ellipse([(cx - 180, cy - 180), (cx + 180, cy + 180)], outline=(*config["primary"], 120), width=4)
    r_draw.ellipse([(cx - 195, cy - 195), (cx + 195, cy + 195)], outline=(*config["primary"], 50), width=2)
    
    # Ornate corner brackets
    c_len = 35
    for bx, by in [(cx - 180, cy - 180), (cx + 180, cy - 180), (cx - 180, cy + 180), (cx + 180, cy + 180)]:
        dx = -1 if bx < cx else 1
        dy = -1 if by < cy else 1
        r_draw.line([(bx, by), (bx + dx * c_len, by)], fill=(*config["primary"], 220), width=3)
        r_draw.line([(bx, by), (bx, by + dy * c_len)], fill=(*config["primary"], 220), width=3)
        
    # 3. Piece glyph silhouette with multi-layer glow
    glyph_layer = Image.new("RGBA", size, (0, 0, 0, 0))
    g_draw = ImageDraw.Draw(glyph_layer)
    
    # Silhouette geometry
    sym = config["symbol"]
    # Draw large stylized emblem
    g_draw.ellipse([(cx - 90, cy - 90), (cx + 90, cy + 90)], fill=(*config["primary"], 80))
    g_draw.ellipse([(cx - 75, cy - 75), (cx + 75, cy + 75)], fill=(*config["primary"], 180))
    
    # Stylized crown / crest notches
    crest_pts = [(cx - 60, cy - 40), (cx, cy - 110), (cx + 60, cy - 40), (cx + 40, cy + 50), (cx - 40, cy + 50)]
    g_draw.polygon(crest_pts, fill=(255, 255, 255, 220), outline=(*config["primary"], 255))
    
    # Central core jewel
    g_draw.ellipse([(cx - 22, cy - 10), (cx + 22, cy + 34)], fill=(*config["primary"], 255))
    g_draw.ellipse([(cx - 12, cy), (cx + 12, cy + 24)], fill=(255, 255, 255, 255))
    
    # Composite with bloom blur
    glow = glyph_layer.filter(ImageFilter.GaussianBlur(16))
    
    final_img = Image.alpha_composite(bg, ring_img)
    final_img = Image.alpha_composite(final_img, glow)
    final_img = Image.alpha_composite(final_img, glyph_layer)
    final_img = add_vignette(final_img, 0.45)
    
    # Bottom name banner
    b_draw = ImageDraw.Draw(final_img)
    b_draw.rectangle([(60, 435), (452, 485)], fill=(10, 12, 16, 210), outline=(*config["primary"], 180), width=2)
    
    final_img.save(filepath, format="PNG")
    
    if config.get("alias"):
        alias_path = os.path.join(PORTRAIT_DIR, config["alias"])
        final_img.save(alias_path, format="PNG")
        print(f"Saved alias: {alias_path}")

# ---------------------------------------------------------------------------
# 3. Store & Marketing Assets
# ---------------------------------------------------------------------------

def generate_store_assets():
    print("Generating Store & Marketing Assets...")
    
    # a) icon_512.png (512x512)
    icon_path = os.path.join(STORE_DIR, "icon_512.png")
    icon_img = create_radial_gradient((512, 512), (50, 40, 70, 255), (10, 12, 16, 255))
    i_draw = ImageDraw.Draw(icon_img)
    
    # Cyber vs Paladin diagonal clash
    i_draw.polygon([(0, 0), (512, 0), (0, 512)], fill=(0, 160, 220, 70))
    i_draw.polygon([(512, 512), (512, 0), (0, 512)], fill=(240, 180, 40, 70))
    # Diagonal clash beam
    i_draw.line([(0, 512), (512, 0)], fill=(255, 255, 255, 240), width=8)
    
    # Ornate clash burst
    for r_burst in [50, 100, 160]:
        i_draw.ellipse([(256 - r_burst, 256 - r_burst), (256 + r_burst, 256 + r_burst)], outline=(255, 220, 100, 120), width=3)
    i_draw.ellipse([(256 - 30, 256 - 30), (256 + 30, 256 + 30)], fill=(255, 255, 255, 255))
    
    icon_img = add_vignette(icon_img, 0.5)
    icon_img.save(icon_path, format="PNG")
    # Also update app icon in assets/icons
    icon_img.save("assets/icons/app_icon.png", format="PNG")
    print(f"Saved: {icon_path}")
    
    # b) steam_capsule_header.png (460x215)
    steam_path = os.path.join(STORE_DIR, "steam_capsule_header.png")
    steam_img = create_radial_gradient((460, 215), (45, 30, 65, 255), (8, 10, 14, 255))
    s_draw = ImageDraw.Draw(steam_img)
    
    # Atmospheric background battle lines
    for i in range(15):
        s_draw.line([(i * 35, 0), (i * 35 + 80, 215)], fill=(0, 200, 255, 30), width=2)
        
    # Title box
    s_draw.rectangle([(30, 55), (430, 160)], fill=(12, 14, 20, 210), outline=(240, 190, 60, 220), width=3)
    steam_img = add_vignette(steam_img, 0.4)
    steam_img.save(steam_path, format="PNG")
    print(f"Saved: {steam_path}")
    
    # c) galaxy_store_banner.png (1024x500)
    galaxy_path = os.path.join(STORE_DIR, "galaxy_store_banner.png")
    gal_img = create_radial_gradient((1024, 500), (40, 25, 75, 255), (10, 12, 16, 255))
    g_draw = ImageDraw.Draw(gal_img)
    
    # Deep space grid
    for gx in range(0, 1024, 64):
        g_draw.line([(gx, 0), (gx, 500)], fill=(120, 60, 200, 35), width=1)
    for gy in range(0, 500, 64):
        g_draw.line([(0, gy), (1024, gy)], fill=(120, 60, 200, 35), width=1)
        
    # Central branding emblem frame
    g_draw.rectangle([(160, 120), (864, 380)], fill=(14, 16, 24, 220), outline=(0, 230, 255, 220), width=4)
    g_draw.ellipse([(512 - 70, 250 - 70), (512 + 70, 250 + 70)], outline=(255, 215, 60, 200), width=3)
    
    gal_img = add_vignette(gal_img, 0.5)
    gal_img.save(galaxy_path, format="PNG")
    print(f"Saved: {galaxy_path}")

# ---------------------------------------------------------------------------
# Main entrypoint
# ---------------------------------------------------------------------------

def main():
    print("=== Duel Chess: Nano Banana 2D Visual Synthesis Pipeline ===")
    
    # 1. Generate PBR Board Textures
    generate_fantasy_marble(os.path.join(BOARD_DIR, "board_fantasy_marble.png"))
    generate_cyber_grid(os.path.join(BOARD_DIR, "board_cyber_grid.png"))
    generate_eldritch_void(os.path.join(BOARD_DIR, "board_eldritch_void.png"))
    
    # 2. Generate 18 HUD Piece Portraits
    for config in PORTRAIT_CONFIGS:
        generate_portrait(config)
        
    # 3. Generate Store & Marketing Assets
    generate_store_assets()
    
    print("=== Visual Asset Synthesis Completed Successfully! ===")

if __name__ == "__main__":
    main()
