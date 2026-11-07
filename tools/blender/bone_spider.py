"""Builds the Bone Spider, an original monster for Crypt Crawl, entirely from code.

Run with Blender's Python (the `bpy` module from PyPI works without a screen):
    python tools/blender/bone_spider.py
It writes art/original/Bone_Spider.glb with four animations: Idle, Running_A,
Attack and Death. Everything here is made by this script, so the model is ours.

Blender is Z-up with the model facing -Y; the glTF exporter turns that into the
Y-up, facing +Z layout the game expects (the same as the KayKit models).
"""
import math
import os
import sys

import bpy
from mathutils import Vector

OUT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "..", "art", "original", "Bone_Spider.glb")
FPS = 30

# ---------------------------------------------------------------- scene and materials

bpy.ops.wm.read_factory_settings(use_empty=True)
scene = bpy.context.scene
scene.render.fps = FPS


def material(name, color, emission=None, rough=0.8):
    m = bpy.data.materials.new(name)
    m.use_nodes = True
    bsdf = m.node_tree.nodes["Principled BSDF"]
    bsdf.inputs["Base Color"].default_value = (*color, 1.0)
    bsdf.inputs["Roughness"].default_value = rough
    if emission:
        bsdf.inputs["Emission Color"].default_value = (*emission, 1.0)
        bsdf.inputs["Emission Strength"].default_value = 4.0
    return m


BONE = material("Bone", (0.86, 0.82, 0.70))
DARK = material("Dark", (0.16, 0.12, 0.16), rough=0.9)
GLOW = material("Glow", (0.3, 1.0, 0.55), emission=(0.3, 1.0, 0.55))


def empty(name, loc=(0, 0, 0), parent=None, rot=(0, 0, 0)):
    o = bpy.data.objects.new(name, None)
    bpy.context.collection.objects.link(o)
    o.parent = parent
    o.location = loc
    o.rotation_euler = rot
    return o


def finish(o, name, mat, parent, loc=(0, 0, 0)):
    o.name = name
    o.data.materials.append(mat)
    for p in o.data.polygons:
        p.use_smooth = False
    o.parent = parent
    o.location = loc
    return o


def sphere(name, radius, scale, mat, parent, loc=(0, 0, 0), segs=10, rings=7):
    bpy.ops.mesh.primitive_uv_sphere_add(segments=segs, ring_count=rings, radius=radius)
    o = bpy.context.active_object
    o.scale = scale
    bpy.ops.object.transform_apply(scale=True)
    return finish(o, name, mat, parent, loc)


def cone(name, r1, r2, depth, mat, parent, loc, rot):
    bpy.ops.mesh.primitive_cone_add(vertices=6, radius1=r1, radius2=r2, depth=depth)
    o = bpy.context.active_object
    o.rotation_euler = rot
    bpy.ops.object.transform_apply(rotation=True)
    return finish(o, name, mat, parent, loc)


def segment(name, p0, p1, radius, mat, parent):
    """A six-sided bone running from p0 to p1 (in the parent's space), pivoting at p0."""
    p0, p1 = Vector(p0), Vector(p1)
    length = (p1 - p0).length
    bpy.ops.mesh.primitive_cylinder_add(vertices=6, radius=radius, depth=length)
    o = bpy.context.active_object
    for v in o.data.vertices:
        v.co.z += length / 2
        # Taper a little towards the tip, and bulge at the joint.
        if v.co.z > length * 0.9:
            v.co.x *= 0.6
            v.co.y *= 0.6
    o.rotation_mode = "QUATERNION"
    o.rotation_quaternion = (p1 - p0).to_track_quat("Z", "Y")
    o.rotation_mode = "XYZ"
    finish(o, name, mat, parent, p0)
    sphere(name + "_joint", radius * 1.35, (1, 1, 1), mat, parent, p0, segs=6, rings=4)
    return o


# ---------------------------------------------------------------- the body

root = empty("Bone_Spider")
body = empty("Body", (0, 0, 0.5), root)

sphere("Abdomen", 0.42, (1.0, 1.25, 0.8), BONE, body, (0, 0.42, 0.08))
for i, y in enumerate((0.22, 0.42, 0.62)):  # dark rib bands across the abdomen
    sphere("Rib%d" % i, 0.43, (1.03, 0.12, 0.83), DARK, body, (0, y, 0.08), segs=12, rings=6)
sphere("Thorax", 0.26, (1.0, 1.0, 0.8), BONE, body, (0, -0.02, 0.02))
head = empty("Head", (0, -0.3, 0.06), body)
sphere("Skull", 0.24, (1.0, 1.1, 0.85), BONE, head)
sphere("Jaw", 0.17, (1.0, 0.8, 0.5), DARK, head, (0, -0.1, -0.1))
for sx in (-1, 1):
    sphere("Eye%s" % ("L" if sx < 0 else "R"), 0.065, (1, 1, 1), GLOW, head, (sx * 0.1, -0.2, 0.06), segs=8, rings=5)
    sphere("EyeSmall%s" % ("L" if sx < 0 else "R"), 0.035, (1, 1, 1), GLOW, head, (sx * 0.17, -0.15, 0.13), segs=6, rings=4)
    cone("Fang%s" % ("L" if sx < 0 else "R"), 0.05, 0.0, 0.22, BONE, head, (sx * 0.08, -0.24, -0.18), (math.radians(160), 0, 0))
for i in range(3):  # spines along the back
    cone("Spine%d" % i, 0.06, 0.0, 0.25, BONE, body, (0, 0.25 + i * 0.2, 0.42 - i * 0.04), (math.radians(-20), 0, 0))

# ---------------------------------------------------------------- legs

# (front to back) hip position along the body and how far each leg fans out.
LEG_Y = (-0.12, 0.02, 0.16, 0.30)
LEG_FAN = (-38, -12, 12, 36)
legs = []  # (side, index, hip, lift, knee)
for side in (1, -1):
    for i in range(4):
        tag = ("R" if side > 0 else "L") + str(i + 1)
        yaw = math.radians(LEG_FAN[i]) if side > 0 else math.pi - math.radians(LEG_FAN[i])
        hip = empty("Hip" + tag, (side * 0.2, LEG_Y[i], 0.0), body, (0, 0, yaw))
        lift = empty("Lift" + tag, (0, 0, 0), hip)
        segment("Upper" + tag, (0, 0, 0), (0.42, 0, 0.3), 0.045, BONE, lift)
        knee = empty("Knee" + tag, (0.42, 0, 0.3), lift)
        segment("Lower" + tag, (0, 0, 0), (0.3, 0, -0.8), 0.038, BONE, knee)
        legs.append((side, i, hip, lift, knee, yaw))

# ---------------------------------------------------------------- animation helpers

anim_objects = [body, head] + [o for leg in legs for o in leg[2:5]]


def key(o, frame, rot=None, loc=None):
    if rot is not None:
        o.rotation_euler = rot
        o.keyframe_insert("rotation_euler", frame=frame)
    if loc is not None:
        o.location = loc
        o.keyframe_insert("location", frame=frame)


def rest_pose():
    body.location = (0, 0, 0.5)
    body.rotation_euler = (0, 0, 0)
    head.rotation_euler = (0, 0, 0)
    for side, i, hip, lift, knee, yaw in legs:
        hip.rotation_euler = (0, 0, yaw)
        lift.rotation_euler = (0, 0, 0)
        knee.rotation_euler = (0, 0, 0)


def bake(name, frames, pose_at, cyclic):
    """Key every animated object at each frame, then stash the keys as an NLA track."""
    for o in anim_objects:
        if o.animation_data:
            o.animation_data.action = None  # start a fresh action; keep earlier NLA tracks
    for f in frames:
        rest_pose()
        pose_at(f)
        for o in anim_objects:
            o.keyframe_insert("rotation_euler", frame=f)
            o.keyframe_insert("location", frame=f)
    for o in anim_objects:
        act = o.animation_data.action
        act.name = "%s_%s" % (name, o.name)
        track = o.animation_data.nla_tracks.new()
        track.name = name
        strip = track.strips.new(name, frames[0], act)
        strip.name = name
        o.animation_data.action = None
    rest_pose()


def gait_phase(side, i):
    # Alternating tetrapod gait: R1, L2, R3, L4 move together, then the others.
    return 0.0 if (i % 2 == 0) == (side > 0) else 0.5


# ---------------------------------------------------------------- the four animations

def idle(f):
    t = f / 60.0 * math.tau
    body.location = (0, 0, 0.5 + math.sin(t) * 0.025)
    head.rotation_euler = (math.sin(t * 2) * 0.05, 0, math.sin(t) * 0.08)
    for side, i, hip, lift, knee, yaw in legs:
        knee.rotation_euler = (0, math.sin(t + i) * 0.05, 0)


def run(f):
    t = f / 16.0
    body.location = (0, 0, 0.52 + abs(math.sin(t * math.tau * 2)) * 0.04)
    body.rotation_euler = (0, math.sin(t * math.tau) * 0.06, 0)
    for side, i, hip, lift, knee, yaw in legs:
        p = (t + gait_phase(side, i)) * math.tau
        swing = math.cos(p) * 0.38      # forward / back
        up = max(0.0, math.sin(p)) * 0.45  # lift the foot while it swings forward
        hip.rotation_euler = (0, 0, yaw - side * swing)
        lift.rotation_euler = (0, -up, 0)
        knee.rotation_euler = (0, up * 0.6, 0)


def attack(f):
    # Rear up (0-8), strike down (8-12), settle (12-20).
    if f <= 8:
        k = f / 8.0
    elif f <= 12:
        k = 1.0 - (f - 8) / 4.0 * 1.3
    else:
        k = -0.3 * (1.0 - (f - 12) / 8.0)
    body.rotation_euler = (k * 0.55, 0, 0)
    body.location = (0, 0, 0.5 + max(k, 0) * 0.15)
    head.rotation_euler = (-k * 0.3, 0, 0)
    for side, i, hip, lift, knee, yaw in legs:
        if i < 2:  # front legs lift and claw
            lift.rotation_euler = (0, -max(k, 0) * 1.1, 0)
            knee.rotation_euler = (0, max(k, 0) * 0.9 - min(k, 0) * 0.5, 0)


def death(f):
    k = min(1.0, f / 18.0)
    body.location = (0, 0, 0.5 - k * 0.38)
    body.rotation_euler = (0, k * 0.35, 0)
    head.rotation_euler = (k * 0.4, 0, 0)
    for side, i, hip, lift, knee, yaw in legs:
        lift.rotation_euler = (0, -k * 0.7, 0)
        knee.rotation_euler = (0, k * (1.6 + i * 0.1), 0)


bake("Idle", list(range(0, 61, 5)), idle, True)
bake("Running_A", list(range(0, 17, 2)), run, True)
bake("Attack", list(range(0, 21, 2)), attack, False)
bake("Death", list(range(0, 31, 3)), death, False)

# ---------------------------------------------------------------- export

os.makedirs(os.path.dirname(OUT), exist_ok=True)
bpy.ops.export_scene.gltf(
    filepath=OUT,
    export_format="GLB",
    export_animation_mode="NLA_TRACKS",
    export_yup=True,
    export_apply=False,
)
print("wrote", os.path.abspath(OUT))
