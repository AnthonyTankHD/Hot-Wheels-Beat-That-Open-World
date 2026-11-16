"""Convert an Eutechnyx ArcBank v5 (.ARC) car file to glTF 2.0 (.glb).

Usage: python3 arc_to_gltf.py input.ARC output.glb

Coordinate conversion: game is Z-up with Y = length (forward).
glTF is Y-up. Mapping: (x, y, z) -> (x, z, -y). Node matrices are
converted as M' = R * M * R^-1.
"""
import json
import os
import struct
import sys

import numpy as np

sys.path.insert(0, '/tmp')
from arcbank import ArcBank
from dxt import decode as dxt_decode, mip_sizes as dxt_mip_sizes


def _fmt_name(t):
    if t == 26:
        return 'RGBA4'
    if t == 827611204:
        return 'DXT1'
    if t == 861165636:
        return 'DXT3'
    return None


def _png_bytes(width, height, rgba):
    import zlib
    raw = b''.join(b'\x00' + bytes(rgba[y * width * 4:(y + 1) * width * 4])
                   for y in range(height))

    def chunk(typ, data):
        c = struct.pack('>I', len(data)) + typ + data
        return c + struct.pack('>I', zlib.crc32(typ + data) & 0xffffffff)

    ihdr = struct.pack('>IIBBBBB', width, height, 8, 6, 0, 0, 0)
    return (b'\x89PNG\r\n\x1a\n' + chunk(b'IHDR', ihdr) +
            chunk(b'IDAT', zlib.compress(raw)) + chunk(b'IEND', b''))


def pick_diffuse_texture(material_name, textures):
    """Best-effort diffuse texture for a material, by name.
    textures: list of dicts with 'name', 'width', 'height'.
    Returns index into textures, or None."""
    m = material_name.lower()
    cands = []
    if 'body' in m:
        cands = [t for t in textures if 'body' in t['name'].lower()]
    elif 'tyre' in m or 'tire' in m or 'wheel' in m:
        cands = [t for t in textures
                 if ('wheel' in t['name'].lower() or
                     'tyre' in t['name'].lower() or
                     'tire' in t['name'].lower())
                 and 'normal' not in t['name'].lower()
                 and not t['name'].lower().endswith('n2.png')]
    if not cands:
        return None
    # largest texture wins
    cands.sort(key=lambda t: t['width'] * t['height'], reverse=True)
    return textures.index(cands[0])

# Rotation R mapping game coords -> glTF coords: (x,y,z) -> (x,z,-y)
R = np.array([[1, 0, 0],
              [0, 0, 1],
              [0, -1, 0]], dtype=np.float64)
R4 = np.eye(4)
R4[:3, :3] = R
R4_INV = np.linalg.inv(R4)


def convert_matrix(tm0):
    """tm0: 16 floats, column-major 4x4. Returns glTF column-major list."""
    m = np.array(tm0, dtype=np.float64).reshape((4, 4), order='F')
    m2 = R4 @ m @ R4_INV
    return m2.reshape(16, order='F').tolist()


def convert_vec(v):
    x, y, z = v
    return (x, z, -y)


def convert_arc(path, out_path):
    arc = ArcBank(path)
    print(f"v{arc.version} file, {arc.num_entries} entries: "
          f"{arc.num_textures} tex, {arc.num_materials} mat, "
          f"{arc.num_meshes} mesh, {arc.num_index_buffers} IB, "
          f"{arc.num_vertex_buffers} VB, {arc.num_models} models")

    # ---- read buffers ----
    ib_entries = sorted(arc.entries_of_type(0x0f), key=lambda e: e.index)
    vb_entries = sorted(arc.entries_of_type(0x10), key=lambda e: e.index)
    index_buffers = [arc.read_index_buffer(e) for e in ib_entries]
    vertex_buffers = []
    for e in vb_entries:
        nv, stride, flags, attrs = arc.read_vertex_buffer(e)
        # convert positions + normals to glTF coords
        attrs['POSITION'] = [convert_vec(p) for p in attrs.get('POSITION', [])]
        attrs['NORMAL'] = [convert_vec(n) for n in attrs.get('NORMAL', [])]
        vertex_buffers.append({'num_vertices': nv, 'attrs': attrs})
        print(f"  VB{e.index}: {nv} verts stride={stride} flags=0x{flags:x} "
              f"attrs={sorted(attrs.keys())}")

    mesh_entries = sorted(arc.entries_of_type(0x09), key=lambda e: e.index)
    meshes = [arc.read_mesh(e) for e in mesh_entries]
    model_entries = sorted(arc.entries_of_type(0x1d), key=lambda e: e.index)
    models = [arc.read_model(e) for e in model_entries]
    material_entries = sorted(arc.entries_of_type(0x02), key=lambda e: e.index)
    material_names = [arc.name(e) or f"material_{e.index}"
                      for e in material_entries]

    # ---- build glTF ----
    bin_data = bytearray()
    buffer_views = []
    accessors = []

    def add_buffer_view(data_bytes, target=None):
        # 4-byte align
        while len(bin_data) % 4:
            bin_data.append(0)
        offset = len(bin_data)
        bin_data.extend(data_bytes)
        bv = {'buffer': 0, 'byteOffset': offset,
              'byteLength': len(data_bytes)}
        if target is not None:
            bv['target'] = target
        buffer_views.append(bv)
        return len(buffer_views) - 1

    def add_accessor(bv, component_type, count, type_, min_=None, max_=None,
                     normalized=False):
        acc = {'bufferView': bv, 'componentType': component_type,
               'count': count, 'type': type_}
        if min_ is not None:
            acc['min'] = min_
        if max_ is not None:
            acc['max'] = max_
        if normalized:
            acc['normalized'] = True
        accessors.append(acc)
        return len(accessors) - 1

    # vertex attributes: one accessor per (VB, attribute)
    vb_attr_accessors = []  # per VB: dict attr name -> accessor index
    for vb in vertex_buffers:
        accs = {}
        attrs = vb['attrs']
        if 'POSITION' in attrs:
            pos = attrs['POSITION']
            raw = b''.join(struct.pack('<3f', *p) for p in pos)
            bv = add_buffer_view(raw, 34962)
            arr = np.array(pos, dtype=np.float64)
            accs['POSITION'] = add_accessor(
                bv, 5126, len(pos), 'VEC3',
                arr.min(axis=0).tolist(), arr.max(axis=0).tolist())
        if 'NORMAL' in attrs:
            nrm = attrs['NORMAL']
            raw = b''.join(struct.pack('<3f', *n) for n in nrm)
            bv = add_buffer_view(raw, 34962)
            accs['NORMAL'] = add_accessor(bv, 5126, len(nrm), 'VEC3')
        if 'COLOR_0' in attrs:
            col = attrs['COLOR_0']
            raw = bytes(c for tup in col for c in tup)
            bv = add_buffer_view(raw, 34962)
            accs['COLOR_0'] = add_accessor(bv, 5121, len(col), 'VEC4',
                                           normalized=True)
        if 'TEXCOORD_0' in attrs:
            uv = attrs['TEXCOORD_0']
            raw = b''.join(struct.pack('<2f', *t) for t in uv)
            bv = add_buffer_view(raw, 34962)
            accs['TEXCOORD_0'] = add_accessor(bv, 5126, len(uv), 'VEC2')
        if 'TEXCOORD_1' in attrs:
            uv = attrs['TEXCOORD_1']
            raw = b''.join(struct.pack('<2f', *t) for t in uv)
            bv = add_buffer_view(raw, 34962)
            accs['TEXCOORD_1'] = add_accessor(bv, 5126, len(uv), 'VEC2')
        vb_attr_accessors.append(accs)

    # index buffers: one bufferView per IB (u16), accessors per cluster slice
    ib_buffer_views = []
    for ib in index_buffers:
        raw = struct.pack(f'<{len(ib)}H', *ib)
        ib_buffer_views.append(add_buffer_view(raw, 34963))

    def index_accessor(ib_idx, start, count):
        acc = {'bufferView': ib_buffer_views[ib_idx],
               'byteOffset': start * 2,
               'componentType': 5123, 'count': count, 'type': 'SCALAR'}
        accessors.append(acc)
        return len(accessors) - 1

    # ---- textures: decode DXT1/DXT3/RGBA4 to PNG, embed in glTF ----
    tex_entries = sorted(arc.entries_of_type(0x01), key=lambda e: e.index)
    textures = []
    for e in tex_entries:
        t = arc.read_texture_header(e)
        fmt = _fmt_name(t['type'])
        if fmt is None:
            print(f"  tex '{t['name']}': unknown format {t['type']}, skipped")
            continue
        sizes = dxt_mip_sizes(t['width'], t['height'], fmt, t['num_mips'])
        rgba = dxt_decode(arc.data[t['data_offset']:t['data_offset'] + sizes[0]],
                          t['width'], t['height'], fmt)
        textures.append({'name': t['name'], 'width': t['width'],
                         'height': t['height'],
                         'png': _png_bytes(t['width'], t['height'], rgba)})
        print(f"  tex '{t['name']}': {t['width']}x{t['height']} {fmt}")

    gltf_images = []
    gltf_textures = []
    for tex in textures:
        while len(bin_data) % 4:
            bin_data.append(0)
        offset = len(bin_data)
        bin_data.extend(tex['png'])
        bv = {'buffer': 0, 'byteOffset': offset,
              'byteLength': len(tex['png'])}
        buffer_views.append(bv)
        gltf_images.append({'name': tex['name'], 'mimeType': 'image/png',
                            'bufferView': len(buffer_views) - 1})
        gltf_textures.append({'source': len(gltf_images) - 1})

    # materials (PBR, named; diffuse texture by name heuristic)
    gltf_materials = []
    for name in material_names:
        mat = {
            'name': name,
            'doubleSided': True,
            'pbrMetallicRoughness': {
                'baseColorFactor': [1.0, 1.0, 1.0, 1.0],
                'metallicFactor': 0.0,
                'roughnessFactor': 0.9,
            },
        }
        if 'chrome' in name.lower():
            mat['pbrMetallicRoughness']['metallicFactor'] = 0.9
            mat['pbrMetallicRoughness']['roughnessFactor'] = 0.25
        tex_idx = pick_diffuse_texture(name, textures)
        if tex_idx is not None:
            mat['pbrMetallicRoughness']['baseColorTexture'] = {
                'index': tex_idx}
            print(f"  material '{name}' -> texture '{textures[tex_idx]['name']}'")
        gltf_materials.append(mat)
    if not gltf_materials:
        gltf_materials.append({
            'name': 'default',
            'pbrMetallicRoughness': {'baseColorFactor': [0.8, 0.8, 0.8, 1.0]},
        })

    # meshes
    gltf_meshes = []
    for mesh in meshes:
        prims = []
        for p in mesh['prims']:
            vb_idx = mesh['vertex_base'] + p['vertex_buffer']
            ib_idx = mesh['index_base'] + p['index_buffer']
            mat_idx = mesh['material_base'] + p['material_index']
            for mod in p['mods']:
                if mod['kind'] != 'cluster':
                    continue
                prim = {
                    'attributes': dict(vb_attr_accessors[vb_idx]),
                    'indices': index_accessor(
                        ib_idx, mod['index_start'], mod['index_count']),
                    'material': mat_idx if mat_idx < len(gltf_materials) else 0,
                    'mode': 4,
                }
                prims.append(prim)
        gltf_meshes.append({'name': mesh['name'] or f"mesh_{mesh['index']}",
                            'primitives': prims})
        print(f"  mesh '{mesh['name']}': {len(prims)} primitives")

    # nodes
    gltf_nodes = []
    for m in models:
        node = {'name': m['name'] or f"model_{m['index']}",
                'matrix': convert_matrix(m['tm0']),
                'mesh': m['mesh_index']}
        gltf_nodes.append(node)
    # children
    for i, m in enumerate(models):
        if m['parent_bone'] >= 0:
            parent = gltf_nodes[m['parent_bone']]
            parent.setdefault('children', []).append(i)
    root_nodes = [i for i, m in enumerate(models) if m['parent_bone'] < 0]

    gltf = {
        'asset': {'version': '2.0',
                  'generator': 'arcbank-v5-converter',
                  'copyright': 'Hot Wheels: Beat That! model, converted for fan project'},
        'scene': 0,
        'scenes': [{'nodes': root_nodes}],
        'nodes': gltf_nodes,
        'meshes': gltf_meshes,
        'materials': gltf_materials,
        'accessors': accessors,
        'bufferViews': buffer_views,
        'buffers': [{'byteLength': len(bin_data)}],
    }
    if gltf_images:
        gltf['images'] = gltf_images
    if gltf_textures:
        gltf['textures'] = gltf_textures

    # ---- write .glb ----
    json_bytes = json.dumps(gltf, separators=(',', ':')).encode('utf-8')
    while len(json_bytes) % 4:
        json_bytes += b' '
    while len(bin_data) % 4:
        bin_data.append(0)
    total = 12 + 8 + len(json_bytes) + 8 + len(bin_data)
    with open(out_path, 'wb') as f:
        f.write(struct.pack('<4sII', b'glTF', 2, total))
        f.write(struct.pack('<I4s', len(json_bytes), b'JSON'))
        f.write(json_bytes)
        f.write(struct.pack('<I4s', len(bin_data), b'BIN\x00'))
        f.write(bytes(bin_data))
    print(f"wrote {out_path}: {len(gltf_meshes)} meshes, "
          f"{len(gltf_nodes)} nodes, {len(accessors)} accessors, "
          f"{total} bytes")
    return gltf


if __name__ == '__main__':
    convert_arc(sys.argv[1], sys.argv[2])
