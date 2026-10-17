"""Build the approved revision-five production sculpture with Blender 4.0.

Uses the production rig/actions helper; historical review sources stay frozen.
Forward -X, left -Y, up +Z. All visible face parts belong to the head bone.
"""
import argparse
import json
import math
from pathlib import Path
import sys

import bpy
from mathutils import Vector, Matrix
from mathutils.bvhtree import BVHTree

HERE = Path(__file__).resolve().parent
MODEL = HERE / 'gentle_foal.blend'
HIND_SHIFT = .122
# v01 hip-to-shoulder span is 1.22; extend it by ten percent.

sys.path.insert(0, str(HERE))
import rig_source as base
import rewards

PI = math.pi
UP = Vector((0, 0, 1))
SKIN = None
SURFACE = None
FACE_PARTS = []
BLUE = (.17, .54, .79)
PINK = (.83, .30, .49)


def mesh_object(name, vertices, faces, mat, bone=None):
    mesh = bpy.data.meshes.new(name)
    mesh.from_pydata(vertices, [], faces)
    mesh.update()
    obj = bpy.data.objects.new(name, mesh)
    bpy.context.collection.objects.link(obj)
    return base.finish(obj, name, mat, bone)


def eye_frame(sign):
    n = Vector((-.60, sign * .80, 0)).normalized()
    h = Vector((.80, sign * .60, 0)).normalized()
    return n, h


def hit(point, normal):
    location, _, _, _ = SURFACE.ray_cast(Vector(point) + normal * 3, -normal, 6)
    if location is None:
        raise RuntimeError('Face projection missed the coat: ' + str(tuple(point)))
    return location


def blush_attribute(obj):
    if obj.type != 'MESH':
        return
    att = obj.data.color_attributes.new(name='cheek_tint', type='FLOAT_COLOR', domain='POINT')
    for v, c in zip(obj.data.vertices, att.data):
        x, y, z = v.co
        amount = .70 * math.exp(-((x + 1.43) / .20)**2 - ((abs(y) - .30) / .15)**2 - ((z - 2.69) / .105)**2)
        c.color = (amount, amount, amount, 1)


def skin_material(coat):
    p = coat.node_tree.nodes.get('Principled BSDF')
    p.inputs['Roughness'].default_value = .50
    p.inputs['Subsurface Weight'].default_value = .065
    p.inputs['Subsurface Radius'].default_value = (1, .45, .30)
    attr = coat.node_tree.nodes.new('ShaderNodeVertexColor')
    attr.layer_name = 'cheek_tint'
    mix = coat.node_tree.nodes.new('ShaderNodeMixRGB')
    mix.inputs[1].default_value = (.89, .82, .73, 1)
    mix.inputs[2].default_value = (.96, .40, .47, 1)
    coat.node_tree.links.new(attr.outputs['Color'], mix.inputs[0])
    coat.node_tree.links.new(mix.outputs[0], p.inputs['Base Color'])


def body_mesh(coat):
    global SKIN, SURFACE
    parts = [
        base.ellipsoid('Barrel', (.111, 0, 1.54), (.821, .365, .43), coat),
        base.ellipsoid('Round shoulder', (-.48, 0, 1.65), (.36, .34, .46), coat),
        base.segment('Rising neck', (-.52, 0, 1.67), (-.82, 0, 2.64), .242, coat),
        base.ellipsoid('Upper neck', (-.79, 0, 2.49), (.242, .264, .39), coat),
        base.ellipsoid('Round forehead', (-.95, 0, 2.98), (.49, .435, .535), coat),
        base.segment('Sloping nasal bridge', (-1.12, 0, 2.94), (-1.53, 0, 2.68), .245, coat),
        base.ellipsoid('Equine velvet muzzle', (-1.56, 0, 2.65), (.33, .30, .25), coat),
        # One tapered jaw replaces the three overlapping cheek/chin lobes.
        base.ellipsoid('Equine lower jaw', (-1.25, 0, 2.63), (.335, .285, .225), coat),
    ]
    for side, y in [('L', -.26), ('R', .26)]:
        for kind, points, widths in [
            ('fore', [(-.61, y, 1.45), (-.80, y, .72), (-.77, y, .16)], [.155, .115]),
            ('hind', base.hind_points(y), [.21, .135, .11]),
        ]:
            for i, w in enumerate(widths):
                parts.append(base.segment(kind + side + str(i), points[i], points[i + 1], w, coat))
    bpy.ops.object.select_all(action='DESELECT')
    for obj in parts:
        obj.select_set(True)
    bpy.context.view_layer.objects.active = parts[0]
    bpy.ops.object.join()
    SKIN = bpy.context.object
    SKIN.name = 'Continuous coat · weighted skin'
    bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)
    remesh = SKIN.modifiers.new('Unified sculpt', 'REMESH')
    remesh.mode = 'VOXEL'
    remesh.voxel_size = .020
    bpy.ops.object.modifier_apply(modifier=remesh.name)
    smooth = SKIN.modifiers.new('Sculpt smoothing', 'SMOOTH')
    smooth.factor, smooth.iterations = 1.1, 7
    bpy.ops.object.modifier_apply(modifier=smooth.name)
    SURFACE = BVHTree.FromPolygons([v.co.copy() for v in SKIN.data.vertices], [list(p.vertices) for p in SKIN.data.polygons])
    skin_material(coat)


def bind_skin():
    obj = SKIN
    blush_attribute(obj)
    groups = {b.name: obj.vertex_groups.new(name=b.name) for b in base.RIG.data.bones
              if b.use_deform and not b.name.startswith(('ear', 'wing', 'tail'))}
    def distance(p, b):
        a, delta = b.head_local, b.tail_local - b.head_local
        return (p - a - delta * max(0, min(1, (p-a).dot(delta) / delta.length_squared))).length
    for v in obj.data.vertices:
        p = v.co
        lw = 1 - base.ease((p.z - 1.04) / .62)
        if p.z > 1.04:
            lw *= base.ease((abs(p.y) - .025) / .19) * base.ease((abs(p.x) - .12) / .32)
        prefix = ('fore' if p.x < -.15 else 'hind') + '.' + ('L' if p.y < 0 else 'R')
        weights = [(n, 1 / max(.035, distance(p, base.RIG.data.bones[n]))**3) for n in groups if n.startswith(prefix)]
        total = sum(w for _, w in weights)
        for n, w in weights:
            groups[n].add([v.index], lw * w / total, 'REPLACE')
        hw = max(base.ease((p.z - 2.28) / .36), base.ease((-p.x - .90) / .20))
        nw = base.ease((-p.x - .24) / .42) * base.ease((p.z - 1.30) / .65) * (1 - hw)
        for n, w in [('head', hw), ('neck', nw), ('body', 1 - hw - nw)]:
            groups[n].add([v.index], (1 - lw) * w, 'REPLACE')
    for p in obj.data.polygons:
        p.use_smooth = True
    arm = obj.modifiers.new('Anatomical skeleton', 'ARMATURE')
    arm.object = base.RIG
    arm.use_deform_preserve_volume = True
    correct = obj.modifiers.new('Preserve shoulder volume', 'CORRECTIVE_SMOOTH')
    correct.factor, correct.iterations = .5, 4
    smoothing=obj.vertex_groups.new(name='Body smoothing outside lip seam')
    for v in obj.data.vertices:
        smoothing.add([v.index],0 if v.co.x< -1.35 and v.co.z<2.72 else 1,'REPLACE')
    correct.vertex_group=smoothing.name
    sub = obj.modifiers.new('Soft sculpture', 'SUBSURF')
    sub.levels = sub.render_levels = 1
    obj.parent = base.RIG


def cutter(name, center, normal, horizontal, radius_u, radius_v, depth=.40, profile=None):
    vertices = []
    if profile is None:
        profile=[(radius_u*math.cos(i*2*PI/64),radius_v*math.sin(i*2*PI/64)) for i in range(64)]
    count = len(profile)
    for d in (-depth, depth):
        for u,v in profile:
            vertices.append(center + normal*d + horizontal*u + UP*v)
    faces = [tuple(range(count-1, -1, -1)), tuple(range(count, 2*count))]
    faces += [(i, (i+1) % count, (i+1) % count + count, i+count) for i in range(count)]
    if horizontal.cross(UP).dot(normal) < 0:
        faces = [tuple(reversed(f)) for f in faces]
    obj = mesh_object(name, vertices, faces, SKIN.data.materials[0])
    bpy.context.view_layer.objects.active = SKIN
    mod = SKIN.modifiers.new(name, 'BOOLEAN')
    mod.operation, mod.solver, mod.object = 'DIFFERENCE', 'EXACT', obj
    bpy.ops.object.modifier_apply(modifier=mod.name)
    bpy.data.objects.remove(obj, do_unlink=True)


def driver(block, expression, channel):
    d = block.driver_add('value').driver
    var = d.variables.new()
    var.name = 'control'
    var.targets[0].id = base.RIG
    var.targets[0].data_path = f'pose.bones["expression"].scale[{channel}]'
    d.expression = expression


def smile_with_open_eyes(key):
    f=key.id_data.animation_data.drivers.find(key.path_from_id('value'))
    var=f.driver.variables.new();var.name='openness'
    var.targets[0].id=base.RIG
    var.targets[0].data_path='pose.bones["expression"].scale[0]'
    f.driver.expression='max(0, min(1, control-1)) * max(0, min(1, (openness-.035)/.965))'


def morph_mesh(obj, name, vertices, expression, channel):
    if not obj.data.shape_keys:
        obj.shape_key_add(name='Basis')
    key = obj.shape_key_add(name=name)
    for vertex, position in zip(key.data, vertices):
        vertex.co = position
    driver(key, expression, channel)


def morph_curve(obj, name, coordinates, expression, channel):
    if not obj.data.shape_keys:
        obj.shape_key_add(name='Basis')
    key = obj.shape_key_add(name=name)
    # Automatic handles are stored in the key; compute from a temporary curve.
    copy = obj.data.copy()
    for point, xyz in zip(copy.splines[0].bezier_points, coordinates):
        point.co = xyz
    temp = bpy.data.objects.new('Temporary morph handles', copy)
    bpy.context.collection.objects.link(temp)
    bpy.context.view_layer.update()
    for dst, src in zip(key.data, copy.splines[0].bezier_points):
        dst.co, dst.handle_left, dst.handle_right = src.co, src.handle_left, src.handle_right
    bpy.data.objects.remove(temp, do_unlink=True)
    driver(key, expression, channel)


def blink_clearance_keys(obj, opened, shut, intermediate, curve=False, smiling=None, happy_intermediate=None):
    """Keep intermediate lids on the facial surface rather than a globe chord."""
    for fraction,target in intermediate.items():
        corrected=[a + desired - a.lerp(b,fraction) for a,b,desired in zip(opened,shut,target)]
        expression=f'max(0, 1-abs((1-control)/.965-{fraction})/.25)'
        if curve:
            morph_curve(obj,f'Blink clearance {fraction:.2f}',corrected,expression,0)
        else:
            morph_mesh(obj,f'Blink clearance {fraction:.2f}',corrected,expression,0)
        if smiling is not None:
            combined=[a + h - r - (smile-a)*(1-fraction) for a,smile,r,h in zip(opened,smiling,target,happy_intermediate[fraction])]
            name=f'Happy blink clearance {fraction:.2f}'
            if curve: morph_curve(obj,name,combined,expression,0)
            else: morph_mesh(obj,name,combined,expression,0)
            key=obj.data.shape_keys.key_blocks[name]
            f=key.id_data.animation_data.drivers.find(key.path_from_id('value'))
            joy=f.driver.variables.new();joy.name='joy';joy.targets[0].id=base.RIG
            joy.targets[0].data_path='pose.bones["expression"].scale[1]'
            f.driver.expression=expression+' * max(0, min(1, joy-1))'


def make_eye(sign, coat, white, ink):
    side = 'L' if sign < 0 else 'R'
    n, h = eye_frame(sign)
    surface = hit(Vector((-1.17, sign*.35, 2.98)), n)
    center = surface - n * .0963
    eye_scale = .90
    rx, rz, depth = .1935, .2358, .108
    def globe(u, v, offset=0):
        d = depth * math.sqrt(max(0, 1 - (u/rx)**2 - (v/rz)**2))
        return center + h*u + UP*v + n*(d+offset)
    cutter('Sculpted eye socket ' + side, center + n*.12, n, h, .2124, .2556)
    # A round, permanent globe. Eyelids cover it; the globe never squashes.
    vertices, faces = [], []
    for j in range(49):
        lat = PI*j/48
        for i in range(64):
            a = 2*PI*i/64
            vertices.append(center + h*(rx*math.sin(lat)*math.cos(a)) + UP*(rz*math.cos(lat)) + n*(depth*math.sin(lat)*math.sin(a)))
    for j in range(48):
        for i in range(64):
            k = j*64+i
            faces.append((k, j*64+(i+1)%64, (j+1)*64+(i+1)%64, k+64))
    eye = mesh_object('Inset eye globe ' + side, vertices, faces, white, 'head')
    FACE_PARTS.append(eye.name)
    # Iris is a colored spherical cap, following the surface of the globe.
    iris = base.material('Violet iris ' + side, (.32, .10, .52))
    iris.node_tree.nodes.get('Principled BSDF').inputs['Roughness'].default_value = .27
    attribute = iris.node_tree.nodes.new('ShaderNodeVertexColor')
    attribute.layer_name = 'iris_color'
    iris.node_tree.links.new(attribute.outputs['Color'], iris.node_tree.nodes.get('Principled BSDF').inputs['Base Color'])
    verts, faces, colors = [], [], []
    for j in range(33):
        r = j/32
        for i in range(96):
            a = 2*PI*i/96
            u = eye_scale*(-.025 + .148*r*math.cos(a))
            v = eye_scale*(-.012 + .190*r*math.sin(a))
            verts.append(globe(u, v, .0015))
            if r < .57:
                col = (.032, .012, .060)
            else:
                light = .65 + .20*math.cos(a+1.1) + .035*math.sin(a*39) + .025*math.sin(a*71)
                rim = 1 - .65*base.ease((r-.83)/.17)
                col = (.39*light*rim, .15*light*rim, .68*light*rim)
            colors.append((*col, 1))
    for j in range(32):
        for i in range(96):
            k=j*96+i
            faces.append((k,j*96+(i+1)%96,(j+1)*96+(i+1)%96,k+96))
    obj = mesh_object('Iris in globe ' + side, verts, faces, iris, 'head')
    attr = obj.data.color_attributes.new(name='iris_color', type='FLOAT_COLOR', domain='POINT')
    for datum, color in zip(attr.data, colors): datum.color = color
    for i,(u,v,r) in enumerate([(-.071,.087,.035),(.044,-.090,.015)]):
        u,v,r=u*eye_scale,v*eye_scale,r*eye_scale
        # Small catchlights hug the same globe, without tall stacked layers.
        pts = [globe(u, v, .004)]
        for k in range(40):
            a=2*PI*k/40
            pts.append(globe(u+r*math.cos(a),v+r*math.sin(a),.004))
        mesh_object('Soft catchlight '+side+str(i),pts,[(0,k+1,(k+1)%40+1) for k in range(40)],white,'head')
    def inner(a, closed=False, smiling=False):
        u = .171*math.cos(a)
        seam = .0108 + .06318*(1 - (u/.171)**2)
        v = seam if closed else ((.2016 if math.sin(a)>=0 else .1737)*math.sin(a)+.0063)
        if smiling and not closed:
            v = .0063 + (v-.0063)*(.945 if math.sin(a)>=0 else .85)
        return u, v
    def lidpoint(u,v):
        original=hit(center+h*u+UP*v,n)
        d=(original-center).dot(n)
        q=1-(u/rx)**2-(v/rz)**2
        if q>0: d=max(d,depth*math.sqrt(q)+.009)
        return center+h*u+UP*v+n*(d+.002)
    vertices, closed, smiling, faces = [], [], [], []
    intermediate={fraction:[] for fraction in (.25,.5,.75)}
    happy_intermediate={fraction:[] for fraction in (.25,.5,.75)}
    count, rings=96,10
    for j in range(rings+1):
        t=j/rings
        for i in range(count):
            a=i*2*PI/count
            u,v=inner(a)
            uc,vc=inner(a,True)
            us,vs=inner(a,smiling=True)
            uo,vo=.2682*math.cos(a),.3159*math.sin(a)
            vertices.append(lidpoint(u*(1-t)+uo*t,v*(1-t)+vo*t))
            closed.append(lidpoint(uc*(1-t)+uo*t,vc*(1-t)+vo*t))
            smiling.append(lidpoint(us*(1-t)+uo*t,vs*(1-t)+vo*t))
            for fraction,points in intermediate.items():
                points.append(lidpoint((u*(1-fraction)+uc*fraction)*(1-t)+uo*t,(v*(1-fraction)+vc*fraction)*(1-t)+vo*t))
                happy_intermediate[fraction].append(lidpoint((us*(1-fraction)+uc*fraction)*(1-t)+uo*t,(vs*(1-fraction)+vc*fraction)*(1-t)+vo*t))
    for j in range(rings):
        for i in range(count):
            k=j*count+i
            faces.append((k,j*count+(i+1)%count,(j+1)*count+(i+1)%count,k+count))
    obj=mesh_object('Sculpted eyelids '+side,vertices,faces,coat,'head')
    blush_attribute(obj)
    morph_mesh(obj,'Blink · skin closes over eye',closed,'max(0, min(1, (1-control)/0.965))',0)
    morph_mesh(obj,'Smile · soft lower eyelid lift',smiling,'max(0, min(1, control-1))',1)
    smile_with_open_eyes(obj.data.shape_keys.key_blocks[-1])
    blink_clearance_keys(obj,vertices,closed,intermediate,smiling=smiling,happy_intermediate=happy_intermediate)
    FACE_PARTS.append(obj.name)
    # The lash line follows the opening, and its morph uses those same samples.
    angles=[i*PI/14 for i in range(15)]
    upper=[lidpoint(*inner(a))+n*.004 for a in angles]
    shut=[lidpoint(*inner(a,True))+n*.004 for a in angles]
    obj=base.strand('Attached upper lash '+side,upper,.007,ink,'head')
    morph_curve(obj,'Blink · follows lid',shut,'max(0, min(1, (1-control)/0.965))',0)
    morph_curve(obj,'Smile · follows upper lid',[lidpoint(*inner(a,smiling=True))+n*.004 for a in angles],'max(0, min(1, control-1))',1)
    smile_with_open_eyes(obj.data.shape_keys.key_blocks[-1])
    intermediates={}
    for fraction in (.25,.5,.75):
        points=[]
        for a in angles:
            u,v=inner(a);uc,vc=inner(a,True)
            points.append(lidpoint(u*(1-fraction)+uc*fraction,v*(1-fraction)+vc*fraction)+n*.004)
        intermediates[fraction]=points
    happy_intermediates={}
    for fraction in (.25,.5,.75):
        points=[]
        for a in angles:
            u,v=inner(a,smiling=True);uc,vc=inner(a,True)
            points.append(lidpoint(u*(1-fraction)+uc*fraction,v*(1-fraction)+vc*fraction)+n*.004)
        happy_intermediates[fraction]=points
    blink_clearance_keys(obj,upper,shut,intermediates,curve=True,smiling=[lidpoint(*inner(a,smiling=True))+n*.004 for a in angles],happy_intermediate=happy_intermediates)

    for j,a in enumerate((.12,.29,.46)):
        start=lidpoint(*inner(a))+n*.004
        end=start+h*(.050-j*.010)+UP*(.028+j*.006)+n*.003
        closed_start=lidpoint(*inner(a,True))+n*.004
        obj=base.strand('Eyelid lash '+side+str(j),[start,(start+end)/2+UP*.009,end],.007,ink,'head')
        morph_curve(obj,'Blink · rooted in lid',[p+closed_start-start for p in [start,(start+end)/2+UP*.009,end]],'max(0, min(1, (1-control)/0.965))',0)
        smiling_start=lidpoint(*inner(a,smiling=True))+n*.004
        morph_curve(obj,'Smile · rooted in lid',[p+smiling_start-start for p in [start,(start+end)/2+UP*.009,end]],'max(0, min(1, control-1))',1)
        smile_with_open_eyes(obj.data.shape_keys.key_blocks[-1])
        points=[start,(start+end)/2+UP*.009,end]
        intermediates={}
        u,v=inner(a);uc,vc=inner(a,True)
        for fraction in (.25,.5,.75):
            root=lidpoint(u*(1-fraction)+uc*fraction,v*(1-fraction)+vc*fraction)+n*.004
            intermediates[fraction]=[p+root-start for p in points]
        happy_intermediates={}
        u,v=inner(a,smiling=True)
        for fraction in (.25,.5,.75):
            root=lidpoint(u*(1-fraction)+uc*fraction,v*(1-fraction)+vc*fraction)+n*.004
            happy_intermediates[fraction]=[p+root-start for p in points]
        blink_clearance_keys(obj,points,[p+closed_start-start for p in points],intermediates,curve=True,smiling=[p+smiling_start-start for p in points],happy_intermediate=happy_intermediates)


def make_mouth(coat, pink):
    # Split a rounded lower lip from the actual muzzle; open it around a rear hinge.
    hinge=Vector((-1.42,0,2.55))
    rotation=Matrix.Rotation(-.25,3,'Y')
    bpy.ops.mesh.primitive_cube_add(size=1,location=(-2.21,0,1.275))
    cutter_obj=bpy.context.object;cutter_obj.name='Temporary lower jaw split'
    cutter_obj.dimensions=(1.58,1.2,2.55)
    bpy.ops.object.transform_apply(location=False,rotation=False,scale=True)
    lower=SKIN.copy();lower.data=SKIN.data.copy();bpy.context.collection.objects.link(lower)
    for obj,operation in ((lower,'INTERSECT'),(SKIN,'DIFFERENCE')):
        bpy.context.view_layer.objects.active=obj
        mod=obj.modifiers.new('Anatomical mouth split','BOOLEAN')
        mod.operation=operation;mod.solver='EXACT';mod.object=cutter_obj
        bpy.ops.object.modifier_apply(modifier=mod.name)
    bpy.data.objects.remove(cutter_obj,do_unlink=True)
    # Retopologize the cut contour onto a smooth ellipse, then preserve it
    # through subdivision. This prevents voxel triangles from making scalloped lips.
    lip_center=Vector((-1.56,0,hinge.z));lip_rx=.294;lip_ry=.267
    for obj in (SKIN,lower):
        for v in obj.data.vertices:
            if abs(v.co.z-hinge.z)<.0001 and v.co.x<hinge.x-.0001:
                a=math.atan2(v.co.y/lip_ry,(v.co.x-lip_center.x)/lip_rx)
                v.co.x=lip_center.x+lip_rx*math.cos(a);v.co.y=lip_ry*math.sin(a)
        crease=obj.data.attributes.get('crease_edge') or obj.data.attributes.new('crease_edge','FLOAT','EDGE')
        for edge in obj.data.edges:
            if all(abs(obj.data.vertices[i].co.z-hinge.z)<.0001 for i in edge.vertices):crease.data[edge.index].value=1
    sub=lower.modifiers.new('Smooth lower jaw with preserved lip edge','SUBSURF');sub.levels=sub.render_levels=1
    lining=base.material('Warm equine mouth lining',(.105,.023,.026))
    for obj in (SKIN,lower):
        obj.data.materials.append(lining);index=len(obj.data.materials)-1
        for face in obj.data.polygons:
            if all(abs(obj.data.vertices[i].co.z-hinge.z)<.0001 for i in face.vertices) or all(abs(obj.data.vertices[i].co.x-hinge.x)<.0001 for i in face.vertices):
                face.material_index=index;face.use_smooth=False
    base.finish(lower,'Rounded hinged lower lip',coat,'head')
    blush_attribute(lower)
    # Tiny rounding makes the closed upper/lower lip junction visible without a painted grin.
    morph_mesh(lower,'Happy jaw opening',[hinge+rotation@(v.co-hinge) for v in lower.data.vertices],'max(0, min(1, control-1))',1)
    lower['jaw_hinge']=list(hinge);lower['opening_radians']=.25
    # Continuous rounded lip rims cover the irregular voxel-cut perimeter.
    arc=math.acos((lip_center.x-hinge.x)/lip_rx)
    upper_points=[];lower_points=[]
    for i in range(65):
        theta=-arc+2*arc*i/64;n=Vector((-math.cos(theta),math.sin(theta),0))
        point=lip_center+Vector((-lip_rx*math.cos(theta),lip_ry*math.sin(theta),0))-n*.004
        upper_points.append(point+UP*.003)
        lower_points.append(point-UP*.006)
    lip_coat=coat.copy();lip_coat.name='Muzzle-matched lip surface'
    shader=lip_coat.node_tree.nodes.get('Principled BSDF')
    for link in list(shader.inputs['Base Color'].links):lip_coat.node_tree.links.remove(link)
    shader.inputs['Base Color'].default_value=(.89,.82,.73,1)
    upper=base.strand('Rounded upper lip rim',upper_points,.006,lip_coat,'head')
    rim=base.strand('Rounded lower lip rim',lower_points,.007,lip_coat,'head')
    morph_curve(rim,'Lower lip follows jaw',[hinge+rotation@(p-hinge) for p in lower_points],'max(0, min(1, control-1))',1)
    FACE_PARTS.extend([upper.name,rim.name])

    tongue=base.material('Natural pink tongue',(.60,.18,.23))
    obj=base.ellipsoid('Tongue inside equine jaw',(-1.66,0,2.55),(.13,.115,.013),tongue)
    bpy.context.view_layer.objects.active=obj
    bpy.ops.object.transform_apply(location=True,rotation=False,scale=False)
    base.bind(obj,'head')
    morph_mesh(obj,'Tongue follows jaw',[hinge+rotation@(v.co-hinge) for v in obj.data.vertices],'max(0, min(1, control-1))',1)
    FACE_PARTS.extend([lower.name,obj.name])


def make_nostril(sign):
    n=Vector((-.60,sign*.80,.08)).normalized()
    h=Vector((.80,sign*.60,0)).normalized()
    center=hit(Vector((-1.75,sign*.20,2.715)),n)
    cutter('Nostril recess',center-n*.018,n,h,.047,.031,.040)
    mat=base.material('Velvet nostril '+str(sign),(.24,.13,.12))
    verts=[center-n*.022];faces=[];count=48
    for j in range(1,9):
        r=j/8
        for i in range(count):
            a=i*2*PI/count
            p=center+h*(.048*r*math.cos(a))+UP*(.032*r*math.sin(a))
            verts.append(hit(p,n)-n*(.022*(1-r*r)+.001))
    faces.extend((0,i+1,(i+1)%count+1) for i in range(count))
    for j in range(7):
        for i in range(count):
            k=1+j*count+i;next_i=1+j*count+(i+1)%count
            faces.append((k,k+count,next_i+count,next_i))
    mesh_object('Recessed side nostril '+str(sign),verts,faces,mat,'head')


def leaf_ear(sign,coat,pink):
    side='L' if sign<0 else 'R'
    root=Vector((-.73,sign*.31,3.25))
    axis=Vector((.07,sign*.24,.64))
    normal=Vector((-.9,sign*.38,-.03)).normalized()
    across=axis.normalized().cross(normal).normalized()
    for inside in (False,True):
        verts,faces=[],[]
        for j in range(25):
            t=j/24
            q=(.14+.73*t) if inside else t
            width=(.109 if inside else .157)*math.sin(PI*t)**.72+.001
            thick=(.025 if inside else .067)*math.sin(PI*t)**.8+.001
            for i in range(32):
                a=i*2*PI/32
                verts.append(root+axis*q+across*(width*math.cos(a))+normal*(thick*math.sin(a)+(.047 if inside else 0)))
        for j in range(24):
            for i in range(32):
                k=j*32+i
                faces.append((k,j*32+(i+1)%32,(j+1)*32+(i+1)%32,k+32))
        obj=mesh_object(('Inset ear velvet ' if inside else 'Soft pointed ear ')+side,verts,faces,pink if inside else coat,'ear.'+side)
        rotation=Matrix.Rotation(-.09,3,'Y')
        morph_mesh(obj,'Happy forward ear perk',[root+rotation@(v-root) for v in verts],'max(0, min(1, control-1))',1)


def sculpted_hair(name,controls,radii,depth,width,mat,bone):
    controls=[Vector(p) for p in controls]
    def sample(segment,t):
        a=controls[max(0,segment-1)];b=controls[segment]
        c=controls[segment+1];d=controls[min(len(controls)-1,segment+2)]
        return .5*((2*b)+(-a+c)*t+(2*a-5*b+4*c-d)*t*t+(-a+3*b-3*c+d)*t*t*t)
    path=[];scales=[]
    for j in range(len(controls)-1):
        for k in range(16):
            t=k/16
            path.append(sample(j,t))
            scales.append(radii[j]*(1-base.ease(t))+radii[j+1]*base.ease(t))
    path.append(controls[-1]);scales.append(radii[-1])
    verts=[];faces=[];count=64
    across=Vector((0,1,0))
    for j,(center,radius) in enumerate(zip(path,scales)):
        tangent=(path[min(j+1,len(path)-1)]-path[max(0,j-1)]).normalized()
        side=tangent.cross(across).normalized()
        for i in range(count):
            a=i*2*PI/count
            ripple=1+.027*math.cos(10*a+.8*j/len(path))
            verts.append(center+across*(width*radius*math.cos(a)*ripple)+side*(depth*radius*math.sin(a)*ripple))
    for j in range(len(path)-1):
        for i in range(count):
            k=j*count+i
            faces.append((k,j*count+(i+1)%count,(j+1)*count+(i+1)%count,k+count))
    faces += [tuple(range(count-1,-1,-1)),tuple(range((len(path)-1)*count,len(path)*count))]
    if bone=='tail':
        verts=[v+Vector((HIND_SHIFT,0,0)) for v in verts]
    return mesh_object(name,verts,faces,mat,bone)


def make_face(coat,pink,hair,gold,purple,ink,white):
    for sign in (-1,1):
        make_eye(sign,coat,white,ink)
        leaf_ear(sign,coat,pink)
    make_mouth(coat,pink)
    for sign in (-1,1):make_nostril(sign)
    # Horn and mane begin clear of the forehead, with a continuous taper.
    bpy.ops.mesh.primitive_cone_add(vertices=64,radius1=.115,radius2=.006,depth=.59,location=(-1.05,0,3.64))
    horn=bpy.context.object
    horn.rotation_euler.y=-.18
    bevel=horn.modifiers.new('Soft horn edges','BEVEL');bevel.width=.013;bevel.segments=3
    base.finish(horn,'Golden spiral horn',gold,'head')
    spiral=[]
    for i in range(150):
        t=i/149;r=.113*(1-t)+.005
        spiral.append((-1.00-.105*t+r*math.cos(t*7*PI),r*math.sin(t*7*PI),3.35+.57*t))
    base.strand('Horn spiral',spiral,.009,gold,'head')
    hair.node_tree.nodes.get('Principled BSDF').inputs['Base Color'].default_value=(*BLUE,1)
    hair.diffuse_color=(*BLUE,1)
    hair.node_tree.nodes.get('Principled BSDF').inputs['Roughness'].default_value=.34
    sculpted_hair('Swept neck mane', [(-.59,0,3.28),(-.30,0,3.15),(-.28,0,2.93),(-.39,0,2.76),(-.18,0,2.55),(-.16,0,2.34),(-.30,0,2.22)], [.42,.92,1,.91,.86,.70,.06], .156,.245,hair,'neck')
    sculpted_hair('Full curled tail',[(.72,0,1.68),(1.10,0,1.94),(1.48,0,2.01),(1.66,0,1.78),(1.47,0,1.48),(1.43,0,1.24),(1.62,0,1.16),(1.77,0,1.34),(1.63,0,1.45)], [.53,.93,1.13,1.15,1.04,.92,.70,.44,.02], .205,.255,hair,'tail')
    for side,y in [('L',-.26),('R',.26)]:
        for kind,x in [('fore',-.77),('hind',.68+HIND_SHIFT)]:
            verts=[]
            for z,rx,ry in [(0,.174,.151),(.035,.187,.159),(.19,.171,.149),(.275,.115,.113)]:
                for i in range(48):
                    a=i*2*PI/48
                    verts.append((x-.027+rx*math.cos(a),y+ry*math.sin(a),z))
            faces=[tuple(range(47,-1,-1)),tuple(range(144,192))]
            for j in range(3):
                for i in range(48):
                    k=j*48+i
                    faces.append((k,j*48+(i+1)%48,(j+1)*48+(i+1)%48,k+48))
            hoof=mesh_object('Lavender hoof '+kind+side,verts,faces,purple,kind+'.'+side+'.foot')
            bevel=hoof.modifiers.new('Soft hoof edge','BEVEL');bevel.width=.018;bevel.segments=3
            hoof.data.use_auto_smooth=True
            hoof.modifiers.new('Hoof weighted normals','WEIGHTED_NORMAL')
    bind_skin()


def equipment(gold,pink,white,purple):
    base_original_equipment(gold,pink,white,purple)
    for item in ('star','flower'):
        for obj in base.EQUIPMENT[item]:
            bpy.data.objects.remove(obj,do_unlink=True)
        base.EQUIPMENT[item]=[]
    def crown_point(angle):
        p=Vector((-.87+.272*math.cos(angle),.306*math.sin(angle),3.4))
        return hit(p,UP)+UP*.012
    points=[crown_point(i*2*PI/96) for i in range(97)]
    base.strand('Fitted gold crown rim',points,.020,gold,'head','star')
    mint=bpy.data.materials['Mint leaves']
    base.strand('Fitted flower crown vine',points,.020,mint,'head','flower')
    # A continuous low tiara joins every star to the rim.
    vertices=[];faces=[];count=140
    for radial in (-.009,.009):
        for upper in (False,True):
            for i in range(count):
                t=i*2*PI/count
                normal=Vector((math.cos(t),math.sin(t),0))
                rise=.027+.123*max(0,math.cos(t*7))**6 if upper else 0
                vertices.append(crown_point(t)+normal*radial+UP*rise)
    for i in range(count):
        nxt=(i+1)%count
        for a,b in ((0,1),(1,3),(3,2),(2,0)):
            faces.append((a*count+i,a*count+nxt,b*count+nxt,b*count+i))
    obj=mesh_object('Continuous star crown',vertices,faces,gold,'head')
    base.EQUIPMENT['star'].append(obj)
    bevel=obj.modifiers.new('Rounded crown edges','BEVEL');bevel.width=.004;bevel.segments=2
    for i in range(7):
        t=i*2*PI/7
        center=crown_point(t)+UP*.15
        tangent=Vector((-math.sin(t),math.cos(t),0));normal=Vector((math.cos(t),math.sin(t),0))
        vertices=[]
        for depth in (-.011,.011):
            for j in range(10):
                a=j*PI/5+PI/2;r=.083 if j%2==0 else .039
                vertices.append(center+tangent*(r*math.cos(a))+UP*(r*math.sin(a))+normal*depth)
        faces=[tuple(range(9,-1,-1)),tuple(range(10,20))]+[(j,(j+1)%10,(j+1)%10+10,j+10) for j in range(10)]
        obj=mesh_object('Joined crown star '+str(i),vertices,faces,gold,'head')
        base.EQUIPMENT['star'].append(obj)
        bevel=obj.modifiers.new('Soft star edge','BEVEL');bevel.width=.005;bevel.segments=2
    petal=bpy.data.materials['Blossom petals']
    for i in range(9):
        center=crown_point(i*2*PI/9)+UP*.027
        for j in range(5):
            a=j*2*PI/5
            base.ellipsoid('Fitted flower petal',center+Vector((.046*math.cos(a),.046*math.sin(a),0)),(.046,.039,.023),white if i%2 else petal,'head','flower')
        base.ellipsoid('Fitted flower heart',center+UP*.019,(.025,.025,.021),gold,'head','flower')
    for obj in base.EQUIPMENT['bow']:
        world=obj.matrix_world.copy();world.translation.z+=.225;world.translation.x+=.02
        obj.matrix_world=world
    rewards.add_equipment(base, mesh_object, crown_point, gold, pink, white)


def studio(scene):
    scene.render.film_transparent=True
    scene.render.resolution_x=scene.render.resolution_y=base.SPEC["size"]
    scene.eevee.taa_render_samples=16
    scene.eevee.gtao_distance=.16
    scene.eevee.gtao_factor=.85
    scene.view_settings.view_transform='AgX'
    scene.view_settings.look='AgX - Medium High Contrast'
    scene.world.use_nodes=True
    scene.world.node_tree.nodes.get('Background').inputs[0].default_value=(.78,.74,.69,1)
    scene.world.node_tree.nodes.get('Background').inputs[1].default_value=.55
    for obj in bpy.data.objects:
        if obj.type=='LIGHT':
            obj.data.energy*=1.2
    camera=scene.camera
    camera.location=(-7.8,-6.2,4.05)
    camera.rotation_euler=(Vector((-.03,0,1.96))-camera.location).to_track_quat('-Z','Y').to_euler()
    camera.data.ortho_scale=5.15
    scene['review_only']=False
    scene['production_revision']=5
    scene['review_revision']=5
    scene['revision_5_changes']='User horse references: rounded deeper muzzle, upper/lower lips, hinged opening jaw, restored attached lashes; preserved equine eyes and body'
    scene['review_targets']=json.dumps({'muzzle_forward':.18,'eye_scale':.90,'eye_normal':[-.60,.80,0],'happy_ear_perk_radians':.09,'jaw_open_radians':.25,'body_preserved_from':4})
    scene['reference']='art/foal/references/approved-c-playful-spark.png'
    scene['review_face_parts']=json.dumps(FACE_PARTS)
    scene['review_controls']='expression.scale.x: 1=open, .035=closed; scale.y: 1=relaxed, 2=happy jaw, eyelids and ears'
    # Pack the actual reference into the authoring file for viewport comparison.
    reference=bpy.data.images.load(str(HERE/'references/approved-c-playful-spark.png'),check_existing=True)
    reference.pack()
    for path in sorted((HERE/'references').glob('*.png')):
        image=bpy.data.images.load(str(path),check_existing=True)
        image.use_fake_user=True
        image.pack()
    scene['visual_reference_sources']=(HERE/'references/revision-five-sources.json').read_text()
    bpy.ops.object.empty_add(type='IMAGE',location=(0,3,2))
    ref=bpy.context.object;ref.name='Approved C · authoring reference';ref.data=reference
    ref.empty_display_size=5
    ref.hide_render=True
    ref.hide_set(True)
    for screen in bpy.data.screens:
        for area in screen.areas:
            if area.type=='VIEW_3D':
                area.spaces.active.region_3d.view_perspective='CAMERA'
                area.spaces.active.shading.type='MATERIAL'


base_original_equipment=base.make_equipment
base.body_mesh=body_mesh
base.make_face=make_face
base.make_equipment=equipment
base.sculpt_proportions=lambda:None

if __name__=='__main__':
    parser=argparse.ArgumentParser()
    parser.add_argument('--preview')
    args=parser.parse_args(sys.argv[sys.argv.index('--')+1:] if '--' in sys.argv else [])
    scene=base.build()
    rewards.add_masks(scene, base.EQUIPMENT)
    studio(scene)
    base.pose('idle',0)
    hair=bpy.data.materials['Pink hair · recolorable']
    hair.diffuse_color=(*PINK,1)
    hair.node_tree.nodes.get('Principled BSDF').inputs['Base Color'].default_value=(*PINK,1)
    bpy.context.view_layer.update()
    bpy.ops.object.select_all(action='DESELECT')
    SKIN.select_set(True)
    bpy.context.view_layer.objects.active=SKIN
    bpy.ops.wm.save_as_mainfile(filepath=str(MODEL))
    if args.preview:
        scene.render.filepath=str(Path(args.preview).resolve())
        bpy.ops.render.render(write_still=True)
    print('PRODUCTION_BUILD_COMPLETE')
