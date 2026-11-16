"""Parser for Eutechnyx ArcBank version 5 (.ARC) files, as used by
Hot Wheels: Beat That! (PC, 2007).

Format (reverse-engineered; structurally identical to Technyx's v3):
  Header (60 bytes, same struct as v3) + zero padding to 0x80
  Entry table at 0x80: 16-byte entries
    u32 index, u32 offset, i32 nameOffset, u8 type, u8 size[3] (big-endian 24-bit)
  Entry offsets are RELATIVE to the end of the entry table (0x80 + 16*numEntries).
  Entry types: 0x01 Texture, 0x02 Material, 0x09 Mesh, 0x0f IndexBuffer,
               0x10 VertexBuffer, 0x1d Model, 0xfd EntryNames, 0xff Group
  IndexBuffer: u32 numIndices, then numIndices x u16
  VertexBuffer: u32 numVertices, u32 stride, u32 flags, then vertex data.
    Attribute order (by flag bit): 0 Position (3f), 2 Normal (3f),
    1 Color (4B RGBA8), 3 Uv0 (2f), 4 Uv1 (2f), 5 Uv2 (2f), 6 BoneWeight (20B)
  Mesh: MeshHdr (52B) + primitives; PrimitiveHdr (28B) + u32 numMods +
        per mod: u32 type (0=cluster 4x u32, 1=skin u32 count + u32s)
  Model: NodeBase (176B) + i32 meshIndex + 4x BBOX (96B) = 276B
  Game coords: X=width, Y=length, Z=up. Matrices stored column-major.
"""
import struct


class Entry:
    __slots__ = ('index', 'offset', 'name_offset', 'type', 'size')

    def __init__(self, index, offset, name_offset, typ, size):
        self.index = index
        self.offset = offset
        self.name_offset = name_offset
        self.type = typ
        self.size = size

    def __repr__(self):
        return (f"Entry(idx={self.index} off=0x{self.offset:x} "
                f"nameOff={self.name_offset} type=0x{self.type:02x} size={self.size})")


class ArcBank:
    def __init__(self, path):
        self.data = open(path, 'rb').read()
        d = self.data
        if d[:4] != b'ARCC':
            raise ValueError('not an ARCC file')
        self.num_entries = struct.unpack('<I', d[4:8])[0] & 0xffffff
        self.version = struct.unpack('<I', d[4:8])[0] >> 24
        # header counts (u16s at offset 8)
        counts = struct.unpack('<26H', d[8:60])
        (self.num_textures, self.num_models, self.num_attachments,
         self.num_attached_models, self.num_skeletons, self.num_cameras,
         _unk1, self.num_rig_nodes, self.num_materials, self.num_meshes,
         _unk2, self.num_ref_textures, *_rest) = counts
        (self.num_index_buffers, self.num_vertex_buffers) = counts[16:18]
        self.origin = 0x80 + 16 * self.num_entries
        self.entries = []
        for i in range(self.num_entries):
            off = 0x80 + i * 16
            idx, eoff, nameoff = struct.unpack('<IIi', d[off:off + 12])
            typ = d[off + 12]
            size = int.from_bytes(d[off + 13:off + 16], 'big')
            self.entries.append(Entry(idx, eoff, nameoff, typ, size))
        # entry names blob (last entry, type 0xfd)
        self.names = b''
        for e in self.entries:
            if e.type == 0xfd:
                self.names = d[self.origin + e.offset:
                               self.origin + e.offset + e.size]
                break

    def abs(self, e):
        return self.origin + e.offset

    def name(self, e):
        if e.name_offset < 0 or not self.names:
            return None
        end = self.names.index(b'\x00', e.name_offset)
        return self.names[e.name_offset:end].decode('ascii', 'replace')

    def entries_of_type(self, typ):
        return [e for e in self.entries if e.type == typ]

    # ---- buffers ----
    def read_index_buffer(self, e):
        a = self.abs(e)
        n, = struct.unpack('<I', self.data[a:a + 4])
        idx = list(struct.unpack(f'<{n}H', self.data[a + 4:a + 4 + 2 * n]))
        # v3 flips winding: swap first two indices of each triangle
        for i in range(0, n - 2, 3):
            idx[i], idx[i + 1] = idx[i + 1], idx[i]
        return idx

    def read_vertex_buffer(self, e):
        """Returns (num_vertices, stride, flags, attrs dict of lists).
        attrs keys: POSITION, NORMAL, COLOR_0, TEXCOORD_0, TEXCOORD_1,
        TEXCOORD_2 (each a list of tuples)."""
        a = self.abs(e)
        nv, stride, flags = struct.unpack('<III', self.data[a:a + 12])
        base = a + 12
        # attribute layout in flag order: Position, Normal, Color, Uv0, Uv1, Uv2, BoneWeight
        layout = []
        off = 0
        if flags & 1:   # bit 0: Position 3f
            layout.append(('POSITION', off, '3f')); off += 12
        if flags & 4:   # bit 2: Normal 3f
            layout.append(('NORMAL', off, '3f')); off += 12
        if flags & 2:   # bit 1: Color 4B
            layout.append(('COLOR_0', off, '4B')); off += 4
        if flags & 8:   # bit 3: Uv0 2f
            layout.append(('TEXCOORD_0', off, '2f')); off += 8
        if flags & 16:  # bit 4: Uv1 2f
            layout.append(('TEXCOORD_1', off, '2f')); off += 8
        if flags & 32:  # bit 5: Uv2 2f
            layout.append(('TEXCOORD_2', off, '2f')); off += 8
        # bit 6: BoneWeight 20B (weights 4f + indices 4B) — not handled
        attrs = {name: [] for name, _, _ in layout}
        d = self.data
        for v in range(nv):
            vb = base + v * stride
            for name, o, fmt in layout:
                if fmt == '3f':
                    attrs[name].append(struct.unpack('<3f', d[vb + o:vb + o + 12]))
                elif fmt == '2f':
                    attrs[name].append(struct.unpack('<2f', d[vb + o:vb + o + 8]))
                elif fmt == '4B':
                    attrs[name].append(tuple(d[vb + o:vb + o + 4]))
        return nv, stride, flags, attrs

    # ---- meshes ----
    def read_mesh(self, e):
        """Returns dict with prims: each prim has materialIndex,
        indexBufferIndex, vertexBufferIndex, vertexBegin, numUsedVertices,
        and mods (list of cluster dicts)."""
        a = self.abs(e)
        p = a
        (num_cameras, mat_base, ib_base, vb_base, unk0, def_mesh,
         unk1) = struct.unpack('<7i', self.data[p:p + 28]); p += 28
        p += 20  # unk2[5]
        num_prims, = struct.unpack('<I', self.data[p:p + 4]); p += 4
        prims = []
        for _ in range(num_prims):
            (mat, ib, vb, v_begin, n_used, off0,
             cnt0) = struct.unpack('<7I', self.data[p:p + 28]); p += 28
            n_mods, = struct.unpack('<I', self.data[p:p + 4]); p += 4
            mods = []
            for _ in range(n_mods):
                mtype, = struct.unpack('<I', self.data[p:p + 4]); p += 4
                if mtype == 0:
                    istart, icount, vstart, vcount = struct.unpack(
                        '<4I', self.data[p:p + 16]); p += 16
                    mods.append({'kind': 'cluster', 'index_start': istart,
                                 'index_count': icount, 'vertex_start': vstart,
                                 'vertex_count': vcount})
                elif mtype == 1:
                    cnt, = struct.unpack('<I', self.data[p:p + 4]); p += 4
                    vals = struct.unpack(f'<{cnt}I', self.data[p:p + 4 * cnt])
                    p += 4 * cnt
                    mods.append({'kind': 'skin', 'values': vals})
                else:
                    raise ValueError(f'unknown primitive mod type {mtype}')
            prims.append({'material_index': mat, 'index_buffer': ib,
                          'vertex_buffer': vb, 'vertex_begin': v_begin,
                          'num_used_vertices': n_used, 'mods': mods})
        return {'name': self.name(e), 'index': e.index,
                'material_base': mat_base, 'index_base': ib_base,
                'vertex_base': vb_base, 'prims': prims}

    # ---- models (nodes) ----
    def read_model(self, e):
        a = self.abs(e)
        p = a
        p += 8  # unk0[2]
        tm0 = struct.unpack('<16f', self.data[p:p + 64]); p += 64
        tm1 = struct.unpack('<16f', self.data[p:p + 64]); p += 64
        bbox = struct.unpack('<6f', self.data[p:p + 24]); p += 24
        unk1, parent_bone, n_children, start_child = struct.unpack(
            '<4i', self.data[p:p + 16]); p += 16
        mesh_idx, = struct.unpack('<i', self.data[p:p + 4]); p += 4
        p += 96  # bbox1[4]
        return {'name': self.name(e), 'index': e.index, 'tm0': tm0,
                'tm1': tm1, 'bbox': bbox, 'parent_bone': parent_bone,
                'num_children': n_children, 'start_child': start_child,
                'mesh_index': mesh_idx}

    # ---- textures ----
    def read_texture_header(self, e):
        a = self.abs(e)
        w, h, num_mips, hsh, typ = struct.unpack('<5I', self.data[a:a + 20])
        return {'name': self.name(e), 'width': w, 'height': h,
                'num_mips': num_mips, 'hash': hsh, 'type': typ,
                'data_offset': a + 20, 'data_size': e.size - 20}
