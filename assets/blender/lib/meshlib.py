"""Shared geometry and asset definitions for the Fawn Rush environment pipeline.

Pure Python 3, no dependencies. Imported by both exporters:

  * `export_obj.py`   — writes .obj/.mtl, needs nothing installed
  * `build_environment.py` — builds real Blender objects and exports .fbx

Keeping the definitions here is what stops the two exporters drifting apart. An asset is a list of
primitives with a colour name; each exporter turns that list into its own representation.

Conventions (docs/06 §5.2):
  * 1 unit = 1 stud
  * origin at ground contact, centred laterally
  * flat palette materials, no textures
"""

import math

# --------------------------------------------------------------------------------------------------
# Palette — must stay in step with WorldConfig.BASE_PALETTE in src/shared/Config/WorldConfig.luau.
# --------------------------------------------------------------------------------------------------

PALETTE = {
    "trunk": (0.416, 0.298, 0.204),
    "leaf": (0.251, 0.455, 0.220),
    "leafAccent": (0.471, 0.627, 0.267),
    "rock": (0.502, 0.502, 0.471),
    "sand": (0.851, 0.737, 0.541),
    "sandstone": (0.745, 0.580, 0.408),
    "snow": (0.949, 0.965, 0.980),
    "ice": (0.745, 0.863, 0.910),
    "concrete": (0.588, 0.604, 0.620),
    "kerb": (0.769, 0.776, 0.784),
    "accent": (0.949, 0.702, 0.239),
    "neonA": (1.000, 0.247, 0.643),
    "neonB": (0.208, 0.878, 1.000),
    "road": (0.227, 0.247, 0.267),
}


# --------------------------------------------------------------------------------------------------
# Primitive generation. Each returns (vertices, faces) with 0-based face indices.
# --------------------------------------------------------------------------------------------------


def box(center, size, rotation_z=0.0):
    """Axis-aligned box with an optional rotation about Z. 8 vertices, 6 quads."""
    cx, cy, cz = center
    sx, sy, sz = size
    hx, hy, hz = sx * 0.5, sy * 0.5, sz * 0.5

    corners = [
        (-hx, -hy, -hz),
        (-hx, -hy, hz),
        (hx, -hy, hz),
        (hx, -hy, -hz),
        (-hx, hy, -hz),
        (-hx, hy, hz),
        (hx, hy, hz),
        (hx, hy, -hz),
    ]

    cos_r, sin_r = math.cos(rotation_z), math.sin(rotation_z)
    vertices = []
    for x, y, z in corners:
        rx = x * cos_r - y * sin_r
        ry = x * sin_r + y * cos_r
        vertices.append((cx + rx, cy + ry, cz + z))

    faces = [
        (0, 1, 2, 3),  # bottom
        (4, 7, 6, 5),  # top
        (1, 5, 6, 2),  # front (+Z)
        (3, 7, 4, 0),  # back (-Z)
        (0, 4, 5, 1),  # left
        (2, 6, 7, 3),  # right
    ]
    return vertices, faces


def sphere(center, radius, rings=6, segments=8):
    """Low-poly UV sphere. `rings` latitude bands, `segments` longitude columns."""
    cx, cy, cz = center
    vertices = []
    faces = []

    # Poles first, then one ring per latitude band.
    vertices.append((cx, cy + radius, cz))
    for ring in range(1, rings):
        phi = math.pi * ring / rings
        y = math.cos(phi) * radius
        r = math.sin(phi) * radius
        for seg in range(segments):
            theta = 2 * math.pi * seg / segments
            vertices.append((cx + math.cos(theta) * r, cy + y, cz + math.sin(theta) * r))
    vertices.append((cx, cy - radius, cz))

    bottom_pole = len(vertices) - 1

    # Top cap.
    for seg in range(segments):
        nxt = (seg + 1) % segments
        faces.append((0, 1 + seg, 1 + nxt))

    # Bands.
    for ring in range(rings - 2):
        base = 1 + ring * segments
        nxt_base = base + segments
        for seg in range(segments):
            nxt = (seg + 1) % segments
            faces.append((base + seg, nxt_base + seg, nxt_base + nxt))
            faces.append((base + seg, nxt_base + nxt, base + nxt))

    # Bottom cap.
    last_ring = 1 + (rings - 2) * segments
    for seg in range(segments):
        nxt = (seg + 1) % segments
        faces.append((bottom_pole, last_ring + nxt, last_ring + seg))

    return vertices, faces


def cylinder(center, radius, height, segments=8):
    """Vertical cylinder standing on its base at `center`."""
    cx, cy, cz = center
    vertices = []
    faces = []

    for seg in range(segments):
        theta = 2 * math.pi * seg / segments
        vertices.append((cx + math.cos(theta) * radius, cy, cz + math.sin(theta) * radius))
    for seg in range(segments):
        theta = 2 * math.pi * seg / segments
        vertices.append((cx + math.cos(theta) * radius, cy + height, cz + math.sin(theta) * radius))

    for seg in range(segments):
        nxt = (seg + 1) % segments
        faces.append((seg, nxt, segments + nxt, segments + seg))

    top_center = len(vertices)
    vertices.append((cx, cy + height, cz))
    bottom_center = len(vertices)
    vertices.append((cx, cy, cz))

    for seg in range(segments):
        nxt = (seg + 1) % segments
        faces.append((top_center, segments + seg, segments + nxt))
        faces.append((bottom_center, nxt, seg))

    return vertices, faces


# --------------------------------------------------------------------------------------------------
# Asset definitions. Each asset is a list of (primitive, colour_key) parts with a material name.
# --------------------------------------------------------------------------------------------------


def _parts(*entries):
    return list(entries)


ASSETS = {
    # --- Greenwood ---------------------------------------------------------------------------
    "ENV_Tree_Broadleaf_A": {
        "family": "Trees",
        "parts": _parts(
            ("cylinder", (0, 0, 0), 0.7, 9.0, "trunk"),
            ("sphere", (0, 11.0, 0), 5.0, "leaf"),
            ("sphere", (0.6, 15.0, -0.4), 3.6, "leafAccent"),
        ),
    },
    "ENV_Rock_A": {
        "family": "Rocks",
        "parts": _parts(
            ("sphere", (0, 0.8, 0), 1.8, "rock"),
        ),
    },
    "ENV_Mushroom_A": {
        "family": "Ground cover",
        "parts": _parts(
            ("cylinder", (0, 0, 0), 0.22, 1.0, "snow"),
            ("sphere", (0, 1.05, 0), 0.75, "accent"),
        ),
    },
    # --- City ---------------------------------------------------------------------------------
    "ENV_Building_A": {
        "family": "City props",
        "parts": _parts(
            ("box", (0, 12, 0), (9, 24, 11), "concrete"),
            ("box", (0, 24.5, 0), (9.4, 1.0, 11.4), "kerb"),
        ),
    },
    # --- Desert -------------------------------------------------------------------------------
    "ENV_Cactus_A": {
        "family": "Desert props",
        "parts": _parts(
            ("cylinder", (0, 0, 0), 0.55, 6.0, "leaf"),
            ("cylinder", (-1.0, 3.0, 0), 0.35, 2.0, "leaf"),
            ("cylinder", (1.0, 3.6, 0), 0.35, 1.6, "leaf"),
        ),
    },
    "ENV_Mesa_A": {
        "family": "Desert props",
        "parts": _parts(
            ("box", (0, 5, 0), (14, 10, 11), "sandstone"),
            ("box", (0, 10.5, 0), (11.5, 1.2, 9.2), "sand"),
        ),
    },
    # --- Snow ---------------------------------------------------------------------------------
    "ENV_Tree_Pine_A": {
        "family": "Trees",
        "parts": _parts(
            ("cylinder", (0, 0, 0), 0.5, 10.0, "trunk"),
            ("sphere", (0, 11.0, 0), 4.2, "leaf"),
            ("sphere", (0, 13.6, 0), 3.0, "leaf"),
            ("sphere", (0, 17.0, 0), 2.2, "snow"),
        ),
    },
    # --- Neon ---------------------------------------------------------------------------------
    "ENV_NeonTower_A": {
        "family": "Neon props",
        "parts": _parts(
            ("box", (0, 18, 0), (8, 36, 7), "concrete"),
            ("box", (0, 22, 0), (8.2, 0.6, 7.2), "neonA"),
            ("box", (0, 30, 0), (8.2, 0.6, 7.2), "neonB"),
        ),
    },
}

PRIMITIVES = {"box": box, "sphere": sphere, "cylinder": cylinder}


def build_asset(name):
    """Returns (vertices, faces, material_of_face) for one asset."""
    spec = ASSETS[name]
    vertices = []
    faces = []
    materials = []

    for part in spec["parts"]:
        kind = part[0]
        if kind == "box":
            _, center, size, color = part
            v, f = box(center, size)
        elif kind == "sphere":
            _, center, radius, color = part
            v, f = sphere(center, radius)
        elif kind == "cylinder":
            _, center, radius, height, color = part
            v, f = cylinder(center, radius, height)
        else:
            raise ValueError("unknown primitive %r in %s" % (kind, name))

        offset = len(vertices)
        vertices.extend(v)
        for face in f:
            faces.append(tuple(index + offset for index in face))
            materials.append(color)

    return vertices, faces, materials


def validate():
    """Sanity checks that catch a broken asset before it reaches Blender."""
    problems = []

    for name, spec in ASSETS.items():
        if not name.startswith(("ENV_", "VH_", "CH_", "CL_")):
            problems.append("%s does not follow the naming rule" % name)

        vertices, faces, materials = build_asset(name)

        if not vertices:
            problems.append("%s has no vertices" % name)
        if not faces:
            problems.append("%s has no faces" % name)

        for face in faces:
            if len(face) > 4:
                problems.append("%s has an n-gon (%d sides)" % (name, len(face)))
            if len(set(face)) != len(face):
                problems.append("%s has a face with a repeated vertex" % name)
            for index in face:
                if index < 0 or index >= len(vertices):
                    problems.append("%s has an out-of-range face index" % name)
                    break

        for face in faces:
            if len(face) < 3:
                problems.append("%s has a degenerate face" % name)

        for color in materials:
            if color not in PALETTE:
                problems.append("%s uses unknown colour %r" % (name, color))

        # Ground contact: nothing should hang below the origin.
        lowest = min(v[1] for v in vertices)
        if lowest < -0.01:
            problems.append("%s dips %.2f below the origin" % (name, lowest))

    return problems


if __name__ == "__main__":
    issues = validate()
    if issues:
        for issue in issues:
            print("FAIL", issue)
        raise SystemExit(1)
    print("meshlib: %d assets valid" % len(ASSETS))
