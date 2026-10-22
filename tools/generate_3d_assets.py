#!/usr/bin/env python3
"""
Duel Chess: Reborn - 3D Asset & Skeleton Pipeline Generator
Generates CC0-compliant, valid binary .glb 3D meshes for all chess pieces across 3 themes:
  - Fantasy: Paladin, Goblin, Sorcerer, Dragon Rook, Queen, King
  - Cyberpunk: Android Pawn, Neon Katana Knight, Railgun Bishop, Cyber Mech Rook, Holo Queen, Cyber King
  - Eldritch: Cultist, Frost Giant, Cosmic Horror, Void Spawn, Cosmic Queen, Shadow King
"""

import os
import sys
import math
import struct
import json

class MeshBuilder:
    def __init__(self):
        self.parts = {} # mat_idx -> {'verts': [], 'norms': [], 'indices': []}

    def _ensure(self, mat_idx):
        if mat_idx not in self.parts:
            self.parts[mat_idx] = {'verts': [], 'norms': [], 'indices': []}
        return self.parts[mat_idx]

    def add_quad(self, mat_idx, v0, v1, v2, v3, n):
        p = self._ensure(mat_idx)
        start = len(p['verts'])
        p['verts'].extend([v0, v1, v2, v3])
        p['norms'].extend([n, n, n, n])
        p['indices'].extend([start, start+1, start+2, start, start+2, start+3])

    def add_tri(self, mat_idx, v0, v1, v2, n):
        p = self._ensure(mat_idx)
        start = len(p['verts'])
        p['verts'].extend([v0, v1, v2])
        p['norms'].extend([n, n, n])
        p['indices'].extend([start, start+1, start+2])

def rot_point(p, rx=0, ry=0, rz=0):
    x, y, z = p
    if rx != 0:
        c, s = math.cos(rx), math.sin(rx)
        y, z = y * c - z * s, y * s + z * c
    if ry != 0:
        c, s = math.cos(ry), math.sin(ry)
        x, z = x * c + z * s, -x * s + z * c
    if rz != 0:
        c, s = math.cos(rz), math.sin(rz)
        x, y = x * c - y * s, x * s + y * c
    return (x, y, z)

def normalize(v):
    l = math.sqrt(v[0]**2 + v[1]**2 + v[2]**2)
    if l == 0: return (0.0, 1.0, 0.0)
    return (v[0]/l, v[1]/l, v[2]/l)

def add_box(mb, mat_idx, cx, cy, cz, wx, wy, wz, rx=0, ry=0, rz=0):
    hx, hy, hz = wx/2.0, wy/2.0, wz/2.0
    faces = [
        ([(-hx, -hy, hz), (hx, -hy, hz), (hx, hy, hz), (-hx, hy, hz)], (0.0, 0.0, 1.0)),
        ([(hx, -hy, -hz), (-hx, -hy, -hz), (-hx, hy, -hz), (hx, hy, -hz)], (0.0, 0.0, -1.0)),
        ([(hx, -hy, hz), (hx, -hy, -hz), (hx, hy, -hz), (hx, hy, hz)], (1.0, 0.0, 0.0)),
        ([(-hx, -hy, -hz), (-hx, -hy, hz), (-hx, hy, hz), (-hx, hy, -hz)], (-1.0, 0.0, 0.0)),
        ([(-hx, hy, hz), (hx, hy, hz), (hx, hy, -hz), (-hx, hy, -hz)], (0.0, 1.0, 0.0)),
        ([(-hx, -hy, -hz), (hx, -hy, -hz), (hx, -hy, hz), (-hx, -hy, hz)], (0.0, -1.0, 0.0)),
    ]
    for pts, norm in faces:
        t_pts = []
        for pt in pts:
            rp = rot_point(pt, rx, ry, rz)
            t_pts.append((cx + rp[0], cy + rp[1], cz + rp[2]))
        rn = rot_point(norm, rx, ry, rz)
        mb.add_quad(mat_idx, t_pts[0], t_pts[1], t_pts[2], t_pts[3], rn)

def add_cylinder(mb, mat_idx, cx, cy, cz, r_bot, r_top, h, segs=12, capped=True, rx=0, ry=0, rz=0):
    half_h = h / 2.0
    angles = [2.0 * math.pi * i / segs for i in range(segs)]
    slope_y = (r_bot - r_top) / h if h > 0 else 0.0
    for i in range(segs):
        next_i = (i + 1) % segs
        a0, a1 = angles[i], angles[next_i]
        c0, s0 = math.cos(a0), math.sin(a0)
        c1, s1 = math.cos(a1), math.sin(a1)
        b0 = rot_point((c0 * r_bot, -half_h, s0 * r_bot), rx, ry, rz)
        b1 = rot_point((c1 * r_bot, -half_h, s1 * r_bot), rx, ry, rz)
        t1 = rot_point((c1 * r_top, half_h, s1 * r_top), rx, ry, rz)
        t0 = rot_point((c0 * r_top, half_h, s0 * r_top), rx, ry, rz)
        n0 = rot_point(normalize((c0, slope_y, s0)), rx, ry, rz)
        n1 = rot_point(normalize((c1, slope_y, s1)), rx, ry, rz)
        p = mb._ensure(mat_idx)
        start = len(p['verts'])
        p['verts'].extend([
            (cx + b0[0], cy + b0[1], cz + b0[2]),
            (cx + b1[0], cy + b1[1], cz + b1[2]),
            (cx + t1[0], cy + t1[1], cz + t1[2]),
            (cx + t0[0], cy + t0[1], cz + t0[2])
        ])
        p['norms'].extend([n0, n1, n1, n0])
        p['indices'].extend([start, start+1, start+2, start, start+2, start+3])
    if capped:
        n_up = rot_point((0.0, 1.0, 0.0), rx, ry, rz)
        top_center = rot_point((0.0, half_h, 0.0), rx, ry, rz)
        tc_world = (cx + top_center[0], cy + top_center[1], cz + top_center[2])
        for i in range(segs):
            next_i = (i + 1) % segs
            a0, a1 = angles[i], angles[next_i]
            t0 = rot_point((math.cos(a0) * r_top, half_h, math.sin(a0) * r_top), rx, ry, rz)
            t1 = rot_point((math.cos(a1) * r_top, half_h, math.sin(a1) * r_top), rx, ry, rz)
            mb.add_tri(mat_idx, tc_world, (cx + t0[0], cy + t0[1], cz + t0[2]), (cx + t1[0], cy + t1[1], cz + t1[2]), n_up)
        n_down = rot_point((0.0, -1.0, 0.0), rx, ry, rz)
        bot_center = rot_point((0.0, -half_h, 0.0), rx, ry, rz)
        bc_world = (cx + bot_center[0], cy + bot_center[1], cz + bot_center[2])
        for i in range(segs):
            next_i = (i + 1) % segs
            a0, a1 = angles[i], angles[next_i]
            b0 = rot_point((math.cos(a0) * r_bot, -half_h, math.sin(a0) * r_bot), rx, ry, rz)
            b1 = rot_point((math.cos(a1) * r_bot, -half_h, math.sin(a1) * r_bot), rx, ry, rz)
            mb.add_tri(mat_idx, bc_world, (cx + b1[0], cy + b1[1], cz + b1[2]), (cx + b0[0], cy + b0[1], cz + b0[2]), n_down)

def add_cone(mb, mat_idx, cx, cy, cz, r_base, h, segs=12, capped=True, rx=0, ry=0, rz=0):
    half_h = h / 2.0
    angles = [2.0 * math.pi * i / segs for i in range(segs)]
    tip_local = (0.0, half_h, 0.0)
    tip = rot_point(tip_local, rx, ry, rz)
    tip_world = (cx + tip[0], cy + tip[1], cz + tip[2])
    slope_y = r_base / h if h > 0 else 0.0
    for i in range(segs):
        next_i = (i + 1) % segs
        a0, a1 = angles[i], angles[next_i]
        c0, s0 = math.cos(a0), math.sin(a0)
        c1, s1 = math.cos(a1), math.sin(a1)
        b0 = rot_point((c0 * r_base, -half_h, s0 * r_base), rx, ry, rz)
        b1 = rot_point((c1 * r_base, -half_h, s1 * r_base), rx, ry, rz)
        mid_a = (a0 + a1) / 2.0
        n_side = rot_point(normalize((math.cos(mid_a), slope_y, math.sin(mid_a))), rx, ry, rz)
        mb.add_tri(mat_idx, (cx + b0[0], cy + b0[1], cz + b0[2]), (cx + b1[0], cy + b1[1], cz + b1[2]), tip_world, n_side)
    if capped:
        n_down = rot_point((0.0, -1.0, 0.0), rx, ry, rz)
        bot_center = rot_point((0.0, -half_h, 0.0), rx, ry, rz)
        bc_world = (cx + bot_center[0], cy + bot_center[1], cz + bot_center[2])
        for i in range(segs):
            next_i = (i + 1) % segs
            a0, a1 = angles[i], angles[next_i]
            b0 = rot_point((math.cos(a0) * r_base, -half_h, math.sin(a0) * r_base), rx, ry, rz)
            b1 = rot_point((math.cos(a1) * r_base, -half_h, math.sin(a1) * r_base), rx, ry, rz)
            mb.add_tri(mat_idx, bc_world, (cx + b1[0], cy + b1[1], cz + b1[2]), (cx + b0[0], cy + b0[1], cz + b0[2]), n_down)

def add_sphere(mb, mat_idx, cx, cy, cz, r, rings=8, segs=12):
    p = mb._ensure(mat_idx)
    grid = []
    for i in range(rings + 1):
        row = []
        phi = math.pi * i / rings
        y = math.cos(phi) * r
        r_ring = math.sin(phi) * r
        for j in range(segs):
            theta = 2.0 * math.pi * j / segs
            x = math.cos(theta) * r_ring
            z = math.sin(theta) * r_ring
            norm = (x/r, y/r, z/r) if r > 0 else (0.0, 1.0, 0.0)
            row.append(((cx + x, cy + y, cz + z), norm))
        grid.append(row)
    for i in range(rings):
        for j in range(segs):
            next_j = (j + 1) % segs
            v0, n0 = grid[i][j]
            v1, n1 = grid[i+1][j]
            v2, n2 = grid[i+1][next_j]
            v3, n3 = grid[i][next_j]
            start = len(p['verts'])
            p['verts'].extend([v0, v1, v2, v3])
            p['norms'].extend([n0, n1, n2, n3])
            p['indices'].extend([start, start+1, start+2, start, start+2, start+3])

def add_ring(mb, mat_idx, cx, cy, cz, r_major, r_minor, segs=14, tube_segs=8, rx=0, ry=0, rz=0):
    p = mb._ensure(mat_idx)
    grid = []
    for i in range(segs):
        row = []
        u = 2.0 * math.pi * i / segs
        cu, su = math.cos(u), math.sin(u)
        for j in range(tube_segs):
            v = 2.0 * math.pi * j / tube_segs
            cv, sv = math.cos(v), math.sin(v)
            pt = rot_point(((r_major + r_minor * cv) * cu, r_minor * sv, (r_major + r_minor * cv) * su), rx, ry, rz)
            norm = rot_point((cv * cu, sv, cv * su), rx, ry, rz)
            row.append(((cx + pt[0], cy + pt[1], cz + pt[2]), norm))
        grid.append(row)
    for i in range(segs):
        next_i = (i + 1) % segs
        for j in range(tube_segs):
            next_j = (j + 1) % tube_segs
            v0, n0 = grid[i][j]
            v1, n1 = grid[next_i][j]
            v2, n2 = grid[next_i][next_j]
            v3, n3 = grid[i][next_j]
            start = len(p['verts'])
            p['verts'].extend([v0, v1, v2, v3])
            p['norms'].extend([n0, n1, n2, n3])
            p['indices'].extend([start, start+1, start+2, start, start+2, start+3])

def export_glb(builder, materials, output_path, model_name="Piece"):
    bin_chunks = []
    accessors = []
    buffer_views = []
    primitives = []
    curr_offset = 0

    sorted_mats = sorted(builder.parts.keys())
    for mat_idx in sorted_mats:
        part = builder.parts[mat_idx]
        verts = part['verts']
        norms = part['norms']
        indices = part['indices']
        if not verts or not indices:
            continue

        v_data = []
        min_p = [float('inf')]*3
        max_p = [float('-inf')]*3
        for v in verts:
            v_data.extend(v)
            for k in range(3):
                min_p[k] = min(min_p[k], v[k])
                max_p[k] = max(max_p[k], v[k])

        pos_bytes = struct.pack(f'<{len(v_data)}f', *v_data)
        while len(pos_bytes) % 4 != 0:
            pos_bytes += b'\x00'

        bv_pos_idx = len(buffer_views)
        buffer_views.append({
            'buffer': 0,
            'byteOffset': curr_offset,
            'byteLength': len(pos_bytes),
            'target': 34962
        })
        curr_offset += len(pos_bytes)
        bin_chunks.append(pos_bytes)

        acc_pos_idx = len(accessors)
        accessors.append({
            'bufferView': bv_pos_idx,
            'byteOffset': 0,
            'componentType': 5126,
            'count': len(verts),
            'type': 'VEC3',
            'min': min_p,
            'max': max_p
        })

        n_data = []
        for n in norms:
            n_data.extend(n)
        norm_bytes = struct.pack(f'<{len(n_data)}f', *n_data)
        while len(norm_bytes) % 4 != 0:
            norm_bytes += b'\x00'

        bv_norm_idx = len(buffer_views)
        buffer_views.append({
            'buffer': 0,
            'byteOffset': curr_offset,
            'byteLength': len(norm_bytes),
            'target': 34962
        })
        curr_offset += len(norm_bytes)
        bin_chunks.append(norm_bytes)

        acc_norm_idx = len(accessors)
        accessors.append({
            'bufferView': bv_norm_idx,
            'byteOffset': 0,
            'componentType': 5126,
            'count': len(norms),
            'type': 'VEC3',
            'min': [-1.0, -1.0, -1.0],
            'max': [1.0, 1.0, 1.0]
        })

        idx_bytes = struct.pack(f'<{len(indices)}I', *indices)
        while len(idx_bytes) % 4 != 0:
            idx_bytes += b'\x00'

        bv_idx_idx = len(buffer_views)
        buffer_views.append({
            'buffer': 0,
            'byteOffset': curr_offset,
            'byteLength': len(idx_bytes),
            'target': 34963
        })
        curr_offset += len(idx_bytes)
        bin_chunks.append(idx_bytes)

        acc_idx_idx = len(accessors)
        accessors.append({
            'bufferView': bv_idx_idx,
            'byteOffset': 0,
            'componentType': 5125,
            'count': len(indices),
            'type': 'SCALAR',
            'min': [min(indices)],
            'max': [max(indices)]
        })

        primitives.append({
            'attributes': {
                'POSITION': acc_pos_idx,
                'NORMAL': acc_norm_idx
            },
            'indices': acc_idx_idx,
            'material': mat_idx
        })

    full_bin = b''.join(bin_chunks)
    pad_bin = (4 - (len(full_bin) % 4)) % 4
    full_bin += b'\x00' * pad_bin

    gltf = {
        'asset': {'version': '2.0', 'generator': 'BattleChessReborn 3D Model Pipeline'},
        'scene': 0,
        'scenes': [{'name': 'Scene', 'nodes': [0]}],
        'nodes': [{'name': model_name, 'mesh': 0}],
        'meshes': [{'name': model_name, 'primitives': primitives}],
        'materials': materials,
        'accessors': accessors,
        'bufferViews': buffer_views,
        'buffers': [{'byteLength': len(full_bin)}]
    }

    json_bytes = json.dumps(gltf, separators=(',', ':')).encode('utf-8')
    pad_json = (4 - (len(json_bytes) % 4)) % 4
    json_bytes += b' ' * pad_json

    total_len = 12 + 8 + len(json_bytes) + 8 + len(full_bin)
    header = struct.pack('<4sII', b'glTF', 2, total_len)
    json_chunk = struct.pack('<II', len(json_bytes), 0x4E4F534A) + json_bytes
    bin_chunk = struct.pack('<II', len(full_bin), 0x004E4942) + full_bin

    os.makedirs(os.path.dirname(os.path.abspath(output_path)), exist_ok=True)
    with open(output_path, 'wb') as f:
        f.write(header + json_chunk + bin_chunk)

print("Generator module loaded successfully")

# ==========================================
# 1. FANTASY THEME MODELS
# ==========================================
FANTASY_MATERIALS = [
    # 0: Polished Steel
    {'name': 'PolishedSteel', 'pbrMetallicRoughness': {'baseColorFactor': [0.85, 0.88, 0.92, 1.0], 'metallicFactor': 0.82, 'roughnessFactor': 0.25}},
    # 1: Imperial Gold Trim
    {'name': 'ImperialGold', 'pbrMetallicRoughness': {'baseColorFactor': [0.98, 0.80, 0.22, 1.0], 'metallicFactor': 0.90, 'roughnessFactor': 0.20}},
    # 2: Royal Blue Fabric / Mantle
    {'name': 'RoyalBlueMantle', 'pbrMetallicRoughness': {'baseColorFactor': [0.12, 0.25, 0.72, 1.0], 'metallicFactor': 0.10, 'roughnessFactor': 0.75}},
    # 3: Deep Red Ermine / Gemstone
    {'name': 'RoyalCrimson', 'pbrMetallicRoughness': {'baseColorFactor': [0.72, 0.08, 0.14, 1.0], 'metallicFactor': 0.15, 'roughnessFactor': 0.65}}
]

def add_fantasy_pedestal(mb):
    # Plinth base
    add_cylinder(mb, 0, 0.0, 0.06, 0.0, 0.42, 0.38, 0.12, segs=16)
    add_cylinder(mb, 1, 0.0, 0.13, 0.0, 0.39, 0.36, 0.03, segs=16)

def build_fantasy_paladin(mb):
    add_fantasy_pedestal(mb)
    # Legs
    add_cylinder(mb, 0, -0.11, 0.32, 0.0, 0.08, 0.07, 0.32, segs=10)
    add_cylinder(mb, 0, 0.11, 0.32, 0.0, 0.08, 0.07, 0.32, segs=10)
    # Pelvis & blue tabard
    add_box(mb, 2, 0.0, 0.50, 0.0, 0.30, 0.18, 0.22)
    # Steel breastplate
    add_box(mb, 0, 0.0, 0.68, 0.0, 0.34, 0.24, 0.24)
    # Gold pectoral cross
    add_box(mb, 1, 0.0, 0.70, 0.13, 0.06, 0.18, 0.02)
    add_box(mb, 1, 0.0, 0.72, 0.13, 0.18, 0.06, 0.02)
    # Pauldrons
    add_box(mb, 0, -0.24, 0.78, 0.0, 0.14, 0.12, 0.20, rz=0.25)
    add_box(mb, 0, 0.24, 0.78, 0.0, 0.14, 0.12, 0.20, rz=-0.25)
    add_box(mb, 1, -0.24, 0.81, 0.0, 0.15, 0.04, 0.21, rz=0.25)
    add_box(mb, 1, 0.24, 0.81, 0.0, 0.15, 0.04, 0.21, rz=-0.25)
    # Great helm
    add_cylinder(mb, 0, 0.0, 0.95, 0.0, 0.14, 0.13, 0.20, segs=12)
    add_box(mb, 1, 0.0, 1.07, 0.0, 0.04, 0.08, 0.22)
    # Helm eye slit
    add_box(mb, 3, 0.0, 0.96, 0.13, 0.16, 0.03, 0.02)
    # Right arm & spear
    add_box(mb, 0, 0.24, 0.60, 0.05, 0.08, 0.22, 0.08)
    add_cylinder(mb, 1, 0.27, 0.75, 0.14, 0.02, 0.02, 1.35, segs=8)
    add_cone(mb, 0, 0.27, 1.48, 0.14, 0.06, 0.20, segs=8)
    # Left arm & kite shield
    add_box(mb, 0, -0.24, 0.60, 0.05, 0.08, 0.22, 0.08)
    add_box(mb, 2, -0.30, 0.62, 0.12, 0.04, 0.42, 0.26, ry=0.2)
    add_box(mb, 1, -0.32, 0.64, 0.12, 0.02, 0.32, 0.05, ry=0.2)
    add_box(mb, 1, -0.32, 0.68, 0.12, 0.02, 0.05, 0.18, ry=0.2)

def build_fantasy_goblin(mb):
    add_fantasy_pedestal(mb)
    # Crouched nimble legs
    add_cylinder(mb, 2, -0.12, 0.26, -0.05, 0.07, 0.06, 0.24, rx=0.4)
    add_cylinder(mb, 2, 0.12, 0.26, -0.05, 0.07, 0.06, 0.24, rx=0.4)
    # Forward-hunched torso
    add_box(mb, 0, 0.0, 0.46, 0.06, 0.28, 0.26, 0.22, rx=0.35)
    # Pointed goblin head jutting forward
    add_box(mb, 0, 0.0, 0.68, 0.18, 0.22, 0.20, 0.20, rx=0.15)
    # Large pointed ears
    add_cone(mb, 0, -0.20, 0.72, 0.16, 0.06, 0.24, rz=1.2, rx=0.2)
    add_cone(mb, 0, 0.20, 0.72, 0.16, 0.06, 0.24, rz=-1.2, rx=0.2)
    # Snout / chin
    add_cone(mb, 0, 0.0, 0.64, 0.32, 0.05, 0.12, rx=-1.4)
    # Glowing predatory yellow eyes
    add_sphere(mb, 1, -0.06, 0.70, 0.28, 0.035)
    add_sphere(mb, 1, 0.06, 0.70, 0.28, 0.035)
    # Dual curved jagged scimitars
    add_box(mb, 0, 0.25, 0.68, 0.16, 0.03, 0.40, 0.07, rx=0.45, rz=-0.3)
    add_box(mb, 0, -0.25, 0.48, -0.04, 0.03, 0.36, 0.06, rx=-0.5, rz=0.25)
    # Spiked leather pauldrons
    add_cone(mb, 1, -0.18, 0.58, 0.04, 0.05, 0.12, rz=0.7)
    add_cone(mb, 1, 0.18, 0.58, 0.04, 0.05, 0.12, rz=-0.7)

def build_fantasy_sorcerer(mb):
    add_fantasy_pedestal(mb)
    # Cascading flowing wizard robe
    add_cylinder(mb, 2, 0.0, 0.38, 0.0, 0.34, 0.22, 0.50, segs=14)
    add_cylinder(mb, 2, 0.0, 0.72, 0.0, 0.22, 0.17, 0.34, segs=12)
    # Gold decorative hem & sash
    add_box(mb, 1, 0.0, 0.45, 0.22, 0.06, 0.55, 0.02)
    # Sorcerer head & beard
    add_sphere(mb, 0, 0.0, 0.96, 0.0, 0.13)
    # Conical wizard hat with wide brim
    add_cylinder(mb, 2, 0.0, 1.04, 0.0, 0.28, 0.28, 0.03, segs=14)
    add_cone(mb, 2, 0.0, 1.28, -0.04, 0.19, 0.46, segs=12, rx=-0.22)
    add_cylinder(mb, 1, 0.0, 1.07, 0.0, 0.20, 0.18, 0.04, segs=12)
    # Arcane darkwood staff with crescent prongs
    add_cylinder(mb, 0, 0.26, 0.78, 0.12, 0.025, 0.025, 1.40, segs=8)
    add_cylinder(mb, 1, 0.26, 1.50, 0.12, 0.11, 0.11, 0.03, segs=10, rx=1.57)
    # Floating glowing magical orb
    add_sphere(mb, 1, 0.26, 1.55, 0.12, 0.09, rings=8, segs=12)
    # Grimoire spellbook at hip
    add_box(mb, 3, -0.25, 0.65, 0.12, 0.20, 0.26, 0.06, ry=0.4, rx=0.2)
    add_box(mb, 1, -0.25, 0.65, 0.12, 0.18, 0.24, 0.04, ry=0.4, rx=0.2)

def build_fantasy_dragon_rook(mb):
    # Fortified octagonal bastion
    add_cylinder(mb, 0, 0.0, 0.08, 0.0, 0.46, 0.44, 0.16, segs=8)
    add_cylinder(mb, 0, 0.0, 0.60, 0.0, 0.38, 0.33, 0.90, segs=8)
    add_cylinder(mb, 0, 0.0, 1.10, 0.0, 0.33, 0.42, 0.12, segs=8)
    # 4 corner crenellated battlements
    for ox, oz in [(-0.30, -0.30), (0.30, -0.30), (-0.30, 0.30), (0.30, 0.30)]:
        add_box(mb, 0, ox, 1.22, oz, 0.14, 0.18, 0.14)
    # Molten lava core glowing inside parapet
    add_cylinder(mb, 1, 0.0, 1.16, 0.0, 0.24, 0.24, 0.06, segs=8)
    # Dragon horns jutting from parapet
    add_cone(mb, 1, -0.28, 1.32, 0.0, 0.08, 0.34, segs=8, rz=0.4, rx=0.2)
    add_cone(mb, 1, 0.28, 1.32, 0.0, 0.08, 0.34, segs=8, rz=-0.4, rx=0.2)
    # Gargoyle wings flanking tower
    add_box(mb, 0, -0.36, 0.72, -0.04, 0.05, 0.50, 0.28, ry=0.3, rz=-0.2)
    add_box(mb, 0, 0.36, 0.72, -0.04, 0.05, 0.50, 0.28, ry=-0.3, rz=0.2)
    # Portcullis archway
    add_box(mb, 1, 0.0, 0.30, 0.36, 0.16, 0.28, 0.04)

def build_fantasy_queen(mb):
    add_fantasy_pedestal(mb)
    # Flared ballgown
    add_cylinder(mb, 0, 0.0, 0.35, 0.0, 0.42, 0.25, 0.50, segs=16)
    add_cylinder(mb, 2, 0.0, 0.70, 0.0, 0.23, 0.17, 0.30, segs=14)
    add_cylinder(mb, 1, 0.0, 0.58, 0.0, 0.24, 0.24, 0.04, segs=14)
    # Velvet shoulders & chest
    add_box(mb, 2, 0.0, 0.90, -0.04, 0.38, 0.16, 0.18)
    # Queen head
    add_sphere(mb, 0, 0.0, 1.12, 0.0, 0.12)
    # 5-pointed coronet crown
    add_cylinder(mb, 1, 0.0, 1.25, 0.0, 0.15, 0.16, 0.08, segs=12)
    for i in range(5):
        ang = 2.0 * math.pi * i / 5.0
        cx = math.cos(ang) * 0.15
        cz = math.sin(ang) * 0.15
        add_cone(mb, 1, cx, 1.34, cz, 0.03, 0.12)
    # Sapphire gem on crown
    add_sphere(mb, 2, 0.0, 1.26, 0.16, 0.035)
    # Golden royal scepter in hand
    add_cylinder(mb, 1, 0.28, 0.88, 0.14, 0.02, 0.02, 0.80, segs=8)
    add_sphere(mb, 1, 0.28, 1.32, 0.14, 0.06)

def build_fantasy_king(mb):
    # Stately wide pedestal
    add_cylinder(mb, 0, 0.0, 0.06, 0.0, 0.45, 0.42, 0.12, segs=16)
    add_cylinder(mb, 1, 0.0, 0.13, 0.0, 0.42, 0.39, 0.03, segs=16)
    # Crimson ermine robe drape
    add_cylinder(mb, 3, 0.0, 0.45, 0.0, 0.43, 0.28, 0.68, segs=16)
    # Heavy armored cuirass
    add_box(mb, 0, 0.0, 0.86, 0.0, 0.42, 0.32, 0.26)
    # Imperial gold crest
    add_box(mb, 1, 0.0, 0.88, 0.14, 0.16, 0.20, 0.02)
    # Heavy pauldrons
    add_box(mb, 1, -0.26, 0.98, 0.0, 0.18, 0.15, 0.24)
    add_box(mb, 1, 0.26, 0.98, 0.0, 0.18, 0.15, 0.24)
    # Fur collar
    add_cylinder(mb, 3, 0.0, 1.08, 0.0, 0.25, 0.21, 0.10, segs=14)
    # King head & beard
    add_sphere(mb, 0, 0.0, 1.22, 0.0, 0.14)
    # Imperial Closed Crown
    add_cylinder(mb, 1, 0.0, 1.36, 0.0, 0.17, 0.18, 0.08, segs=14)
    add_sphere(mb, 3, 0.0, 1.44, 0.0, 0.15)
    # Crown cross finial
    add_box(mb, 1, 0.0, 1.62, 0.0, 0.03, 0.14, 0.03)
    add_box(mb, 1, 0.0, 1.64, 0.0, 0.10, 0.03, 0.03)
    # Masterwork claymore sword point-down into pedestal
    add_box(mb, 0, 0.0, 0.52, 0.28, 0.06, 0.70, 0.02)
    add_box(mb, 1, 0.0, 0.88, 0.28, 0.26, 0.04, 0.04)
    add_cylinder(mb, 1, 0.0, 0.98, 0.28, 0.02, 0.02, 0.16)


# ==========================================
# 2. CYBERPUNK THEME MODELS
# ==========================================
CYBER_MATERIALS = [
    # 0: Carbon Nano-Chassis
    {'name': 'CarbonChassis', 'pbrMetallicRoughness': {'baseColorFactor': [0.12, 0.13, 0.16, 1.0], 'metallicFactor': 0.75, 'roughnessFactor': 0.35}},
    # 1: Neon Cyan LED / Matrix
    {'name': 'NeonCyan', 'pbrMetallicRoughness': {'baseColorFactor': [0.0, 0.95, 0.95, 1.0], 'metallicFactor': 0.10, 'roughnessFactor': 0.10}},
    # 2: Hot Neon Magenta / Laser
    {'name': 'NeonMagenta', 'pbrMetallicRoughness': {'baseColorFactor': [1.0, 0.05, 0.55, 1.0], 'metallicFactor': 0.10, 'roughnessFactor': 0.10}},
    # 3: Titanium / 24K Cyber Gold
    {'name': 'CyberGold', 'pbrMetallicRoughness': {'baseColorFactor': [0.92, 0.78, 0.20, 1.0], 'metallicFactor': 0.92, 'roughnessFactor': 0.18}}
]

def add_cyber_pedestal(mb):
    # Hexagonal cyber plinth
    add_cylinder(mb, 0, 0.0, 0.06, 0.0, 0.44, 0.40, 0.12, segs=6)
    add_cylinder(mb, 1, 0.0, 0.13, 0.0, 0.40, 0.37, 0.03, segs=6)

def build_cyber_android_pawn(mb):
    add_cyber_pedestal(mb)
    # Segmented robotic legs
    add_cylinder(mb, 0, -0.11, 0.34, 0.0, 0.07, 0.06, 0.36, segs=8)
    add_cylinder(mb, 0, 0.11, 0.34, 0.0, 0.07, 0.06, 0.36, segs=8)
    add_sphere(mb, 3, -0.11, 0.34, 0.05, 0.045)
    add_sphere(mb, 3, 0.11, 0.34, 0.05, 0.045)
    # Angular athletic chassis
    add_box(mb, 0, 0.0, 0.66, 0.0, 0.32, 0.28, 0.20)
    # Chest neon arc reactor core
    add_cylinder(mb, 1, 0.0, 0.70, 0.10, 0.06, 0.06, 0.02, segs=10, rx=1.57)
    # Android head with visor slit
    add_box(mb, 0, 0.0, 0.96, 0.0, 0.18, 0.20, 0.20)
    add_box(mb, 1, 0.0, 0.96, 0.10, 0.16, 0.03, 0.02)
    # Shock baton forearm weapon with neon rings
    add_cylinder(mb, 0, 0.22, 0.56, 0.10, 0.025, 0.025, 0.48, segs=8)
    add_ring(mb, 1, 0.22, 0.62, 0.10, 0.045, 0.015, rx=1.57)
    add_ring(mb, 1, 0.22, 0.70, 0.10, 0.045, 0.015, rx=1.57)

def build_cyber_katana_knight(mb):
    add_cyber_pedestal(mb)
    # Agile cyber-shinobi stance
    add_cylinder(mb, 0, -0.12, 0.30, -0.04, 0.07, 0.06, 0.30, rx=0.2)
    add_cylinder(mb, 0, 0.12, 0.30, 0.04, 0.07, 0.06, 0.30, rx=-0.2)
    # Nano-carbon torso
    add_box(mb, 0, 0.0, 0.64, 0.0, 0.32, 0.30, 0.22)
    # Jet thruster jump pack on back
    add_box(mb, 0, 0.0, 0.70, -0.15, 0.22, 0.26, 0.08)
    add_cone(mb, 2, -0.06, 0.54, -0.15, 0.04, 0.12)
    add_cone(mb, 2, 0.06, 0.54, -0.15, 0.04, 0.12)
    # Cyber kabuto helmet with antenna fin
    add_box(mb, 0, 0.0, 0.95, 0.0, 0.20, 0.20, 0.22)
    add_box(mb, 2, 0.0, 1.12, 0.04, 0.03, 0.14, 0.16, rx=0.4)
    # Menacing glowing magenta optic slit
    add_box(mb, 2, 0.0, 0.95, 0.11, 0.15, 0.025, 0.02)
    # Energized High-Frequency Katana across body
    add_cylinder(mb, 3, -0.05, 0.62, 0.18, 0.02, 0.02, 0.24, segs=8, rz=0.6, rx=0.3)
    add_box(mb, 2, 0.02, 0.70, 0.20, 0.06, 0.06, 0.015, rz=0.6, rx=0.3)
    add_box(mb, 2, 0.24, 0.92, 0.24, 0.025, 0.62, 0.05, rz=-0.7, rx=0.2)

def build_cyber_railgun_bishop(mb):
    add_cyber_pedestal(mb)
    # Tripod-braced legs
    add_cylinder(mb, 0, -0.12, 0.32, 0.0, 0.07, 0.06, 0.32, segs=8)
    add_cylinder(mb, 0, 0.12, 0.32, 0.0, 0.07, 0.06, 0.32, segs=8)
    # Slender sniper torso
    add_box(mb, 0, 0.0, 0.66, 0.0, 0.30, 0.30, 0.18)
    # Sensor uplink antenna fin
    add_cylinder(mb, 3, -0.14, 1.10, 0.0, 0.01, 0.01, 0.38, segs=6)
    # Sniper head with multi-ocular optics
    add_box(mb, 0, 0.0, 0.94, 0.0, 0.18, 0.18, 0.20)
    add_cylinder(mb, 3, 0.05, 0.96, 0.11, 0.035, 0.035, 0.02, segs=8, rx=1.57)
    # Massive Hyper-Velocity Railgun
    add_box(mb, 0, 0.22, 0.82, 0.12, 0.06, 0.06, 1.15)
    add_box(mb, 1, 0.22, 0.82, 0.12, 0.02, 0.02, 1.20)
    # 4 magnetic acceleration coils
    for z in [0.25, 0.45, 0.65, 0.85]:
        add_ring(mb, 1, 0.22, 0.82, z, 0.05, 0.015)
    # Battery power pack on hip
    add_box(mb, 1, -0.16, 0.54, 0.0, 0.10, 0.16, 0.12)

def build_cyber_mech_rook(mb):
    # Heavy octagonal mechanized plinth
    add_cylinder(mb, 0, 0.0, 0.08, 0.0, 0.46, 0.44, 0.16, segs=8)
    add_cylinder(mb, 3, 0.0, 0.17, 0.0, 0.43, 0.41, 0.03, segs=8)
    # 4 hydraulic walker legs at 45 deg angles
    for dx, dz in [(-0.25, -0.25), (0.25, -0.25), (-0.25, 0.25), (0.25, 0.25)]:
        add_box(mb, 0, dx, 0.35, dz, 0.12, 0.28, 0.12)
    # Armored bunker chassis
    add_box(mb, 0, 0.0, 0.65, 0.0, 0.52, 0.40, 0.44)
    # Hazard yellow armor plating
    add_box(mb, 3, 0.0, 0.72, 0.23, 0.36, 0.14, 0.02)
    # Armored targeting visor slit
    add_box(mb, 2, 0.0, 0.72, 0.24, 0.22, 0.035, 0.02)
    # Twin shoulder-mounted heavy rotary autocannons
    add_cylinder(mb, 0, -0.30, 0.80, 0.10, 0.07, 0.07, 0.48, segs=10, rx=1.57)
    add_cylinder(mb, 0, 0.30, 0.80, 0.10, 0.07, 0.07, 0.48, segs=10, rx=1.57)
    add_cylinder(mb, 1, -0.30, 0.80, 0.35, 0.02, 0.02, 0.06, segs=6, rx=1.57)
    add_cylinder(mb, 1, 0.30, 0.80, 0.35, 0.02, 0.02, 0.06, segs=6, rx=1.57)
    # Sensor radar dome
    add_cylinder(mb, 0, 0.0, 0.90, 0.0, 0.16, 0.14, 0.08, segs=12)

def build_cyber_holo_queen(mb):
    # Suspended repulsor base ring
    add_ring(mb, 1, 0.0, 0.08, 0.0, 0.38, 0.04, segs=16, tube_segs=8)
    # Floating synthetic avatar torso
    add_box(mb, 1, 0.0, 0.65, 0.0, 0.26, 0.38, 0.16)
    # Dual orbiting floating data rings
    add_ring(mb, 1, 0.0, 0.65, 0.0, 0.32, 0.02, rx=0.3, rz=0.2)
    add_ring(mb, 2, 0.0, 0.75, 0.0, 0.30, 0.02, rx=-0.3, rz=-0.2)
    # Holographic avatar head & tiara
    add_sphere(mb, 1, 0.0, 1.08, 0.0, 0.12)
    add_ring(mb, 2, 0.0, 1.26, 0.0, 0.16, 0.015, rx=0.2)
    # Floating data crystal scepter
    add_cone(mb, 1, 0.26, 0.98, 0.10, 0.05, 0.32, segs=6)
    add_cone(mb, 2, 0.26, 0.80, 0.10, 0.05, 0.20, segs=6, rx=3.14)

def build_cyber_king(mb):
    # Massive mainframe dais
    add_cylinder(mb, 0, 0.0, 0.08, 0.0, 0.46, 0.44, 0.16, segs=8)
    add_cylinder(mb, 2, 0.0, 0.17, 0.0, 0.43, 0.40, 0.03, segs=8)
    # Powered exoskeleton legs
    add_cylinder(mb, 0, -0.14, 0.40, 0.0, 0.09, 0.08, 0.44, segs=8)
    add_cylinder(mb, 0, 0.14, 0.40, 0.0, 0.09, 0.08, 0.44, segs=8)
    # Cyber-warlord powered torso
    add_box(mb, 0, 0.0, 0.80, 0.0, 0.46, 0.36, 0.28)
    # High angular energy-shield cape collar
    add_box(mb, 0, 0.0, 1.08, -0.12, 0.42, 0.28, 0.05, rx=0.25)
    # Neon red overclock busbars
    add_box(mb, 2, -0.10, 0.80, 0.15, 0.025, 0.26, 0.02)
    add_box(mb, 2, 0.10, 0.80, 0.15, 0.025, 0.26, 0.02)
    # Broad gold capacitor pauldrons
    add_box(mb, 3, -0.30, 0.94, 0.0, 0.18, 0.16, 0.24)
    add_box(mb, 3, 0.30, 0.94, 0.0, 0.18, 0.16, 0.24)
    # Helm with spiked neural crown cooling fins
    add_box(mb, 0, 0.0, 1.18, 0.0, 0.20, 0.22, 0.22)
    for x in [-0.08, -0.04, 0.0, 0.04, 0.08]:
        add_box(mb, 3, x, 1.36, 0.0, 0.015, 0.16, 0.18)
    # Crimson ocular visor
    add_box(mb, 2, 0.0, 1.18, 0.12, 0.16, 0.035, 0.02)
    # Overcharged plasma core charging in gauntlet
    add_sphere(mb, 2, 0.32, 0.82, 0.18, 0.085)


# ==========================================
# 3. ELDRITCH THEME MODELS
# ==========================================
ELDRITCH_MATERIALS = [
    # 0: Abyssal Carapace / Ash-Purple
    {'name': 'AbyssalCarapace', 'pbrMetallicRoughness': {'baseColorFactor': [0.16, 0.14, 0.22, 1.0], 'metallicFactor': 0.15, 'roughnessFactor': 0.85}},
    # 1: Deep Necrotic Violet / Void Nebula
    {'name': 'VoidViolet', 'pbrMetallicRoughness': {'baseColorFactor': [0.60, 0.08, 0.75, 1.0], 'metallicFactor': 0.25, 'roughnessFactor': 0.18}},
    # 2: Luminous Eye Yellow / Blood Rune
    {'name': 'EldritchEyeYellow', 'pbrMetallicRoughness': {'baseColorFactor': [0.95, 0.88, 0.12, 1.0], 'metallicFactor': 0.10, 'roughnessFactor': 0.10}},
    # 3: Glacial Ice / Corrupted Bone
    {'name': 'GlacialBone', 'pbrMetallicRoughness': {'baseColorFactor': [0.55, 0.82, 0.95, 1.0], 'metallicFactor': 0.35, 'roughnessFactor': 0.20}}
]

def add_eldritch_pedestal(mb):
    # Rough unholy ritual plinth
    add_cylinder(mb, 0, 0.0, 0.06, 0.0, 0.44, 0.38, 0.12, segs=10)
    add_cylinder(mb, 1, 0.0, 0.13, 0.0, 0.38, 0.34, 0.03, segs=10)

def build_eldritch_cultist(mb):
    add_eldritch_pedestal(mb)
    # Tattered cowl & robe
    add_cylinder(mb, 0, 0.0, 0.38, 0.0, 0.35, 0.22, 0.50, segs=10)
    add_cylinder(mb, 0, 0.0, 0.76, 0.0, 0.23, 0.19, 0.28, segs=10)
    # Deep shadowed face cavity
    add_sphere(mb, 1, 0.0, 0.92, 0.04, 0.11)
    # Cavernous hood overhang
    add_cone(mb, 0, 0.0, 1.12, -0.04, 0.21, 0.28, segs=10, rx=-0.3)
    # Ritual sacrificial bone dagger
    add_cylinder(mb, 0, 0.20, 0.56, 0.18, 0.02, 0.02, 0.14)
    add_box(mb, 3, 0.20, 0.74, 0.18, 0.03, 0.28, 0.015, rz=-0.1)
    # Occult talisman on chest
    add_box(mb, 2, 0.0, 0.64, 0.14, 0.07, 0.07, 0.02, ry=0.78)

def build_eldritch_frost_giant(mb):
    # Glacial crag pedestal
    add_cylinder(mb, 0, 0.0, 0.06, 0.0, 0.45, 0.40, 0.12, segs=8)
    add_cylinder(mb, 3, 0.0, 0.14, 0.0, 0.40, 0.36, 0.04, segs=8)
    # Hulking brute torso
    add_box(mb, 0, 0.0, 0.66, 0.0, 0.48, 0.40, 0.30)
    # Ice crystals bursting through shoulders
    add_cone(mb, 3, -0.26, 0.92, 0.0, 0.08, 0.28, segs=6, rz=0.4)
    add_cone(mb, 3, 0.26, 0.92, 0.0, 0.08, 0.28, segs=6, rz=-0.4)
    # Spiked horned helm
    add_cylinder(mb, 0, 0.0, 1.08, 0.0, 0.18, 0.17, 0.20, segs=10)
    # Massive curved frost ram horns
    add_cone(mb, 3, -0.20, 1.15, 0.0, 0.07, 0.34, segs=8, rz=0.9, rx=0.3)
    add_cone(mb, 3, 0.20, 1.15, 0.0, 0.07, 0.34, segs=8, rz=-0.9, rx=0.3)
    # Glowing frost eyes
    add_sphere(mb, 3, -0.06, 1.06, 0.16, 0.025)
    add_sphere(mb, 3, 0.06, 1.06, 0.16, 0.025)
    # Crystalline Ice Warhammer / Maul
    add_cylinder(mb, 0, 0.28, 0.68, 0.16, 0.035, 0.035, 1.05, segs=8)
    add_box(mb, 3, 0.28, 1.20, 0.16, 0.22, 0.28, 0.38)

def build_eldritch_cosmic_horror(mb):
    add_eldritch_pedestal(mb)
    # Cephalopodic alien mantle
    add_sphere(mb, 0, 0.0, 0.62, 0.0, 0.30, rings=8, segs=12)
    # Swelling cosmic cranium dome
    add_sphere(mb, 1, 0.0, 0.96, -0.04, 0.26, rings=8, segs=12)
    # Clustered cosmic eyeballs
    add_sphere(mb, 2, 0.0, 0.88, 0.20, 0.05)
    add_sphere(mb, 2, -0.10, 0.94, 0.17, 0.04)
    add_sphere(mb, 2, 0.10, 0.94, 0.17, 0.04)
    add_sphere(mb, 2, -0.06, 0.80, 0.22, 0.035)
    add_sphere(mb, 2, 0.06, 0.80, 0.22, 0.035)
    # 6 writhing curling tentacles
    for i in range(6):
        ang = 2.0 * math.pi * i / 6.0
        tx = math.cos(ang) * 0.22
        tz = math.sin(ang) * 0.22
        add_cylinder(mb, 0, tx, 0.34, tz, 0.06, 0.04, 0.30, rx=math.cos(ang)*0.4, rz=math.sin(ang)*0.4)
        add_cone(mb, 1, tx*1.3, 0.44, tz*1.3, 0.04, 0.26, rx=math.cos(ang)*0.7, rz=math.sin(ang)*0.7)
    # Central toothy beak
    add_cone(mb, 0, 0.0, 0.62, 0.26, 0.07, 0.10, segs=6, rx=1.57)

def build_eldritch_void_spawn(mb):
    # Dimensional crater base
    add_cylinder(mb, 0, 0.0, 0.08, 0.0, 0.46, 0.42, 0.16, segs=10)
    add_cylinder(mb, 1, 0.0, 0.17, 0.0, 0.42, 0.38, 0.03, segs=10)
    # Twin twisted obsidian obelisk monoliths
    add_box(mb, 0, -0.22, 0.72, 0.0, 0.16, 1.05, 0.22, rz=-0.1)
    add_box(mb, 0, 0.22, 0.72, 0.0, 0.16, 1.05, 0.22, rz=0.1)
    # Monolith spire tips
    add_cone(mb, 0, -0.27, 1.35, 0.0, 0.11, 0.28, segs=4, rz=-0.1)
    add_cone(mb, 0, 0.27, 1.35, 0.0, 0.11, 0.28, segs=4, rz=0.1)
    # Suspended black hole singularity sphere
    add_sphere(mb, 0, 0.0, 0.82, 0.0, 0.14)
    # Violet event horizon halo ring
    add_ring(mb, 1, 0.0, 0.82, 0.0, 0.20, 0.025, rx=0.4, rz=0.3)
    # Accretion gold sparks
    add_ring(mb, 2, 0.0, 0.82, 0.0, 0.26, 0.015, rx=-0.3, rz=-0.4)

def build_eldritch_cosmic_queen(mb):
    add_eldritch_pedestal(mb)
    # Flowing cosmic gown
    add_cylinder(mb, 0, 0.0, 0.36, 0.0, 0.40, 0.23, 0.52, segs=14)
    add_cylinder(mb, 0, 0.0, 0.76, 0.0, 0.21, 0.16, 0.32, segs=12)
    # Swirling dimensional tear wings (void ribbons)
    add_box(mb, 1, -0.30, 0.92, -0.06, 0.04, 0.56, 0.26, ry=0.3, rz=-0.3)
    add_box(mb, 1, 0.30, 0.92, -0.06, 0.04, 0.56, 0.26, ry=-0.3, rz=0.3)
    # Cosmic queen head
    add_sphere(mb, 0, 0.0, 1.10, 0.0, 0.12)
    # Crown halo of floating celestial eyes
    add_ring(mb, 1, 0.0, 1.30, 0.0, 0.20, 0.018, rx=0.2)
    add_sphere(mb, 2, -0.15, 1.33, 0.0, 0.035)
    add_sphere(mb, 2, 0.0, 1.40, 0.14, 0.035)
    add_sphere(mb, 2, 0.15, 1.33, 0.0, 0.035)
    # Levitating miniature dying star held above palms
    add_sphere(mb, 2, 0.0, 1.00, 0.22, 0.075)

def build_eldritch_shadow_king(mb):
    # Spiked throne plinth
    add_cylinder(mb, 0, 0.0, 0.06, 0.0, 0.46, 0.42, 0.12, segs=12)
    add_cylinder(mb, 1, 0.0, 0.13, 0.0, 0.42, 0.38, 0.03, segs=12)
    # Skeletal ribbed bone cuirass
    add_box(mb, 3, 0.0, 0.80, 0.0, 0.42, 0.36, 0.26)
    # Rib ridges along chest
    for y in [0.72, 0.80, 0.88]:
        add_box(mb, 1, 0.0, y, 0.14, 0.34, 0.025, 0.02)
    # Jagged shoulder bone spires
    add_cone(mb, 0, -0.28, 1.02, 0.0, 0.08, 0.36, segs=6, rz=0.4)
    add_cone(mb, 0, 0.28, 1.02, 0.0, 0.08, 0.36, segs=6, rz=-0.4)
    # Faceless void head
    add_box(mb, 0, 0.0, 1.20, 0.0, 0.20, 0.22, 0.22)
    # Crown of six obsidian spikes
    for i in range(6):
        ang = 2.0 * math.pi * i / 6.0
        cx = math.cos(ang) * 0.12
        cz = math.sin(ang) * 0.12
        add_cone(mb, 0, cx, 1.40, cz, 0.03, 0.22, segs=4)
    # Glowing necrotic crimson eye slits
    add_box(mb, 1, 0.0, 1.20, 0.12, 0.15, 0.025, 0.02)
    # Extended shadow claws
    for dx in [-0.03, 0.0, 0.03]:
        add_cone(mb, 1, -0.26 + dx, 0.70, 0.22, 0.015, 0.14, rx=1.57)
        add_cone(mb, 1, 0.26 + dx, 0.70, 0.22, 0.015, 0.14, rx=1.57)


# ==========================================
# VERIFICATION AND GENERATION RUNNER
# ==========================================
def verify_glb(filepath):
    """Verifies that a file is a valid glTF 2.0 binary file."""
    if not os.path.exists(filepath):
        return False, f"File not found: {filepath}"
    size = os.path.getsize(filepath)
    if size < 20:
        return False, f"File too small ({size} bytes)"
    with open(filepath, 'rb') as f:
        data = f.read()

    magic, ver, total_len = struct.unpack('<4sII', data[:12])
    if magic != b'glTF':
        return False, f"Bad magic: {magic} (expected b'glTF')"
    if ver != 2:
        return False, f"Bad version: {ver} (expected 2)"
    if total_len != size:
        return False, f"Header totalLength ({total_len}) != file size ({size})"

    # Check chunks
    offset = 12
    chunk_idx = 0
    json_verified = False
    bin_verified = False

    while offset < size:
        c_len, c_type = struct.unpack('<II', data[offset:offset+8])
        c_data = data[offset+8:offset+8+c_len]
        if c_type == 0x4E4F534A: # JSON
            try:
                gltf = json.loads(c_data.decode('utf-8'))
                if gltf.get('asset', {}).get('version') != '2.0':
                    return False, "Asset version is not 2.0"
                json_verified = True
            except Exception as e:
                return False, f"JSON parse error: {e}"
        elif c_type == 0x004E4942: # BIN
            bin_verified = True
        offset += 8 + c_len
        chunk_idx += 1

    if not json_verified:
        return False, "No valid JSON chunk found"
    return True, f"Valid glTF 2.0 binary ({size} bytes, {chunk_idx} chunks)"


PIPELINE = {
    'fantasy': {
        'materials': FANTASY_MATERIALS,
        'pieces': [
            ('pawn', 'paladin', build_fantasy_paladin),
            ('knight', 'goblin', build_fantasy_goblin),
            ('bishop', 'sorcerer', build_fantasy_sorcerer),
            ('rook', 'dragon_rook', build_fantasy_dragon_rook),
            ('queen', 'queen', build_fantasy_queen),
            ('king', 'king', build_fantasy_king),
        ]
    },
    'cyberpunk': {
        'materials': CYBER_MATERIALS,
        'pieces': [
            ('pawn', 'android_pawn', build_cyber_android_pawn),
            ('knight', 'neon_katana_knight', build_cyber_katana_knight),
            ('bishop', 'railgun_bishop', build_cyber_railgun_bishop),
            ('rook', 'cyber_mech_rook', build_cyber_mech_rook),
            ('queen', 'holo_queen', build_cyber_holo_queen),
            ('king', 'cyber_king', build_cyber_king),
        ]
    },
    'eldritch': {
        'materials': ELDRITCH_MATERIALS,
        'pieces': [
            ('pawn', 'cultist', build_eldritch_cultist),
            ('knight', 'frost_giant', build_eldritch_frost_giant),
            ('bishop', 'cosmic_horror', build_eldritch_cosmic_horror),
            ('rook', 'void_spawn', build_eldritch_void_spawn),
            ('queen', 'cosmic_queen', build_eldritch_cosmic_queen),
            ('king', 'shadow_king', build_eldritch_shadow_king),
        ]
    }
}

def generate_all(base_output_dir="assets/models"):
    print("=" * 60)
    print("Starting 3D Asset & Skeleton Pipeline Generation")
    print(f"Output Directory: {os.path.abspath(base_output_dir)}")
    print("=" * 60)

    total_files = 0
    verified_files = 0

    for theme, data in PIPELINE.items():
        theme_dir = os.path.join(base_output_dir, theme)
        os.makedirs(theme_dir, exist_ok=True)
        print(f"\n[Theme: {theme.upper()}] -> {theme_dir}")

        for std_name, thematic_name, builder_fn in data['pieces']:
            mb = MeshBuilder()
            builder_fn(mb)

            # Generate primary thematic file
            thematic_path = os.path.join(theme_dir, f"{thematic_name}.glb")
            export_glb(mb, data['materials'], thematic_path, model_name=thematic_name)
            total_files += 1

            ok, msg = verify_glb(thematic_path)
            if ok:
                verified_files += 1
                print(f"  ✓ {thematic_name}.glb: {msg}")
            else:
                print(f"  ✗ {thematic_name}.glb: ERROR: {msg}")

            # Also generate or link standard chess piece name (e.g. pawn.glb)
            std_path = os.path.join(theme_dir, f"{std_name}.glb")
            if std_name != thematic_name:
                export_glb(mb, data['materials'], std_path, model_name=std_name)
                total_files += 1
                ok, msg = verify_glb(std_path)
                if ok:
                    verified_files += 1
                    print(f"    ↳ alias {std_name}.glb: {msg}")
                else:
                    print(f"    ↳ alias {std_name}.glb: ERROR: {msg}")

    print("\n" + "=" * 60)
    print(f"Pipeline Generation Complete: {verified_files}/{total_files} files verified.")
    print("=" * 60)
    return verified_files == total_files

if __name__ == '__main__':
    base_dir = sys.argv[1] if len(sys.argv) > 1 else "assets/models"
    success = generate_all(base_dir)
    sys.exit(0 if success else 1)
