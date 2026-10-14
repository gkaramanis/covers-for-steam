"""List which cached apps declare portrait library art in appinfo.vdf (v29)."""
import os
import struct
import sys

path, cache = sys.argv[1], sys.argv[2]
data = open(path, "rb").read()
magic, universe, table_offset = struct.unpack_from("<IIq", data, 0)
assert magic == 0x07564429, hex(magic)

count = struct.unpack_from("<I", data, table_offset)[0]
strings, pos = [], table_offset + 4
for _ in range(count):
    end = data.index(b"\0", pos)
    strings.append(data[pos:end].decode("utf-8", "replace"))
    pos = end + 1


def read_kv(pos):
    """Binary KeyValues with string-table keys; returns (dict, pos)."""
    out = {}
    while True:
        kind = data[pos]; pos += 1
        if kind == 8:
            return out, pos
        key = strings[struct.unpack_from("<I", data, pos)[0]]; pos += 4
        if kind == 0:
            out[key], pos = read_kv(pos)
        elif kind == 1:
            end = data.index(b"\0", pos)
            out[key] = data[pos:end].decode("utf-8", "replace"); pos = end + 1
        elif kind in (2, 4, 6):
            out[key] = struct.unpack_from("<I", data, pos)[0]; pos += 4
        elif kind == 3:
            out[key] = struct.unpack_from("<f", data, pos)[0]; pos += 4
        elif kind in (7, 10):
            out[key] = struct.unpack_from("<Q", data, pos)[0]; pos += 8
        else:
            raise ValueError(f"type {kind} at {pos}")


apps, pos = {}, 16
while pos < table_offset:
    appid, size = struct.unpack_from("<II", data, pos)
    if appid == 0:
        break
    kv, _ = read_kv(pos + 8 + 4 + 4 + 8 + 20 + 4 + 20)
    apps[appid] = kv.get("appinfo", kv)
    pos += 8 + size

cached = {int(d) for d in os.listdir(cache) if d.isdigit()}
for appid in sorted(cached):
    common = apps.get(appid, {}).get("common", {})
    assets = common.get("library_assets_full", {})
    portrait = "library_capsule" in assets
    has_cover = any(
        f == "library_600x900.jpg"
        for _, _, files in os.walk(os.path.join(cache, str(appid)))
        for f in files
    )
    if has_cover:
        print(appid, "real" if portrait else "fallback", common.get("type", "?"), common.get("name", "?"), sep="\t")
