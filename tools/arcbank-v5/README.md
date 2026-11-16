# ArcBank v5 — Reverse-Engineered Format + Converter

Eutechnyx ArcBank version 5, as used by Hot Wheels: Beat That! (PC, 2007).
Technyx's `arc_extract` only supports v3; v5 files crash it with
`std::bad_alloc`. This folder contains a Python parser + glTF converter
that works on all 30 Beat That cars.

## What was actually different in v5

Almost nothing in the container format — the header, entry table, index
buffers, vertex buffers, meshes, and models are **structurally identical
to v3**. The crash comes from the **Material** entries: v5 materials use a
different parameter layout, so the v3 parser reads a float `1.0`
(`0x3F800000`) as a param count (~1 billion) and tries to allocate it.

## Format

```
Header (60 bytes) + zero padding to 0x80
  u32 id = "ARCC"
  u32 numEntriesAndVersion: high byte = version (5), low 24 bits = entry count
  26x u16 counts: numTextures, numModels, numAttachments, numAttachedModels,
    numSkeletons, numCameras, unk1, numRigNodes, numMaterials, numMeshes,
    unk2, numReferencedTextures, unk22[4], numIndexBuffers, numVertexBuffers,
    unk20[2], numSkinnedModels, numDeformedMeshes, numAnimations, unk3,
    numAnimatedNodes, unk4, numLightNodes

Entry table at 0x80, 16 bytes per entry:
  u32 index, u32 offset, i32 nameOffset, u8 type, u8 size[3] (big-endian 24-bit)
  Entry offsets are RELATIVE to the end of the entry table (0x80 + 16*count).
  Types: 0x01 Texture, 0x02 Material, 0x09 Mesh, 0x0f IndexBuffer,
         0x10 VertexBuffer, 0x1d Model, 0xfd EntryNames, 0xff Group

IndexBuffer: u32 numIndices, then numIndices x u16 (winding: swap first two
  of each triangle for glTF)
VertexBuffer: u32 numVertices, u32 stride, u32 flags, then vertex data.
  Attribute order: Position (3f), Normal (3f), Color (4B RGBA8),
  Uv0 (2f), Uv1 (2f), Uv2 (2f), BoneWeight (20B) — by flag bit:
  bit0 Position, bit1 Color, bit2 Normal, bit3 Uv0, bit4 Uv1, bit5 Uv2,
  bit6 BoneWeight. (Order in file: Position, Normal, Color, Uv0, Uv1, Uv2.)
Mesh: MeshHdr (52B: numCameras, materialBaseIndex, indexBaseIndex,
  vertexBaseIndex, unk0, deformedMeshIndex, unk1, unk2[5], numPrimitives)
  + primitives. PrimitiveHdr (28B: materialIndex, indexBufferIndex,
  vertexBufferIndex, vertexBegin, numUsedVertices, offset0, count0)
  + u32 numMods + per mod: u32 type (0 = cluster: 4x u32
  indexStart/indexCount/vertexStart/vertexCount; 1 = skin: u32 count + u32s)
Model: NodeBase (176B: unk0[2], tm0, tm1, bbox, unk1, parentBone,
  numChildren, startChildIndex) + i32 meshIndex + 4x BBOX = 276 bytes.
  Matrices are column-major. Game coords: X=width, Y=length, Z=up.
  glTF conversion: (x,y,z) -> (x,z,-y); matrices M' = R*M*R^-1.

Texture: u32 width, height, numMips, hash, type; then mip data.
  type 26 = RGBA4, type "DXT1" (0x31545844) = BC1, type "DXT3" (0x33545844) = BC3.
  Mip sizes follow the standard DXT block math.

Material (v5, partially decoded): 24-byte header (same as v3), then a list
  of (u32 id, u32 size, data) shader params (ids 1,2,6,14,15,16,17,18 seen;
  sizes 4/8/12/16; values are floats — specular/gloss/colors), then texture
  bindings as (u32 packed=0x10000|texIndex, u32, u32, u32) groups.
  Full material->texture mapping is NOT fully decoded; the converter maps
  diffuse textures by name heuristic instead (see arc_to_gltf.py).
  Entry 0x42 (24 bytes, one per car file) is an unidentified v5-only type.
```

## Tools

- `arcbank.py` — v5 parser (header, entries, buffers, meshes, models, textures)
- `arc_to_gltf.py` — converter to glTF 2.0 (.glb) with embedded PNG textures
- `dxt.py` — DXT1/DXT3/RGBA4 decoder

## Usage

```
python3 arc_to_gltf.py <car>_LOD0_GRA.ARC <car>.glb
```

Converted models: `~/workspace/hot-wheels-beat-that/models/` (30 .glb files,
2.5–4.4 MB each). All 30 import cleanly into Godot 4.3 headless
(0 errors, 30 .scn files). Bone Shaker verified in detail: 3 meshes,
5 nodes (Body + 4 wheels), 8 body surfaces + 2 per wheel, ~79k triangles,
bbox 2.7 wide × 2.0 tall × 5.8 long, textures decode correctly
(skull/crossbones body atlas verified visually).

## Known limitations

- Material→texture mapping is name-heuristic, not decoded from the file.
  Body materials get the `*BodyDA.png` texture, tyre materials get a
  `pwheel*.png` texture, chrome gets metallic PBR. Lights materials get no
  texture. This may be wrong for some cars — check visually in Godot.
- UVs are passed through unflipped; if textures appear upside down in
  Godot, flip V in the converter.
- The 0x42 entry type (24 bytes) is ignored.
- Vertex COLOR_0 is included as-is (RGBA8); some cars' colors may look
  odd if the 4th byte isn't alpha.
