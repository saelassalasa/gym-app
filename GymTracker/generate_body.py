"""Generate a low-poly humanoid OBJ with named groups per muscle region."""
import math

verts = []
faces = []
groups = {}

def vid():
    return len(verts) + 1

def add_ring(cx, cy, cz, rx, rz, n, y_off=0):
    """Add a ring of vertices, return list of 1-based indices."""
    indices = []
    for i in range(n):
        a = 2 * math.pi * i / n
        x = cx + rx * math.cos(a)
        z = cz + rz * math.sin(a)
        verts.append((x, cy + y_off, z))
        indices.append(vid())
    return indices

def connect_rings(r1, r2, group):
    """Connect two rings with quads (triangulated)."""
    if group not in groups:
        groups[group] = []
    n = len(r1)
    for i in range(n):
        j = (i + 1) % n
        a, b, c, d = r1[i], r1[j], r2[j], r2[i]
        groups[group].append((a, b, c))
        groups[group].append((a, c, d))

def cap_ring(ring, cx, cy, cz, group, top=True):
    """Cap a ring with a fan to a center vertex."""
    if group not in groups:
        groups[group] = []
    verts.append((cx, cy, cz))
    center = vid()
    n = len(ring)
    for i in range(n):
        j = (i + 1) % n
        if top:
            groups[group].append((center, ring[j], ring[i]))
        else:
            groups[group].append((center, ring[i], ring[j]))

def limb(cx, cz, y_bot, y_top, r_bot, r_top, segs, n, group):
    """Create a tapered cylinder limb."""
    rings = []
    for s in range(segs + 1):
        t = s / segs
        y = y_bot + (y_top - y_bot) * t
        r = r_bot + (r_top - r_bot) * t
        rings.append(add_ring(cx, y, cz, r, r, n))
    for i in range(len(rings) - 1):
        connect_rings(rings[i], rings[i + 1], group)
    cap_ring(rings[0], cx, y_bot, cz, group, top=False)
    cap_ring(rings[-1], cx, y_top, cz, group, top=True)

N = 10  # vertices per ring

# === HEAD ===
limb(0, 0, 1.58, 1.78, 0.08, 0.09, 3, N, "head")

# === NECK ===
limb(0, 0, 1.50, 1.58, 0.05, 0.06, 2, N, "neck")

# === CHEST (upper torso) ===
# Wider at top (shoulders), narrower at waist
rings_torso = []
torso_profile = [
    (1.10, 0.16, 0.10),  # waist
    (1.18, 0.18, 0.11),
    (1.28, 0.21, 0.12),
    (1.38, 0.22, 0.13),  # chest
    (1.46, 0.21, 0.12),
    (1.50, 0.18, 0.10),  # neck base
]
for y, rx, rz in torso_profile:
    rings_torso.append(add_ring(0, y, 0, rx, rz, N))
# Lower torso = core, upper = chest
for i in range(len(rings_torso) - 1):
    g = "core" if i < 2 else "chest"
    connect_rings(rings_torso[i], rings_torso[i + 1], g)

# === BACK (shares torso rings, add a back plate) ===
# Back is implicit in the torso cylinder - covered by chest/core groups

# === SHOULDERS ===
for side in [-1, 1]:
    name = "shoulder_L" if side == -1 else "shoulder_R"
    cx = side * 0.22
    limb(cx, 0, 1.40, 1.50, 0.06, 0.07, 2, N, name)

# === UPPER ARMS (biceps front, triceps back - combined as arm) ===
for side in [-1, 1]:
    bname = "bicep_L" if side == -1 else "bicep_R"
    tname = "tricep_L" if side == -1 else "tricep_R"
    cx = side * 0.26
    # Upper arm
    limb(cx, 0.01, 1.22, 1.40, 0.04, 0.05, 3, N, bname)
    # Add slight tricep bump on back
    limb(cx, -0.02, 1.24, 1.38, 0.035, 0.04, 2, N, tname)

# === FOREARMS ===
for side in [-1, 1]:
    name = "forearm_L" if side == -1 else "forearm_R"
    cx = side * 0.28
    limb(cx, 0, 1.05, 1.22, 0.03, 0.04, 3, N, name)

# === GLUTES ===
for side in [-1, 1]:
    name = "glute_L" if side == -1 else "glute_R"
    cx = side * 0.08
    limb(cx, -0.03, 0.95, 1.10, 0.08, 0.09, 2, N, name)

# === QUADS (front of thigh) ===
for side in [-1, 1]:
    name = "quad_L" if side == -1 else "quad_R"
    cx = side * 0.10
    limb(cx, 0.02, 0.55, 0.98, 0.05, 0.08, 4, N, name)

# === HAMSTRINGS (back of thigh) ===
for side in [-1, 1]:
    name = "ham_L" if side == -1 else "ham_R"
    cx = side * 0.10
    limb(cx, -0.02, 0.58, 0.95, 0.045, 0.07, 3, N, name)

# === CALVES ===
for side in [-1, 1]:
    name = "calf_L" if side == -1 else "calf_R"
    cx = side * 0.10
    limb(cx, -0.01, 0.22, 0.55, 0.03, 0.05, 4, N, name)

# === WRITE OBJ ===
out = "# Generated low-poly humanoid with named muscle groups\n"
out += "# CC0 - programmatically generated\n\n"

for v in verts:
    out += f"v {v[0]:.4f} {v[1]:.4f} {v[2]:.4f}\n"

out += "\n"

for gname, tris in groups.items():
    out += f"g {gname}\n"
    for tri in tris:
        out += f"f {tri[0]} {tri[1]} {tri[2]}\n"
    out += "\n"

with open("/Users/deniznebiler/gym-app/GymTracker/Models/body.obj", "w") as f:
    f.write(out)

print(f"Generated: {len(verts)} vertices, {sum(len(t) for t in groups.values())} triangles, {len(groups)} groups")
print(f"Groups: {', '.join(groups.keys())}")
