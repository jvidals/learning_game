"""Editable Playful Spark source. Run with Blender --background --python.

All coordinates are metres: forward is -X, left is -Y, up is +Z.
The saved armature/actions, not independent drawings, own every attachment.
"""
import argparse
import json
import math
from pathlib import Path
import sys

import bpy
from mathutils import Vector

HERE = Path(__file__).resolve().parent
SPEC = json.loads((HERE / "animation_spec.json").read_text())
PI = math.pi
RIG = None
EQUIPMENT = {}
EYES = []


def material(name, color, metallic=0, hair=False):
    m = bpy.data.materials.new(name)
    m.diffuse_color = (*color, 1)
    m.use_nodes = True
    p = m.node_tree.nodes.get("Principled BSDF")
    p.inputs["Base Color"].default_value = (*color, 1)
    p.inputs["Roughness"].default_value = .42
    p.inputs["Metallic"].default_value = metallic
    aov = m.node_tree.nodes.new("ShaderNodeOutputAOV")
    aov.name = "hair"
    aov.inputs["Value"].default_value = 1 if hair else 0
    return m


def finish(o, name, mat, bone=None, equipment=None):
    o.name = name
    o.data.materials.append(mat)
    if o.type == "MESH":
        for p in o.data.polygons:
            p.use_smooth = True
    if bone:
        bind(o, bone)
    if equipment:
        EQUIPMENT.setdefault(equipment, []).append(o)
    return o


def bind(o, bone):
    # Preserve the authored world transform when parenting to a posed bone.
    bpy.context.view_layer.update()
    world = o.matrix_world.copy()
    o.parent = RIG
    o.parent_type = "BONE"
    o.parent_bone = bone
    bpy.context.view_layer.update()
    o.matrix_world = world


def ellipsoid(name, at, scale, mat, bone=None, equipment=None):
    bpy.ops.mesh.primitive_uv_sphere_add(segments=24, ring_count=16, location=at)
    o = bpy.context.object
    o.scale = scale
    bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
    return finish(o, name, mat, bone, equipment)


def strand(name, points, radius, mat, bone=None, equipment=None):
    curve = bpy.data.curves.new(name, "CURVE")
    curve.dimensions = "3D"
    curve.resolution_u = 12
    curve.bevel_depth = radius
    curve.bevel_resolution = 3
    curve.resolution_u = 10
    s = curve.splines.new("BEZIER")
    s.bezier_points.add(len(points) - 1)
    for i, (p, xyz) in enumerate(zip(s.bezier_points, points)):
        p.co = xyz
        p.handle_left_type = p.handle_right_type = "AUTO"
        p.radius = .12 if i == len(points) - 1 else (0.6 if i == 0 else 1)
    o = bpy.data.objects.new(name, curve)
    bpy.context.collection.objects.link(o)
    return finish(o, name, mat, bone, equipment)


def segment(name, a, b, width, mat):
    a, b = Vector(a), Vector(b)
    o = ellipsoid(name, (a + b) / 2, (width, width, (a - b).length / 2 + width), mat)
    o.rotation_euler = (b - a).to_track_quat("Z", "Y").to_euler()
    return o


def hind_points(y):
    # Slight forward stifle and backward hock, with a straighter overall stance.
    return [(.732,y,1.42),(.650,y,1.00),(.850,y,.60),(.802,y,.16)]


def make_rig():
    global RIG
    a = bpy.data.armatures.new("Gentle foal skeleton")
    RIG = bpy.data.objects.new("Gentle foal · animation rig", a)
    bpy.context.collection.objects.link(RIG)
    bpy.context.view_layer.objects.active = RIG
    RIG.select_set(True)
    bpy.ops.object.mode_set(mode="EDIT")
    def bone(name, head, tail, parent=None, connected=False, deform=True):
        b = a.edit_bones.new(name)
        b.head, b.tail = head, tail
        b.use_deform = deform
        if parent:
            b.parent = a.edit_bones[parent]
            b.use_connect = connected
        return b
    bone("root", (0, 0, 0), (0, 0, .3), deform=False)
    bone("body", (.622, 0, 1.48), (-.55, 0, 1.55), "root")
    bone("neck", (-.55, 0, 1.55), (-.84, 0, 2.52), "body", True)
    bone("head", (-.84, 0, 2.52), (-1.22, 0, 2.77), "neck", True)
    bone("expression", (0,0,3.8), (0,0,4.0), "root", deform=False)
    bone("tail", (.902, 0, 1.6), (1.622, 0, 1.1), "body")
    for side, y in [("L", -.26), ("R", .26)]:
        bone("ear." + side, (-.75, y, 3.02), (-.62, y, 3.52), "head")
        bone("wing." + side, (-.48, y * 1.42, 1.83), (.65, y * 2, 2.06), "body")
        for kind, joints in [
            ("fore", [(-.61, y, 1.45), (-.80, y, .72), (-.77, y, .16)]),
            ("hind", hind_points(y)),
        ]:
            prefix = kind + "." + side
            for i in range(len(joints)-1):
                bone(prefix + str(i), joints[i], joints[i+1], "body" if i == 0 else prefix + str(i-1), i > 0)
            end = joints[-1]
            bone(prefix + ".foot", end, (end[0]-.15, y, end[2]), "root", deform=False)
            pole = (-2, y, .65) if kind == "fore" else (2.122, y, .6)
            bone(prefix + ".pole", pole, (pole[0], y, .85), "root", deform=False)
    bpy.ops.object.mode_set(mode="POSE")
    for side in ["L", "R"]:
        for kind, end in [("fore", 1), ("hind", 2)]:
            prefix = kind + "." + side
            b = RIG.pose.bones[prefix + str(end)]
            ik = b.constraints.new("IK")
            ik.name = "Grounded foot · fixed bend direction"
            ik.target, ik.subtarget = RIG, prefix + ".foot"
            # The rest-chain plane defines the bend; a mismatched pole angle
            # rotates the neutral leg before skinning and tears the torso.
            ik.chain_count = 2
            ik.use_stretch = False
            for n in [prefix + str(end-1), prefix + str(end)]:
                p = RIG.pose.bones[n]
                p.ik_stretch = 0
                p.lock_ik_y = True
            b.use_ik_limit_x = True
            b.ik_min_x, b.ik_max_x = -2.65, 2.65
    bpy.ops.object.mode_set(mode="OBJECT")
    RIG.show_in_front = True
    RIG.data.display_type = "STICK"
    RIG.select_set(False)


def body_mesh(coat):
    parts = [
        ellipsoid("Torso", (0, 0, 1.52), (.86, .43, .53), coat),
        ellipsoid("Shoulders", (-.52, 0, 1.63), (.42, .39, .54), coat),
        segment("Neck", (-.55, 0, 1.57), (-.84, 0, 2.62), .28, coat),
        ellipsoid("Cheeks", (-1.0, 0, 2.76), (.46, .39, .44), coat),
        ellipsoid("Muzzle", (-1.30, 0, 2.53), (.29, .285, .235), coat),
    ]
    for side, y in [("L", -.26), ("R", .26)]:
        for kind, points, radii in [
            ("fore", [(-.61,y,1.45),(-.80,y,.72),(-.77,y,.16)], [.13,.105]),
            ("hind", [(.61,y,1.42),(.38,y,1.00),(.78,y,.60),(.68,y,.16)], [.20,.13,.10]),
        ]:
            for i, r in enumerate(radii):
                parts.append(segment(kind + side + str(i), points[i], points[i+1], r, coat))
    bpy.ops.object.select_all(action="DESELECT")
    for o in parts:
        o.select_set(True)
    bpy.context.view_layer.objects.active = parts[0]
    bpy.ops.object.join()
    o = bpy.context.object
    o.name = "Continuous coat · weighted skin"
    bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)
    remesh = o.modifiers.new("Continuous neck and limb topology", "REMESH")
    remesh.mode = "VOXEL"
    remesh.voxel_size = .035
    bpy.ops.object.modifier_apply(modifier=remesh.name)
    smooth = o.modifiers.new("Soft coat", "SMOOTH")
    smooth.factor, smooth.iterations = 1.25, 5
    bpy.ops.object.modifier_apply(modifier=smooth.name)
    for p in o.data.polygons:
        p.use_smooth = True
    groups = {b.name: o.vertex_groups.new(name=b.name) for b in RIG.data.bones if b.use_deform and not b.name.startswith(("ear", "wing", "tail"))}
    def distance(p, b):
        a, delta = b.head_local, b.tail_local-b.head_local
        return (p-a-delta * max(0, min(1, (p-a).dot(delta)/delta.length_squared))).length
    for v in o.data.vertices:
        p = v.co
        # Continuous anatomical blend bands avoid discontinuities at the
        # chest/shoulder boundary when a foreleg folds beneath the body.
        leg_weight = 1 - ease((p.z-1.04)/.62)
        if p.z > 1.04:
            leg_weight *= ease((abs(p.y)-.025)/.19)
            leg_weight *= ease((abs(p.x)-.12)/.32)
        kind = "fore" if p.x < -.15 else "hind"
        side = "L" if p.y < 0 else "R"
        names = [n for n in groups if n.startswith(kind+"."+side)]
        weights = [(n, 1/max(.035,distance(p,RIG.data.bones[n]))**3) for n in names]
        total=sum(w for _,w in weights)
        for n,w in weights:
            groups[n].add([v.index],leg_weight*w/total,"REPLACE")
        head_weight=max(ease((p.z-2.28)/.36),ease((-p.x-.90)/.20))
        neck_weight=ease((-p.x-.24)/.42)*ease((p.z-1.30)/.65)*(1-head_weight)
        for n,w in [("head",head_weight),("neck",neck_weight),("body",1-head_weight-neck_weight)]:
            groups[n].add([v.index],(1-leg_weight)*w,"REPLACE")
    arm = o.modifiers.new("Anatomical skeleton", "ARMATURE")
    arm.object = RIG
    arm.use_deform_preserve_volume = True
    correct=o.modifiers.new("Preserve shoulder volume", "CORRECTIVE_SMOOTH")
    correct.factor=.5
    correct.iterations=4
    sub = o.modifiers.new("Smooth silhouette", "SUBSURF")
    sub.levels = sub.render_levels = 1
    o.parent = RIG


def make_face(coat, pink, hair, gold, purple, ink, white):
    for side, sign in [("L", -1), ("R", 1)]:
        y = sign*.295
        outer = ellipsoid("Ear " + side, (-.76, y, 3.19), (.14,.115,.30), coat, "ear."+side)
        inner = ellipsoid("Inner ear " + side, (-.81,y+.048*sign,3.22), (.078,.075,.20), pink, "ear."+side)
        outer.rotation_euler.x -= sign * .25
        inner.rotation_euler.x -= sign * .25
        cheek = material("Cheek blush " + side, (.94, .58, .65))
        ellipsoid("Rosy cheek " + side, (-1.10, sign * .358, 2.59), (.105, .018, .065), cheek, "head")
        eye = ellipsoid("Eye white " + side, (-1.15, sign*.346, 2.83), (.215,.050,.25), white, "head")
        EYES.append(eye)
        eye = ellipsoid("Violet iris " + side, (-1.195, sign*.391, 2.83), (.142,.027,.20), purple, "head")
        EYES.append(eye)
        eye = ellipsoid("Pupil " + side, (-1.22, sign*.417, 2.85), (.080,.018,.145), ink, "head")
        EYES.append(eye)
        for x,z,r in [(-1.28,2.94,.041),(-1.21,2.79,.018)]:
            EYES.append(ellipsoid("Eye sparkle " + side, (x+.03,sign*.438,z), (r,.010,r), white,"head"))
        strand("Upper lashes " + side, [(-1.35,sign*.37,3.005),(-1.22,sign*.405,3.095),(-1.06,sign*.372,3.075),(-1.005,sign*.38,3.12)], .017,ink,"head")
        ellipsoid("Nostril "+side,(-1.49, sign*.215,2.57),(.048,.025,.031),pink,"head")
        smile = strand("Smile "+side,[(-1.535,sign*.10,2.465),(-1.43,sign*.22,2.425),(-1.26,sign*.28,2.485)],.012,pink,"head")
        # One small smile shape, driven by the existing expression control.
        smile.shape_key_add(name="Relaxed smile")
        happy = smile.shape_key_add(name="Happy smile")
        for point, lift in zip(happy.data, (.012, -.015, .05)):
            point.co.z += lift
            point.handle_left.z += lift
            point.handle_right.z += lift
        driver = happy.driver_add("value").driver
        variable = driver.variables.new()
        variable.name = "joy"
        variable.targets[0].id = RIG
        variable.targets[0].data_path = 'pose.bones["expression"].scale[1]'
        driver.expression = "max(0, min(1, joy - 1))"
    for eye in EYES:
        driver=eye.driver_add("scale",2).driver
        variable=driver.variables.new()
        variable.name="openness"
        variable.targets[0].id=RIG
        variable.targets[0].data_path='pose.bones["expression"].scale[0]'
        driver.expression="max(0.035, openness)"
    # A tapered horn with a fine golden spiral, rooted in the forehead.
    bpy.ops.mesh.primitive_cone_add(vertices=40, radius1=.12, radius2=.008, depth=.59, location=(-1.12,0,3.32))
    horn = bpy.context.object
    horn.rotation_euler[1] = -.26
    finish(horn,"Golden horn",gold,"head")
    spiral=[]
    for i in range(100):
        t=i/99
        r=.116*(1-t)+.005
        spiral.append((-1.05-.15*t+r*math.cos(t*6*PI), r*math.sin(t*6*PI),3.035+.57*t))
    strand("Horn spiral",spiral,.010,gold,"head")
    # Sculpted, flowing locks with tapered ends, not flat camera cards.
    for i in range(5):
        y=(i-2)*.105
        strand("Mane lock %d"%i,[(-.48,y,2.79),(-.27,y,2.62),(-.42,y,2.43),(-.11,y,2.1),(-.15,y,1.84),(-.32,y,1.82)], .12 if i<4 else .09,hair,"neck")
    for i in range(5):
        y=(i-2)*.10
        strand("Tail ribbon %d"%i,[(.79,y,1.63),(1.30,y,1.80),(1.49,y,1.52),(1.30,y,1.25),(1.25,y,.97),(1.49,y,.98),(1.52,y,1.14)], .13,hair,"tail")
    for side,y in [("L",-.26),("R",.26)]:
        for kind,x in [("fore",-.77),("hind",.68)]:
            hoof=ellipsoid("Lavender hoof " + kind+side,(x-.03,y,.13),(.17,.145,.115),purple,kind+"."+side+".foot")


def make_equipment(gold, pink, white, purple):
    mint=material("Mint leaves",(.25,.66,.46))
    petal=material("Blossom petals",(.98,.48,.66))
    blue=material("Sky blue",(.26,.64,.94))
    palette=[petal,material("Peach",(1,.66,.32)),gold,mint,blue,purple]
    # Crown rings lie on the upper head, behind the horn and in front of ears.
    for item,mat in [("flower",mint),("star",gold)]:
        points=[(-.99+.32*math.cos(i*2*PI/40),.35*math.sin(i*2*PI/40),3.115+.025*math.cos(i*2*PI/40)) for i in range(41)]
        strand(item+" crown band",points,.024,mat,"head",item)
    for i in range(9):
        t=i*2*PI/9
        c=Vector((-.99+.32*math.cos(t),.35*math.sin(t),3.15))
        for j in range(5):
            a=j*2*PI/5
            ellipsoid("Flower petal",c+Vector((.055*math.cos(a),.055*math.sin(a),.025)),(.054,.045,.029),white if i%2 else petal,"head","flower")
        ellipsoid("Flower heart",c+Vector((0,0,.053)),(.032,.032,.028),gold,"head","flower")
    for i in range(7):
        t=i*2*PI/7
        c=Vector((-.99+.32*math.cos(t),.35*math.sin(t),3.32))
        vertices=[]
        # Small solid five-point stars tangent to the fitted crown band.
        for depth in [-.014,.014]:
            for j in range(10):
                a=j*PI/5+PI/2
                r=.105 if j%2==0 else .048
                vertices.append(tuple(c+Vector((r*math.cos(a)*math.sin(t)+depth*math.cos(t),-r*math.cos(a)*math.cos(t)+depth*math.sin(t),r*math.sin(a)))))
        faces=[tuple(range(9,-1,-1)),tuple(range(10,20))]+[(j,(j+1)%10,(j+1)%10+10,j+10) for j in range(10)]
        mesh=bpy.data.meshes.new("Crown star")
        mesh.from_pydata(vertices,[],faces)
        o=bpy.data.objects.new("Crown star",mesh)
        bpy.context.collection.objects.link(o)
        finish(o,"Crown star",gold,"head","star")
    for x,z,angle in [(-.83,3.13,-.35),(-.56,3.20,.35)]:
        o=ellipsoid("Bow loop",(x,-.38,z),(.16,.064,.105),petal,"head","bow")
        o.rotation_euler[1]+=angle
    ellipsoid("Bow knot",(-.70,-.41,3.15),(.075,.066,.075),pink,"head","bow")
    for dx in [-.065,.065]:
        strand("Bow ribbon",[(-.70+dx,-.39,3.13),(-.69+dx,-.40,3.00),(-.59+dx,-.41,2.94)],.045,petal,"head","bow")
    for side,sign in [("L",-1),("R",1)]:
        root=Vector((-.48,sign*.37,1.83))
        bone="wing."+side
        for item in ["feather","rainbow"]:
            strand(item+" shoulder",[root,root+Vector((.28,sign*.17,.22)),root+Vector((.73,sign*.28,.32))],.095,white if item=="feather" else blue,bone,item)
            for i in range(8):
                start=root+Vector((.09+i*.075,sign*(.035+i*.025),.025+i*.033))
                end=root+Vector((.54+i*.10,sign*(.11+i*.042),-.29+i*.055))
                feather=segment(item+" plume",start,end,.068,white if item=="feather" else palette[min(5,i*6//8)])
                bind(feather,bone)
                EQUIPMENT.setdefault(item,[]).append(feather)
        # Both butterfly lobes sweep aft from the same shoulder socket.
        for center,scale in [((.48,sign*.21,.34),(.54,.035,.29)),((.39,sign*.14,-.16),(.39,.03,.20))]:
            c=root+Vector(center)
            lobe=ellipsoid("Butterfly violet edge",c,scale,purple,bone,"butterfly")
            for offset in [-1,1]:
                ellipsoid("Butterfly pastel membrane",c+Vector((-.015,offset*.032,0)),(scale[0]*.83,.011,scale[2]*.75),blue,bone,"butterfly")
            for j in range(5):
                ellipsoid("Butterfly pearl",c+Vector(((j-2)*.15,sign*.045,.10)),(.025,.014,.025),white,bone,"butterfly")


def sculpt_proportions():
    """Compact foal limbs/neck and a larger face, preserving weighted topology.

    Apply the same rest-space map to skin, bone sockets and fitted equipment.
    Animation remains entirely bone based after this authoring-only operation.
    """
    from mathutils import Matrix

    def sculpt(point):
        p = point.copy()
        face = ease((p.z - 2.22) / .40)
        p.x = -1 + (p.x + 1) * (1 + .13 * face)
        p.y *= 1 + .16 * face
        p.z = p.z * .80 if p.z < 2.40 else 1.92 + (p.z - 2.40) * 1.10
        return p

    objects = [o for o in bpy.context.scene.objects if o.type in ('MESH', 'CURVE')]
    attachments = {}
    for obj in objects:
        world = obj.matrix_world.copy()
        if obj.parent_type == 'BONE':
            attachments[obj.name] = obj.parent_bone
        obj.parent = None
        if obj.type == 'MESH':
            for vertex in obj.data.vertices:
                vertex.co = sculpt(world @ vertex.co)
        else:
            # Shape keys use local coordinates too; transform every key block.
            keys = obj.data.shape_keys
            if keys:
                for block in keys.key_blocks:
                    for point in block.data:
                        point.co = sculpt(world @ point.co)
                        point.handle_left = sculpt(world @ point.handle_left)
                        point.handle_right = sculpt(world @ point.handle_right)
            else:
                for spline in obj.data.splines:
                    for point in spline.bezier_points:
                        left, right = point.handle_left.copy(), point.handle_right.copy()
                        point.co = sculpt(world @ point.co)
                        point.handle_left = sculpt(world @ left)
                        point.handle_right = sculpt(world @ right)
        obj.matrix_world = Matrix.Identity(4)
        if obj in EYES:
            center = sum((v.co for v in obj.data.vertices), Vector()) / len(obj.data.vertices)
            for vertex in obj.data.vertices:
                vertex.co -= center
            obj.location = center
    bpy.context.view_layer.objects.active = RIG
    RIG.select_set(True)
    bpy.ops.object.mode_set(mode='EDIT')
    # Connected children follow their parent's edited endpoint immediately.
    # Snapshot first so no joint is transformed twice during the rest sculpt.
    rest = {bone.name: (sculpt(bone.head), sculpt(bone.tail))
            for bone in RIG.data.edit_bones}
    for bone in RIG.data.edit_bones:
        bone.head, bone.tail = rest[bone.name]
    bpy.ops.object.mode_set(mode='OBJECT')
    RIG.select_set(False)
    bpy.context.view_layer.update()
    for obj in objects:
        if obj.name in attachments:
            bind(obj, attachments[obj.name])
        elif any(m.type == 'ARMATURE' for m in obj.modifiers):
            obj.parent = RIG


def outfit(headwear="none", wings="none"):
    for name, objects in EQUIPMENT.items():
        for o in objects:
            o.hide_render = name not in (headwear,wings)
            o.hide_set(o.hide_render)


def ease(t):
    t=max(0,min(1,t))
    return t*t*(3-2*t)


def pulse(t, center, radius):
    distance = abs(t - center) / radius
    return 1 - ease(distance) if distance < 1 else 0


def pose(clip, t, update=True):
    for p in RIG.pose.bones:
        p.rotation_mode="XYZ"
        p.rotation_euler=(0,0,0)
        p.location=(0,0,0)
        p.scale=(1,1,1)
    RIG.rotation_euler=(0,0,0)
    for o in EYES:
        o.hide_render=False
    bones=RIG.pose.bones
    response=math.sin(PI*max(0,min(1,t)))
    if clip=="idle":
        # Compact smooth pulses leave quiet rests and zero velocity at the seam.
        blink = max(pulse(t, .165, .022), pulse(t, .535, .020),
                    pulse(t, .842, .024))
        bones["expression"].scale.x = 1 - .965 * blink
        # World-space lateral weight shift, with independent ground controls.
        shift = .018 * pulse(t, .29, .18) - .012 * pulse(t, .70, .14)
        bones["body"].location = bones["body"].bone.matrix_local.to_3x3().inverted() @ Vector((0, shift, 0))
        bones["head"].rotation_euler[1] = math.radians(2.5) * pulse(t, .43, .17)
        bones["ear.L"].rotation_euler[1] = .10 * pulse(t, .24, .045)
        bones["ear.R"].rotation_euler[1] = -.085 * pulse(t, .64, .05)
        bones["tail"].rotation_euler[1] = .055 * pulse(t, .73, .17) - .035 * pulse(t, .14, .10)
    if clip=="bowing":
        a=ease(t/.35)*(1-ease((t-.65)/.35))
        # Body lowers forward; foot controls stay in root/world space.
        bones["body"].location[2]=-.02*a
        bones["body"].rotation_euler[0]=-.18*a
        bones["neck"].rotation_euler[0]=-.35*a
        bones["head"].rotation_euler[0]=-.20*a
        # Bone-local foot X points toward the world +Y direction; convert
        # world-space displacement explicitly rather than guessing axes.
        foot_offset("fore.L",Vector((.28,0,.48))*a)
        foot_offset("fore.R",Vector((-.40,0,0))*a)
    if clip in ("hop","happy","simple"):
        lift=(.42 if clip=="hop" else .075 if clip=="happy" else .13)*response
        bones["root"].location.z=lift
        bones["head"].rotation_euler[0]=-.10*response
        if clip=="happy":
            bones["expression"].scale.x=1-.965*response
            bones["expression"].scale.y=1+response
        if clip=="hop":
            foot_offset("fore.L",Vector((.10,0,.13))*response)
            foot_offset("fore.R",Vector((.10,0,.13))*response)
    if clip=="twirl":
        turn=ease((t-.08)/.84)
        RIG.rotation_euler.z=turn*2*PI
        bones["tail"].rotation_euler[1]=.18*response
        for side in ("L","R"):
            bones["wing."+side].rotation_euler[1]=(.08 if side=="L" else -.08)*response
        for i,name in enumerate(("fore.L","hind.R","fore.R","hind.L")):
            step=math.sin(turn*4*PI+i*PI/2)
            foot_offset(name,Vector((0,0,.065*max(0,step)*response)))
    if update:
        bpy.context.view_layer.update()


def foot_offset(name, displacement):
    p=RIG.pose.bones[name+".foot"]
    p.location=p.bone.matrix_local.to_3x3().inverted() @ displacement


def setup_scene():
    bpy.ops.object.select_all(action="SELECT")
    bpy.ops.object.delete(use_global=False)
    s=bpy.context.scene
    s.render.engine="BLENDER_EEVEE"
    s.eevee.use_gtao=True
    s.eevee.gtao_distance=3
    s.eevee.gtao_factor=1.12
    s.eevee.taa_render_samples=16
    s.render.film_transparent=True
    s.render.resolution_x=s.render.resolution_y=SPEC["size"]
    s.render.resolution_percentage=100
    s.render.image_settings.file_format="PNG"
    s.render.image_settings.color_mode="RGBA"
    s.render.image_settings.color_depth="8"
    s.render.fps=60
    s.view_settings.view_transform="AgX"
    s.view_settings.look="AgX - Medium High Contrast"
    s.world.color=(.45,.42,.48)
    bpy.ops.object.camera_add(location=(-5.6,-9.5,4.1))
    camera=bpy.context.object
    camera.name="Fixed orthographic review camera"
    camera.rotation_euler=(Vector((-.03,0,1.48))-camera.location).to_track_quat("-Z","Y").to_euler()
    camera.data.type="ORTHO"
    camera.data.ortho_scale=4.55
    s.camera=camera
    for name,at,power,size,color in [("Soft key",(-3,-4,7),650,5,(1,.87,.81)),("Lavender fill",(2,-2,4),350,4,(.78,.83,1)),("Hair rim",(1,4,6),750,4,(1,.88,.95))]:
        bpy.ops.object.light_add(type="AREA",location=at)
        light=bpy.context.object
        light.name=name
        light.data.energy=power
        light.data.shape="DISK"
        light.data.size=size
        light.data.color=color
        light.rotation_euler=(Vector((0,0,1.5))-light.location).to_track_quat("-Z","Y").to_euler()
    aov=s.view_layers[0].aovs.add()
    aov.name="hair"
    aov.type="VALUE"
    return s


def build():
    scene=setup_scene()
    coat=material("Pearl coat",(.92,.87,.86))
    white=material("Warm white",(1,.97,.92))
    pink=material("Rose velvet",(.73,.30,.44))
    hair=material("Pink hair · recolorable",(.91,.29,.48),hair=True)
    gold=material("Soft gold",(.95,.64,.20),.3)
    purple=material("Lavender",(.44,.25,.64))
    ink=material("Deep plum",(.06,.025,.105))
    make_rig()
    body_mesh(coat)
    make_face(coat,pink,hair,gold,purple,ink,white)
    make_equipment(gold,pink,white,purple)
    sculpt_proportions()
    outfit()
    for clip, definition in SPEC["clips"].items():
        RIG.animation_data_clear()
        action=bpy.data.actions.new(clip)
        action.use_fake_user=True
        RIG.animation_data_create()
        RIG.animation_data.action=action
        count=round(definition["durationMs"]*60/1000)
        for frame in range(0,count+1,1 if clip == "idle" else 3):
            pose(clip,frame/count,update=False)
            RIG.keyframe_insert("rotation_euler",frame=frame)
            for p in RIG.pose.bones:
                p.keyframe_insert("location",frame=frame)
                p.keyframe_insert("rotation_euler",frame=frame)
                p.keyframe_insert("scale",frame=frame)
        for curve in action.fcurves:
            for key in curve.keyframe_points:
                key.interpolation="BEZIER"
                key.handle_left_type = key.handle_right_type = "AUTO_CLAMPED"
    RIG.animation_data_clear()
    pose("idle",0)
    scene["source_contract"]="forward=-X; left=-Y; up=+Z; fixed orthographic camera"
    scene["equipment"] = json.dumps({k:[o.name for o in v] for k,v in EQUIPMENT.items()})
    scene["animation_spec"] = json.dumps(SPEC)
    return scene


if __name__=="__main__":
    parser=argparse.ArgumentParser()
    parser.add_argument("--output",default=str(HERE/"gentle_foal.blend"))
    parser.add_argument("--preview",default=None)
    args=parser.parse_args(sys.argv[sys.argv.index("--")+1:] if "--" in sys.argv else [])
    scene=build()
    Path(args.output).parent.mkdir(parents=True,exist_ok=True)
    bpy.ops.wm.save_as_mainfile(filepath=str(Path(args.output).resolve()))
    if args.preview:
        outfit("star","feather")
        scene.render.filepath=str(Path(args.preview).resolve())
        bpy.ops.render.render(write_still=True)
