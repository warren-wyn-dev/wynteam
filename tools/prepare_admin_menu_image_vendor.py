#!/usr/bin/env python3
"""Prepare the pinned image decoder without npm hooks or tracked binary assets."""

import base64
import hashlib
import io
import os
from pathlib import Path
import tarfile
import tempfile
import time
import urllib.error
import urllib.request


VERSION = "0.0.44"
URL = f"https://registry.npmjs.org/@imagemagick/magick-wasm/-/magick-wasm-{VERSION}.tgz"
INTEGRITY = "J6oieSjlJzamANwtrNAlO+DKnRm49ILtSIWDhtkGn35f/5zS99AXta2gPsZuG9m2JvQbsu3h3CHe14ViXrFD/Q=="
MAX_DOWNLOAD_BYTES = 16 * 1024 * 1024
TARGET = Path(__file__).resolve().parents[1] / "supabase/functions/admin-merchant-menu-image/_vendor"
# Exact members only: never extract an archive path or its symlinks to disk.
FILES = {
    "index.js": ("package/dist/index.js", 409450, "cf1db24f7e63f560118ef434fd581dc9ef66ad099dc417184765cd6076fb4a1b"),
    "index.d.ts": ("package/dist/index.d.ts", 116259, "ca8656c589c38f99d102c3169d6843415b72b28ed820389c187f2641bc749514"),
    "magick.wasm": ("package/dist/x86/magick.wasm", 15447097, "b7d6710436b150dc5bd1ca04d80b6b7614c54854d7470f888f7e69a2a41b00e4"),
    "LICENSE": ("package/LICENSE", 11358, "cfc7749b96f63bd31c3c42b5c471bf756814053e847c10f3eb003417bc523d30"),
    "NOTICE": ("package/NOTICE", 221910, "bc14d5191f0cd22ef077cb91daca24ec57a221746bc21941fc48b18f5bd8f072"),
}


def valid_file(path: Path, size: int, checksum: str) -> bool:
    if path.is_symlink():
        raise RuntimeError("Refusing a symlink in the generated decoder directory")
    return path.is_file() and path.stat().st_size == size and hashlib.sha256(path.read_bytes()).hexdigest() == checksum


def download() -> bytes:
    for attempt in range(3):
        try:
            request = urllib.request.Request(URL, headers={"User-Agent": "WYNOS-admin-menu-image-build/1"})
            with urllib.request.urlopen(request, timeout=20) as response:
                declared = response.headers.get("Content-Length")
                if declared and int(declared) > MAX_DOWNLOAD_BYTES:
                    raise RuntimeError("Decoder archive exceeds the download limit")
                result = bytearray()
                deadline = time.monotonic() + 45
                while True:
                    if time.monotonic() > deadline:
                        raise TimeoutError("Decoder download exceeded its deadline")
                    chunk = response.read(min(65536, MAX_DOWNLOAD_BYTES + 1 - len(result)))
                    if not chunk:
                        break
                    result.extend(chunk)
                    if len(result) > MAX_DOWNLOAD_BYTES:
                        raise RuntimeError("Decoder archive exceeds the download limit")
                return bytes(result)
        except (TimeoutError, urllib.error.URLError):
            if attempt == 2:
                raise
            time.sleep(0.5 * (attempt + 1))
    raise RuntimeError("Decoder download failed")


def main() -> None:
    if TARGET.is_symlink():
        raise RuntimeError("Refusing a symlink for the generated decoder directory")
    if all(valid_file(TARGET / name, size, checksum) for name, (_, size, checksum) in FILES.items()):
        print(f"Verified cached magick-wasm {VERSION} decoder assets")
        return
    archive = download()
    if hashlib.sha512(archive).digest() != base64.b64decode(INTEGRITY):
        raise RuntimeError("Decoder archive integrity verification failed")
    TARGET.mkdir(parents=True, exist_ok=True)
    with tarfile.open(fileobj=io.BytesIO(archive), mode="r:gz") as package:
        for name, (member_name, size, checksum) in FILES.items():
            member = package.getmember(member_name)
            if not member.isfile() or member.size != size:
                raise RuntimeError("Unexpected decoder archive member")
            source = package.extractfile(member)
            if source is None:
                raise RuntimeError("Missing decoder archive member")
            with source:
                data = source.read(size + 1)
            if len(data) != size or hashlib.sha256(data).hexdigest() != checksum:
                raise RuntimeError("Decoder member integrity verification failed")
            valid_file(TARGET / name, size, checksum)
            with tempfile.NamedTemporaryFile(dir=TARGET, delete=False) as output:
                temporary = Path(output.name)
                output.write(data)
            try:
                os.replace(temporary, TARGET / name)
            finally:
                temporary.unlink(missing_ok=True)
    print(f"Prepared magick-wasm {VERSION}: one x86 WASM plus JavaScript, types and licenses")


if __name__ == "__main__":
    main()
