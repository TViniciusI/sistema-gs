import base64
import re
import struct
import zlib
from pathlib import Path

p = Path(__file__).resolve().parent.parent / "lib" / "data" / "inpm_table_data.dart"
text = p.read_text(encoding="utf-8")
m = re.search(r"base64Decode\('([^']+)'\)", text)
assert m, "base64 not found"
b64 = m.group(1)
raw = zlib.decompress(base64.b64decode(b64))
print("bytes", len(raw), "floats", len(raw) // 4)
vals = struct.unpack("<" + "f" * (len(raw) // 4), raw)
print("first", vals[0], "last", vals[-1])
