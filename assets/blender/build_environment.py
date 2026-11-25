#!/usr/bin/env python3
"""Build the Fawn Rush environment assets as real Blender objects and export FBX + .blend.

    blender --background --python assets/blender/build_environment.py -- --out assets/export

Requires Blender 3.6+ (any recent version). Not runnable in the development environment, which has no
Blender — see README.md. The geometry comes from lib/meshlib.py, shared with the OBJ exporter, so the
two cannot drift apart.

Produces, per asset:
  * one mesh object with per-part palette materials
  * a decimated LOD variant parented alongside it
  * <AssetName>.fbx  (the import artefact)
and one .blend per family for hand editing.
"""

import os
import sys

try:
    import bpy
except ImportError:  # pragma: no cover - only reachable outside Blender
    print("This script must be run inside Blender:", file=sys.stderr)
    print("  blender --background --python assets/blender/build_environment.py -- --out assets/export", file=sys.stderr)
    raise SystemExit(2)

sys.path.insert(0, os.path.join(os.path.dirname(os.path.abspath(__file__)), "lib"))

import meshlib  # noqa: E402

LOD_RATIO = 0.5
LOD_SUFFIX = "_LOD1"


def parse_args():
    argv = sys.argv
    argv = argv[argv.index("--") + 1 :] if "--" in argv else []
    out = "assets/export"
    for index, token in enumerate(argv):
        if token == "--out" and index + 1 < len(argv):
            out = argv[index + 1]
    return out


def reset_scene():
    bpy.ops.wm.read_factory_settings(use_empty=True)


def material_for(color_key):
    """One material per palette colour, shared across every asset that uses it."""
    name = "FR_" + color_key
    existing = bpy.data.materials.get(name)
    if existing:
        return existing

    material = bpy.data.materials.new(name=name)
    material.use_nodes = True

    red, green, blue = meshlib.PALETTE[color_key]
    principled = material.node_tree.nodes.get("Principled BSDF")
    if principled:
        principled.inputs["Base Color"].default_value = (red, green, blue, 1.0)
        principled.inputs["Roughness"].default_value = 0.72
        principled.inputs["Metallic"].default_value = 0.0

    material.diffuse_color = (red, green, blue, 1.0)
    return material


def build_object(asset_name, object_name=None, lod_ratio=1.0):
    """Builds one Blender object from `asset_name`.

    `object_name` is separate because the LOD variant is the *same* asset decimated, not a second
    entry in meshlib.ASSETS — passing the suffixed name here previously made build_asset() look up
    an asset that does not exist.
    """
    object_name = object_name or asset_name
    vertices, faces, materials = meshlib.build_asset(asset_name)

    mesh = bpy.data.meshes.new(object_name)
    mesh.from_pydata(vertices, [], faces)
    mesh.update()

    obj = bpy.data.objects.new(object_name, mesh)
    bpy.context.collection.objects.link(obj)

    # Material slots, in first-seen order, then one index per polygon.
    slots = []
    index_of = {}
    for color_key in materials:
        if color_key not in index_of:
            index_of[color_key] = len(slots)
            slots.append(material_for(color_key))

    for material in slots:
        obj.data.materials.append(material)

    for polygon, color_key in zip(mesh.polygons, materials):
        polygon.material_index = index_of[color_key]
        polygon.use_smooth = color_key in ("leaf", "leafAccent", "rock", "snow")

    # Ground contact and flat shading expectations from docs/06 §5.2.
    obj.location = (0.0, 0.0, 0.0)

    if lod_ratio < 1.0:
        modifier = obj.modifiers.new(name="LODDecimate", type="DECIMATE")
        modifier.ratio = lod_ratio
        # modifier_apply acts on the active object, but leaving a stale selection can apply it to
        # the wrong one; select explicitly and deselect everything else first.
        bpy.ops.object.select_all(action="DESELECT")
        obj.select_set(True)
        bpy.context.view_layer.objects.active = obj
        try:
            bpy.ops.object.modifier_apply(modifier=modifier.name)
        except RuntimeError as error:
            print("  ! decimate failed on %s: %s" % (object_name, error))

    return obj


def export_fbx(objects, path):
    bpy.ops.object.select_all(action="DESELECT")
    for obj in objects:
        obj.select_set(True)
    if objects:
        bpy.context.view_layer.objects.active = objects[0]

    bpy.ops.export_scene.fbx(
        filepath=path,
        use_selection=True,
        object_types={"MESH"},
        apply_scale_options="FBX_SCALE_ALL",
        axis_forward="-Z",
        axis_up="Y",
        bake_space_transform=False,
        mesh_smooth_type="FACE",
        use_mesh_modifiers=True,
    )


def main():
    out_dir = parse_args()
    os.makedirs(out_dir, exist_ok=True)

    problems = meshlib.validate()
    if problems:
        for problem in problems:
            print("FAIL", problem)
        print("Refusing to build an invalid asset set.")
        return 1

    families = {}
    for name, spec in sorted(meshlib.ASSETS.items()):
        families.setdefault(spec["family"], []).append(name)

    total = 0
    for family, names in sorted(families.items()):
        reset_scene()

        built = []
        for name in names:
            high = build_object(name)
            low = build_object(name, object_name=name + LOD_SUFFIX, lod_ratio=LOD_RATIO)
            low.hide_render = True
            built.extend([high, low])

            # The importer takes one asset at a time; export each pair on its own.
            export_fbx([high, low], os.path.join(out_dir, name + ".fbx"))
            print("  %-28s %d tris (high)" % (name, len(high.data.polygons)))
            total += 1

        blend_path = os.path.join(out_dir, "ENV_%s.blend" % family.replace(" ", "_"))
        bpy.ops.wm.save_as_mainfile(filepath=os.path.abspath(blend_path))
        print("%s -> %s" % (family, blend_path))

    print("\n%d assets exported to %s" % (total, os.path.abspath(out_dir)))
    print("Import check: a 4-stud tile must measure exactly 4.00 studs in Studio.")
    print("Then paste each id into assets/manifest.json and set status to 'uploaded'.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
