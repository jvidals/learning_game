"""Read-only checks of the saved review scene, including visible face contact."""
import json
import math
from pathlib import Path
import bpy
from mathutils import Vector
from mathutils.bvhtree import BVHTree
from bpy_extras.object_utils import world_to_camera_view

scene=bpy.context.scene
assert scene.get('production_revision') == 5 and not scene.get('review_only')
assert scene.render.film_transparent
assert (scene.render.resolution_x,scene.render.resolution_y)==(1024,1024)
assert 'Review studio floor' not in scene.objects
rig=bpy.data.objects['Gentle foal · animation rig']
skin=bpy.data.objects['Continuous coat · weighted skin']
spec=json.loads(scene['animation_spec'])
assert abs(rig.data.bones['hind.L0'].head_local.x-rig.data.bones['fore.L0'].head_local.x-1.342)<1e-5,'Accepted body length changed'
for side in ('L','R'):
    joints=[rig.data.bones[f'hind.{side}{i}'].head_local for i in range(3)]+[rig.data.bones[f'hind.{side}2'].tail_local]
    assert max(p.x for p in joints)-min(p.x for p in joints)<.21,'Hind chain remains too folded'
    assert joints[1].x<joints[0].x and joints[2].x>joints[3].x,'Keep stifle/hock anatomy'
for side in ('L','R'):
    wing=rig.data.bones['wing.'+side]
    assert wing.parent.name=='body','Wings must attach at the shoulders'
    assert wing.tail_local.x-wing.head_local.x>1,'Wings must flow backward'
assert not any('Forelock' in obj.name for obj in scene.objects)
expected={'idle','happy','simple','hop','bowing','twirl'}
assert expected <= set(bpy.data.actions.keys())
assert not any(o.name.startswith(('Upper lashes','Eye white','Rosy cheek','Skin fitted eyebrow')) for o in scene.objects)
assert any(image.packed_file for image in bpy.data.images if 'approved-c-playful-spark' in image.name)

# Auxiliary smoothing groups are not skin weights.
weighted_vertices=0
for obj in scene.objects:
    if obj.type!='MESH' or not any(m.type=='ARMATURE' for m in obj.modifiers):continue
    deform={g.index for g in obj.vertex_groups if g.name in rig.data.bones and rig.data.bones[g.name].use_deform}
    for vertex in obj.data.vertices:
        weights=[g.weight for g in vertex.groups if g.group in deform]
        assert weights and all(math.isfinite(w) and w>=0 for w in weights)
        assert abs(sum(weights)-1)<1e-4,(obj.name,vertex.index,sum(weights))
        weighted_vertices+=1

bindings={}
for obj in scene.objects:
    if obj.parent_type=='BONE':
        assert obj.parent==rig
        b=rig.pose.bones[obj.parent_bone]
        bindings[obj.name]=(rig.matrix_world@b.matrix).inverted()@obj.matrix_world
for side in ('L','R'):
    for prefix in ('Inset eye globe ','Iris in globe ','Sculpted eyelids ','Attached upper lash '):
        obj=bpy.data.objects[prefix+side]
        assert obj.parent_bone=='head'
    globe=bpy.data.objects['Inset eye globe '+side]
    assert globe.animation_data is None, 'Round eyeballs must not have squash drivers'
    lids=bpy.data.objects['Sculpted eyelids '+side]
    assert 'Blink · skin closes over eye' in lids.data.shape_keys.key_blocks
    key=lids.data.shape_keys.key_blocks[1]
    # Symmetric points of the aperture meet, while the outer ring stays fixed.
    for i in range(1,48):
        assert (key.data[i].co-key.data[96-i].co).length<1e-5
    for i in range(96*10,96*11):
        assert (key.data[i].co-lids.data.shape_keys.key_blocks[0].data[i].co).length<1e-5

rig.animation_data_create()
foot_baseline={}
max_attachment_error=0
max_hoof_shift=0
max_ik_error=0
framing_margin=1
bow_checked=False
for clip in sorted(expected):
    action=bpy.data.actions[clip]
    count=round(spec['clips'][clip]['durationMs']*60/1000)
    assert abs(action.frame_range[1]-count)<=2
    rig.animation_data.action=action
    frames=sorted({0,count//4,count//2,3*count//4,count})
    if clip=='idle': frames=range(count+1)
    endpoints=[];seam_samples={};body_origin=None;max_body_shift=0
    for frame in frames:
        scene.frame_set(frame)
        bpy.context.view_layer.update()
        for name,bind in bindings.items():
            obj=bpy.data.objects[name]
            b=rig.pose.bones[obj.parent_bone]
            actual=(rig.matrix_world@b.matrix).inverted()@obj.matrix_world
            error=max(abs(actual[r][c]-bind[r][c]) for r in range(4) for c in range(4))
            max_attachment_error=max(max_attachment_error,error)
            assert error<2e-5,(name,clip,frame,error)
        for side in ('L','R'):
            for kind,end in [('fore',1),('hind',2)]:
                endpoint=rig.pose.bones[f'{kind}.{side}{end}'].tail
                target=rig.pose.bones[f'{kind}.{side}.foot'].head
                ik_error=(endpoint-target).length
                max_ik_error=max(max_ik_error,ik_error)
                assert ik_error<.045,(clip,frame,kind,side,'IK disconnect',ik_error)
        for obj in scene.objects if frame in {0,count//4,count//2,3*count//4,count} else []:
            if obj.type not in ('MESH','CURVE') or obj.name=='Review studio floor':continue
            evaluated=obj.evaluated_get(bpy.context.evaluated_depsgraph_get())
            for corner in evaluated.bound_box:
                projected=world_to_camera_view(scene,scene.camera,evaluated.matrix_world@Vector(corner))
                margin=min(projected.x,projected.y,1-projected.x,1-projected.y)
                framing_margin=min(framing_margin,margin)
                assert margin>.05,(clip,frame,obj.name,'Camera clipping',tuple(projected))
        if clip=='bowing' and frame==count//2:
            knee=rig.pose.bones['fore.L1'].head;foot=rig.pose.bones['fore.L1'].tail
            assert foot.x>knee.x+.15 and foot.z>.5,('Bow fold',list(knee),list(foot))
            for name in ('fore.R','hind.L','hind.R'):
                assert abs(rig.pose.bones[name+'.foot'].head.z-.16)<.001
            bow_checked=True
        if clip=='idle':
            for side in ('L','R'):
                for kind in ('fore','hind'):
                    name='Lavender hoof '+kind+side
                    pos=bpy.data.objects[name].matrix_world.translation.copy()
                    foot_baseline.setdefault(name,pos)
                    error=(pos-foot_baseline[name]).length
                    max_hoof_shift=max(max_hoof_shift,error)
                    assert error<1e-6
            assert rig.pose.bones['head'].rotation_euler.to_quaternion().angle<math.radians(3.01)
            body=rig.pose.bones['body'].head.copy()
            if body_origin is None:body_origin=body
            max_body_shift=max(max_body_shift,(body-body_origin).length)
            assert max_body_shift<.031
            assert abs(rig.pose.bones['expression'].scale.y-1)<1e-7
            for name in ('root','body','neck','head','wing.L','wing.R'):
                assert (rig.pose.bones[name].scale-Vector((1,1,1))).length<1e-7
            for name in ('wing.L','wing.R'):
                assert rig.pose.bones[name].rotation_euler.to_quaternion().angle<1e-7
            if frame in (0,1,count-1,count):seam_samples[frame]=[(rig.matrix_world@b.matrix).copy() for b in rig.pose.bones]
        if frame in (0,count):endpoints.append([(rig.matrix_world@b.matrix).copy() for b in rig.pose.bones])
    assert max(abs(a[r][c]-b[r][c]) for a,b in zip(*endpoints) for r in range(4) for c in range(4))<1e-4,(clip,'pose seam')
    if clip=='idle':
        assert max_body_shift>.01
        seam_error=max(abs((b[r][c]-a[r][c])-(d[r][c]-c_[r][c])) for a,b,c_,d in zip(seam_samples[0],seam_samples[1],seam_samples[count-1],seam_samples[count]) for r in range(4) for c in range(4))
        assert seam_error<1e-6
        idle_body_shift=max_body_shift


rig.animation_data_clear()
for bone in rig.pose.bones:
    bone.location=(0,0,0);bone.rotation_euler=(0,0,0);bone.scale=(1,1,1)
rig.rotation_euler=(0,0,0)
bpy.context.view_layer.update()
deps=bpy.context.evaluated_depsgraph_get()
evaluated=skin.evaluated_get(deps)
mesh=evaluated.to_mesh()
bvh=BVHTree.FromPolygons([evaluated.matrix_world@v.co for v in mesh.vertices],[list(p.vertices) for p in mesh.polygons])
jaw=bpy.data.objects['Rounded hinged lower lip']
assert jaw.parent_bone=='head'
keys=jaw.data.shape_keys.key_blocks
closed=keys['Basis'];opened=keys['Happy jaw opening']
front=min(range(len(closed.data)),key=lambda i:closed.data[i].co.x)
jaw_drop=closed.data[front].co.z-opened.data[front].co.z
assert .10<jaw_drop<.20,('Jaw opening depth',jaw_drop)
assert len([o for o in scene.objects if o.name.startswith('Eyelid lash ')])==6
assert all(any(im.packed_file for im in bpy.data.images if name in im.name) for name in ('horse-front','horse-three-quarter'))
evaluated.to_mesh_clear()
# Check actual eye/lid clearance, including intermediate blink poses.
eye_surfaces={}
for side,sign in [('L',-1),('R',1)]:
    eye=bpy.data.objects['Inset eye globe '+side].evaluated_get(deps)
    eye_mesh=eye.to_mesh()
    eye_surfaces[side]=(BVHTree.FromPolygons([eye.matrix_world@v.co for v in eye_mesh.vertices],[list(p.vertices) for p in eye_mesh.polygons]),Vector((-.60,sign*.80,0)).normalized())
    eye.to_mesh_clear()
minimum_lid_clearance=1
# Verify controls drive shape keys after reopening the saved .blend.
for smile,blink in ((0,0),(1,0),(1,.15),(1,.25),(1,.4),(1,.5),(1,.65),(1,.75),(1,.9),(1,1),(0,.5)):
    rig.pose.bones['expression'].scale=(1-.965*blink,1+smile,1)
    bpy.context.view_layer.update()
    for side in ('L','R'):
        keys=bpy.data.objects['Sculpted eyelids '+side].data.shape_keys
        assert abs(keys.key_blocks[1].value-blink)<1e-5
        surface,normal=eye_surfaces[side]
        lids=bpy.data.objects['Sculpted eyelids '+side].evaluated_get(deps)
        lid_mesh=lids.to_mesh()
        for v in lid_mesh.vertices:
            point=lids.matrix_world@v.co
            hit=surface.ray_cast(point+normal,-normal,2)
            if hit[0] is not None:
                clearance=hit[3]-1
                minimum_lid_clearance=min(minimum_lid_clearance,clearance)
                assert clearance>.003,(side,smile,blink,'Lid intersects eye',clearance)
        lids.to_mesh_clear()
    for side in ('L','R'):
        for prefix in ('Soft pointed ear ','Inset ear velvet '):
            ear=bpy.data.objects[prefix+side]
            key=ear.data.shape_keys.key_blocks['Happy forward ear perk']
            assert abs(key.value-smile)<1e-5
            base=ear.data.shape_keys.key_blocks['Basis']
            movement=max((a.co-b.co).length for a,b in zip(key.data,base.data))
            assert .04<movement<.09,('Unexpected ear perk',movement)
    assert abs(jaw.data.shape_keys.key_blocks['Happy jaw opening'].value-smile)<1e-5
    assert abs(bpy.data.objects['Tongue inside equine jaw'].data.shape_keys.key_blocks['Tongue follows jaw'].value-smile)<1e-5
    for side in ('L','R'):
        for i in range(3):
            lash=bpy.data.objects[f'Eyelid lash {side}{i}']
            assert lash.parent_bone=='head'
            assert abs(lash.data.shape_keys.key_blocks['Blink · rooted in lid'].value-blink)<1e-5
result={'weighted_vertices':weighted_vertices,'idle_body_shift':idle_body_shift,'idle_velocity_seam':seam_error,'status':'passed','actions':len(expected),'bone_attachments':len(bindings),'max_attachment_matrix_error':max_attachment_error,'max_idle_hoof_shift':max_hoof_shift,'jaw_front_drop':jaw_drop,'restored_eyelashes':6,'horse_photos_packed':True,'happy_ear_perk_checked':True,'eyeballs_keep_shape':True,'lids_close_without_scaling_globes':True,'packed_original_reference':True,'animated_equine_jaw':True,'max_ik_endpoint_error':max_ik_error,'all_action_bounds_margin':framing_margin,'bow_anatomy_checked':bow_checked,'partial_blinks_checked':[.15,.25,.4,.5,.65,.75,.9],'minimum_lid_globe_clearance':minimum_lid_clearance}
root=Path(__file__).resolve().parents[2]/'artifacts/playful-spark/release-0120'
root.mkdir(parents=True,exist_ok=True)
(root/'validation.json').write_text(json.dumps(result,indent=2)+'\n')
print('PRODUCTION_VALIDATION',json.dumps(result),flush=True)
