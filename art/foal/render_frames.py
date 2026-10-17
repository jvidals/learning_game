"""Render one fitted outfit and four isolated, visible-surface AOVs."""
import argparse
import json
from pathlib import Path
import sys
import time
import bpy

parser = argparse.ArgumentParser()
parser.add_argument("--root", required=True)
parser.add_argument("--headwear", default="star")
parser.add_argument("--wings", default="feather")
parser.add_argument("--clip", default="bowing")
parser.add_argument("--review", action="store_true")
parser.add_argument("--icons", action="store_true")
args = parser.parse_args(sys.argv[sys.argv.index("--") + 1:])
scene = bpy.context.scene
spec = json.loads(scene["animation_spec"])
rig = bpy.data.objects["Gentle foal · animation rig"]
equipment = json.loads(scene["equipment"])
for item, names in equipment.items():
    for name in names:
        bpy.data.objects[name].hide_render = item not in (args.headwear, args.wings)
scene.use_nodes = True
nodes = scene.node_tree.nodes
nodes.clear()
layers = nodes.new("CompositorNodeRLayers")
root = Path(args.root).resolve() / (args.headwear + "-" + args.wings) / args.clip
root.mkdir(parents=True, exist_ok=True)
outputs = []
for name, socket, mode in [("color", "Image", "RGBA"), ("mask", "hair", "BW"),
                           ("hooves", "hooves", "BW"), ("headwear", "headwear", "BW"),
                           ("wings", "wings", "BW")]:
    output = nodes.new("CompositorNodeOutputFile")
    output.base_path = str(root)
    output.file_slots[0].path = name + "-"
    output.format.file_format = "PNG"
    output.format.color_mode = mode
    output.format.color_depth = "8"
    if name != "color":
        output.file_slots[0].save_as_render = False
    scene.node_tree.links.new(layers.outputs[socket], output.inputs[0])
    outputs.append(output)
rig.animation_data_create()
rig.animation_data.action = bpy.data.actions[args.clip]
count = round(spec["clips"][args.clip]["durationMs"] * spec["fps"] / 1000)
scene.frame_start = 0
scene.frame_end = count - 1
scene.render.use_file_extension = True
scene.render.filepath = str(root / "preview-")
start = time.monotonic()
if args.icons:
    rig.animation_data.action = bpy.data.actions['idle']
    scene.frame_set(0)
    icons = dict(equipment)
    icons['hoof'] = ['Lavender hoof foreL']
    for item, names in icons.items():
        for obj in scene.objects:
            if obj.type in ('MESH', 'CURVE'):
                obj.hide_render = obj.name not in names
        target = Path(args.root).resolve() / 'icons' / item
        target.mkdir(parents=True, exist_ok=True)
        for output in outputs:
            output.base_path = str(target)
        bpy.ops.render.render(write_still=False)
elif args.review:
    for frame in sorted({0, count // 4, count // 2, 3 * count // 4, count - 1}):
        scene.frame_set(frame)
        bpy.ops.render.render(write_still=False)
else:
    bpy.ops.render.render(animation=True, write_still=False)
print("FOAL_RENDER", json.dumps({"outfit": args.headwear + "-" + args.wings,
      "clip": args.clip, "frames": count, "seconds": time.monotonic() - start}))
