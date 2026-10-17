"""Reward geometry and isolated material masks; keep the approved foal intact."""
import math
import bpy
from mathutils import Vector

def add_equipment(base, mesh_object, crown_point, gold, pink, white):
    up = Vector((0, 0, 1))
    points = [crown_point(i * 2 * math.pi / 96) for i in range(97)]
    base.strand('Heart tiara gold band', points, .022, gold, 'head', 'heart')
    heart_mat = base.material('Heart tiara rose gems', (.96, .35, .52))
    for i, angle in enumerate((math.pi * .60, math.pi, math.pi * 1.40)):
        center = crown_point(angle) + up * (.13 if i == 1 else .10)
        tangent = Vector((-math.sin(angle), math.cos(angle), 0))
        normal = Vector((math.cos(angle), math.sin(angle), 0))
        radius = .008 if i == 1 else .006
        outline = []
        for j in range(64):
            t = j * 2 * math.pi / 64
            x = 16 * math.sin(t) ** 3
            z = 13 * math.cos(t) - 5 * math.cos(2*t) - 2 * math.cos(3*t) - math.cos(4*t)
            outline.append(center + tangent * x * radius + up * z * radius)
        vertices = [p + normal * depth for depth in (-.016, .016) for p in outline]
        faces = [tuple(range(63, -1, -1)), tuple(range(64, 128))]
        faces += [(j, (j+1)%64, (j+1)%64+64, j+64) for j in range(64)]
        obj = mesh_object('Heart tiara gem ' + str(i), vertices, faces, heart_mat, 'head')
        base.EQUIPMENT.setdefault('heart', []).append(obj)
        bevel = obj.modifiers.new('Rounded heart edges', 'BEVEL')
        bevel.width = .008
        bevel.segments = 3
        base.strand('Heart tiara gold setting', outline + outline[:1], .008, gold, 'head', 'heart')
    membrane = base.material('Fairy pink membrane', (.96, .61, .78))
    vein = base.material('Fairy pearl veins', (.99, .89, .94))
    for side, sign in (('L', -1), ('R', 1)):
        root = Vector((-.48, sign * .37, 1.83))
        bone = 'wing.' + side
        for lower in (False, True):
            length, rise, spread = (.98, .59, .28) if not lower else (.78, -.27, .23)
            vertices = []
            rows = 20
            for i in range(rows + 1):
                t = i / rows
                width = spread * math.sin(math.pi * t) ** .8
                for across in (-1, 0, 1):
                    vertices.append(root + Vector((length*t, sign*(.08+.27*t+.035*(1-across*across)*math.sin(math.pi*t)), rise*t+across*width)))
            faces = []
            for i in range(rows):
                for j in range(2):
                    a = i*3+j
                    faces.append((a, a+1, a+4, a+3))
            obj = mesh_object('Fairy membrane '+side+str(lower), vertices, faces, membrane, bone)
            base.EQUIPMENT.setdefault('fairy', []).append(obj)
            solid = obj.modifiers.new('Soft wing thickness', 'SOLIDIFY')
            solid.thickness = .018
            smooth = obj.modifiers.new('Soft fairy surface', 'SUBSURF')
            smooth.levels = 2
            for edge in (-1, 0, 1):
                points = [vertices[i*3+edge+1] for i in range(rows+1)]
                base.strand('Fairy pearl vein', points, .012 if edge else .009, vein, bone, 'fairy')

def add_masks(scene, equipment):
    for name in ('hooves', 'headwear', 'wings'):
        aov = scene.view_layers[0].aovs.add()
        aov.name = name
        aov.type = 'VALUE'
    groups = {
        'hooves': [o for o in scene.objects if o.name.startswith('Lavender hoof ')],
        'headwear': [o for item in ('flower', 'bow') for o in equipment[item]
                     if item == 'bow' or o.name.startswith('Fitted flower petal')],
        'wings': [o for item in ('feather', 'butterfly') for o in equipment[item]
                  if item == 'feather' or o.name.startswith('Butterfly pastel membrane')],
    }
    copies = {}
    for name, objects in groups.items():
        for obj in objects:
            for slot in obj.material_slots:
                old = slot.material
                key = (old.name, name)
                if key not in copies:
                    material = old.copy()
                    material.name = old.name + ' · ' + name + ' recolor'
                    aov = material.node_tree.nodes.new('ShaderNodeOutputAOV')
                    aov.name = name
                    aov.inputs['Value'].default_value = 1
                    copies[key] = material
                slot.material = copies[key]
