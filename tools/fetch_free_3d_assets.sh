#!/usr/bin/env bash
# ==============================================================================
# Duel Chess: Reborn - 3D Asset & Skeleton Pipeline Fetcher & Generator
# Theme Coverage: Fantasy, Cyberpunk, Eldritch
# CC0 / Open Source Character & Creature Models
# ==============================================================================

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"

MODELS_DIR="${PROJECT_ROOT}/assets/models"
FANTASY_DIR="${MODELS_DIR}/fantasy"
CYBERPUNK_DIR="${MODELS_DIR}/cyberpunk"
ELDRITCH_DIR="${MODELS_DIR}/eldritch"

echo "============================================================"
echo " Duel Chess: Reborn - 3D Asset & Skeleton Pipeline"
echo " Target Directory: ${MODELS_DIR}"
echo "============================================================"

# Step 1: Ensure directory structure
echo "[1/4] Setting up directory hierarchy..."
mkdir -p "${FANTASY_DIR}"
mkdir -p "${CYBERPUNK_DIR}"
mkdir -p "${ELDRITCH_DIR}"

# Provide high_fantasy compatibility symlink
if [ ! -e "${MODELS_DIR}/high_fantasy" ]; then
    ln -sfn fantasy "${MODELS_DIR}/high_fantasy"
fi
echo "  ✓ Directory structure created: fantasy, cyberpunk, eldritch"

# Step 2: Generate / Fetch CC0 3D Models
echo "[2/4] Generating & populating CC0 binary .glb models..."
if command -v python3 >/dev/null 2>&1; then
    python3 "${SCRIPT_DIR}/generate_3d_assets.py" "${MODELS_DIR}"
else
    echo "ERROR: python3 is required to generate/validate 3D GLB assets."
    exit 1
fi

# Step 3: Write CC0 License and Metadata
echo "[3/4] Writing CC0 licensing & asset metadata..."
cat << 'LICENSE_EOF' > "${MODELS_DIR}/LICENSE_CC0.md"
# 3D Model Assets License - CC0 1.0 Universal (Public Domain)

The 3D piece models included in `assets/models/{fantasy,cyberpunk,eldritch}/` are 
dedicated to the public domain under the Creative Commons CC0 1.0 Universal license.

You can copy, modify, distribute, and perform the work, even for commercial purposes,
all without asking permission.

### Included Themes & Meshes:
- **Fantasy**: Paladin (Pawn), Goblin (Knight), Sorcerer (Bishop), Dragon Rook (Rook), High Queen, High King
- **Cyberpunk**: Android Pawn, Neon Katana Knight, Railgun Bishop, Cyber Mech Rook, Holo Queen, Cyber King
- **Eldritch**: Cultist (Pawn), Frost Giant (Knight), Cosmic Horror (Bishop), Void Spawn (Rook), Cosmic Queen, Shadow King

All models are formatted as glTF 2.0 Binary (.glb) standard meshes with PBR materials.
LICENSE_EOF
echo "  ✓ LICENSE_CC0.md created."

# Step 4: Strict Verification of all GLB assets
echo "[4/4] Verifying all binary .glb assets across themes..."
python3 - << 'PY_VERIFY_EOF'
import os
import sys
import struct
import json

base_dir = "assets/models"
themes = ["fantasy", "cyberpunk", "eldritch"]

expected_pieces = {
    "fantasy": [
        "paladin.glb", "goblin.glb", "sorcerer.glb", "dragon_rook.glb", "queen.glb", "king.glb",
        "pawn.glb", "knight.glb", "bishop.glb", "rook.glb"
    ],
    "cyberpunk": [
        "android_pawn.glb", "neon_katana_knight.glb", "railgun_bishop.glb", "cyber_mech_rook.glb",
        "holo_queen.glb", "cyber_king.glb", "pawn.glb", "knight.glb", "bishop.glb", "rook.glb", "queen.glb", "king.glb"
    ],
    "eldritch": [
        "cultist.glb", "frost_giant.glb", "cosmic_horror.glb", "void_spawn.glb", "cosmic_queen.glb",
        "shadow_king.glb", "pawn.glb", "knight.glb", "bishop.glb", "rook.glb", "queen.glb", "king.glb"
    ]
}

total_checked = 0
failed = 0

for theme in themes:
    tdir = os.path.join(base_dir, theme)
    print(f"\nVerifying Theme: {theme.upper()} ({tdir})")
    for piece_file in expected_pieces[theme]:
        fpath = os.path.join(tdir, piece_file)
        total_checked += 1
        if not os.path.exists(fpath):
            print(f"  ✗ MISSING: {piece_file}")
            failed += 1
            continue
        
        size = os.path.getsize(fpath)
        with open(fpath, "rb") as f:
            header = f.read(12)
            if len(header) < 12:
                print(f"  ✗ TRUNCATED: {piece_file}")
                failed += 1
                continue
            magic, ver, total_len = struct.unpack("<4sII", header)
            if magic != b"glTF":
                print(f"  ✗ INVALID MAGIC: {piece_file} ({magic})")
                failed += 1
                continue
            if ver != 2:
                print(f"  ✗ INVALID VERSION: {piece_file} (ver {ver})")
                failed += 1
                continue
            if total_len != size:
                print(f"  ✗ SIZE MISMATCH: {piece_file} (header={total_len}, actual={size})")
                failed += 1
                continue
            
            # Check JSON chunk
            chunk_header = f.read(8)
            c_len, c_type = struct.unpack("<II", chunk_header)
            if c_type != 0x4E4F534A: # JSON
                print(f"  ✗ INVALID CHUNK 0: {piece_file}")
                failed += 1
                continue
            json_bytes = f.read(c_len)
            gltf = json.loads(json_bytes.decode("utf-8"))
            if gltf.get("asset", {}).get("version") != "2.0":
                print(f"  ✗ BAD GLTF VERSION: {piece_file}")
                failed += 1
                continue
            
            node_name = gltf.get("nodes", [{}])[0].get("name", "Unknown")
            prim_count = len(gltf.get("meshes", [{}])[0].get("primitives", []))
            print(f"  ✓ {piece_file:<24} | Node: {node_name:<20} | Primitives: {prim_count} | Size: {size/1024:.1f} KB")

print("\n" + "=" * 60)
if failed == 0:
    print(f"ALL {total_checked} GLB ASSETS SUCCESSFULLY VERIFIED!")
    print("=" * 60)
    sys.exit(0)
else:
    print(f"VERIFICATION FAILED: {failed}/{total_checked} files failed.")
    print("=" * 60)
    sys.exit(1)
PY_VERIFY_EOF

echo ""
echo "3D Asset Pipeline execution complete!"
