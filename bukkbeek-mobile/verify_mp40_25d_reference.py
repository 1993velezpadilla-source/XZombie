#!/usr/bin/env python3
"""Strict data/source guard. NO claims that AI concept sheets are 1:1 footage."""
import json
from pathlib import Path
import sys

def verify(path: Path):
    m = json.loads(path.read_text())
    assert m["schema_version"] == 1 and m["weapon_id"] == "mp40_25d"
    assert m["stage"].startswith("REFERENCE_AND_TIMELINE")
    clips = m["clips"]
    assert len(clips) >= 10
    expected_empty = ["reach_mag","mag_out","bolt_lock_with_old_mag_held",
                      "fresh_mag_upside_down_from_pouch","mag_in","bolt_release","return"]
    expected_tac = ["reach_mag","mag_out","fresh_mag","mag_in","return"]
    assert [x["id"] for x in clips["reload_empty"]["phases"]] == expected_empty
    assert [x["id"] for x in clips["reload_tactical"]["phases"]] == expected_tac
    assert [x["id"] for x in clips["reload_empty"]["events"]] == [
        "mag_out","bolt_pull","mag_in","bolt_release"]
    assert [x["id"] for x in clips["reload_tactical"]["events"]] == [
        "mag_out","mag_in"]
    count = 0
    for name, clip in clips.items():
        phases=clip["phases"]
        assert phases and 0 < clip["duration_sec"] < 10
        prior = 0
        for phase in phases:
            assert phase["frames"] >= 1
            assert prior < phase["end"] <= 1
            prior = phase["end"]
            count += phase["frames"]
        assert abs(prior - 1) < 1e-8
        times = [v["at"] for v in clip["events"]]
        assert times == sorted(times)
        assert all(0 <= x <= 1 for x in times)
    e = clips["reload_empty"]
    events = {x["id"]: x["at"] for x in e["events"]}
    assert events["mag_out"] < events["bolt_pull"] < events["mag_in"] < events["bolt_release"]
    assert e["duration_sec"] > clips["reload_tactical"]["duration_sec"]
    refs = m["references"]
    assert any("ea_dice.artstation.com/blog" in r["url"] for r in refs)
    assert any("youtu.be" in r["url"] for r in refs)
    print(f"MP40_25D_REFERENCE_CONTRACT_GREEN clips={len(clips)} planned_unique_frames={count} physical_order=verified art_complete=false")

if __name__=="__main__":
    verify(Path(sys.argv[1]))
