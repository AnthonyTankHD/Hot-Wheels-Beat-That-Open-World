"""Minimal DXT1/DXT3/RGBA4 texture decoder (for Eutechnyx ArcBank textures)."""
import struct


def _rgb565(c):
    r = ((c >> 11) & 31) * 255 // 31
    g = ((c >> 5) & 63) * 255 // 63
    b = (c & 31) * 255 // 31
    return r, g, b


def _decode_dxt1_block(block, out, ox, oy, w, h):
    c0, c1 = struct.unpack('<2H', block[:4])
    idx = struct.unpack('<I', block[4:8])[0]
    col0 = _rgb565(c0)
    col1 = _rgb565(c1)
    if c0 > c1:
        cols = [col0, col1,
                tuple((2 * a + b) // 3 for a, b in zip(col0, col1)),
                tuple((a + 2 * b) // 3 for a, b in zip(col0, col1))]
        alphas = [255, 255, 255, 255]
    else:
        cols = [col0, col1, tuple((a + b) // 2 for a, b in zip(col0, col1)),
                (0, 0, 0)]
        alphas = [255, 255, 255, 0]
    for py in range(4):
        for px in range(4):
            i = (idx >> (2 * (4 * py + px))) & 3
            x, y = ox + px, oy + py
            if x < w and y < h:
                r, g, b = cols[i]
                out[(y * w + x) * 4:(y * w + x) * 4 + 4] = bytes(
                    [r, g, b, alphas[i]])


def _decode_dxt3_block(block, out, ox, oy, w, h):
    alpha_block = block[:8]
    for py in range(4):
        for px in range(4):
            a = (alpha_block[(4 * py + px) // 2] >> (4 * ((4 * py + px) % 2))) & 0xF
            x, y = ox + px, oy + py
            if x < w and y < h:
                out[(y * w + x) * 4 + 3] = a * 17
    _decode_dxt1_block(block[8:16], out, ox, oy, w, h)
    # dxt1 block wrote alpha=255; fix by re-applying the 4-bit alphas
    for py in range(4):
        for px in range(4):
            a = (alpha_block[(4 * py + px) // 2] >> (4 * ((4 * py + px) % 2))) & 0xF
            x, y = ox + px, oy + py
            if x < w and y < h:
                out[(y * w + x) * 4 + 3] = a * 17


def decode(data, width, height, fmt):
    """fmt: 'DXT1', 'DXT3', or 'RGBA4'. Returns RGBA bytearray (top-down)."""
    out = bytearray(width * height * 4)
    if fmt == 'RGBA4':
        for i in range(width * height):
            v = struct.unpack('<H', data[i * 2:i * 2 + 2])[0]
            r = ((v >> 12) & 0xF) * 17
            g = ((v >> 8) & 0xF) * 17
            b = ((v >> 4) & 0xF) * 17
            a = (v & 0xF) * 17
            out[i * 4:i * 4 + 4] = bytes([r, g, b, a])
        return out
    bpp = 8 if fmt == 'DXT1' else 16
    bw = (width + 3) // 4
    bh = (height + 3) // 4
    for by in range(bh):
        for bx in range(bw):
            off = (by * bw + bx) * bpp
            block = data[off:off + bpp]
            if fmt == 'DXT1':
                _decode_dxt1_block(block, out, bx * 4, by * 4, width, height)
            else:
                _decode_dxt3_block(block, out, bx * 4, by * 4, width, height)
    return out


def mip_sizes(width, height, fmt, num_mips):
    """Byte sizes of each mip level."""
    sizes = []
    w, h = width, height
    for _ in range(num_mips):
        if fmt == 'DXT1':
            sizes.append(((w + 3) // 4) * ((h + 3) // 4) * 8)
        elif fmt == 'DXT3':
            sizes.append(((w + 3) // 4) * ((h + 3) // 4) * 16)
        elif fmt == 'RGBA4':
            sizes.append(w * h * 2)
        w = max(1, w // 2)
        h = max(1, h // 2)
    return sizes
