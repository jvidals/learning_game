"""Explicit phone-scale preflight of the saved source, before full export."""
import json
from pathlib import Path
import bpy

root = Path(__file__).resolve().parents[2] / 'artifacts/playful-spark/release-0120/preflight'
root.mkdir(parents=True, exist_ok=True)
scene = bpy.context.scene
rig = bpy.data.objects['Gentle foal · animation rig']
equipment = json.loads(scene['equipment'])
rig.animation_data_create()
for head in ('none', 'flower', 'bow', 'star'):
    for item, names in equipment.items():
        for name in names:
            bpy.data.objects[name].hide_render = item != head
    for clip, frame in (('idle', 0), ('happy', 16)):
        rig.animation_data.action = bpy.data.actions[clip]
        scene.frame_set(frame)
        scene.render.filepath = str(root / f'{head}-{clip}.png')
        bpy.ops.render.render(write_still=True)
