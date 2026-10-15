#!/usr/bin/env python3
"""Strict authentic Aether MP40 soundwave gate. No foley substitutes allowed."""
import hashlib
import json
from pathlib import Path
import sys
import wave

root = Path(sys.argv[1])  # committed bukkbeek-mobile/audio/aether/mp40/
wanted = {
    "mag_out.wav": "gr_mp40_mag_out",
    "mag_in.wav": "gr_mp40_mag_in",
    "charge.wav": "gr_mp40_charge",
}
proof = root / "SOURCE_AETHER_PROVENANCE.json"
if not proof.is_file():
    sys.exit("MP40_REAL_AUDIO_RED: missing original Aether .ubulk provenance")
source = json.loads(proof.read_text(encoding="utf-8-sig"))
if isinstance(source, dict):
    source = [source]
observed = {}
for row in source:
    if row.get("output") in wanted:
        observed[row["output"]] = row

hashes = set()
for output, stem in wanted.items():
    path = root / output
    if not path.is_file() or output not in observed:
        sys.exit("MP40_REAL_AUDIO_RED: missing authentic source WAV "+output)
    row = observed[output]
    if row.get("stem") != stem:
        sys.exit("MP40_REAL_AUDIO_RED: wrong Source Aether stem for "+output)
    digest = hashlib.sha256(path.read_bytes()).hexdigest()
    if digest.casefold() != str(row.get("wav_sha256","")).casefold():
        sys.exit("MP40_REAL_AUDIO_RED: provenance sha256 mismatch "+output)
    if not row.get("raw_sha256") or len(row["raw_sha256"]) != 64:
        sys.exit("MP40_REAL_AUDIO_RED: no authenticated original .ubulk hash")
    with wave.open(str(path), "rb") as audio:
        if audio.getnframes() < 100 or not (8000 <= audio.getframerate() <= 96000):
            sys.exit("MP40_REAL_AUDIO_RED: invalid decoded source wave "+output)
        print("MP40_AUTHENTIC_AETHER_AUDIO_GREEN", stem, output,
              audio.getnframes(), audio.getframerate(),digest)
    if digest in hashes:
        sys.exit("MP40_REAL_AUDIO_RED: two distinct originals use identical audio")
    hashes.add(digest)

print("MP40_ORIGINAL_RELOAD_SOUNDS_GREEN: gr_mp40_mag_out, gr_mp40_mag_in, gr_mp40_charge")
