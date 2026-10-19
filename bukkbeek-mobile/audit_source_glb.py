#!/usr/bin/env python3
"""Read REAL source glTF 2.0 GLB metadata and material index; no screenshot guessing."""
import json,struct,sys
from pathlib import Path
base=Path(sys.argv[1])
for id in ["colt","thompson","kar98k"]:
    p=base/id/"viewmodel.glb"
    data=p.read_bytes()
    assert data[:4]==b"glTF" and struct.unpack_from("<I",data,4)[0]==2,p
    sz,typ=struct.unpack_from("<II",data,12)
    assert typ==0x4E4F534A
    g=json.loads(data[20:20+sz].decode("utf8"))
    names=[]
    for mesh in g.get("meshes",[]):
        for i,prim in enumerate(mesh.get("primitives",[])):
            mat_ix=prim.get("material",-1)
            mn=g.get("materials",[])
            mat=mn[mat_ix].get("name","<unnamed>") if mat_ix>=0 and mat_ix<len(mn) else "<none>"
            acc_ix=prim["attributes"].get("POSITION")
            acc=g["accessors"][acc_ix] if acc_ix is not None else {}
            names.append(dict(mesh=mesh.get("name"),primitive=i,material=mat,indices=mat_ix,
                             count=acc.get("count"),posmin=acc.get("min"),posmax=acc.get("max"),
                             uv0="TEXCOORD_0" in prim.get("attributes",{}),
                             normal="NORMAL" in prim.get("attributes",{})))
    nodes=[dict(name=x.get("name"),translation=x.get("translation"),rotation=x.get("rotation"),scale=x.get("scale")) for x in g.get("nodes",[]) if any(k in x.get("name","").lower() for k in ["viewmodel","gun","skeleton","tag_","socket"])]
    print("XZIEL_GLTF_AUDIT "+json.dumps(dict(id=id,materials=[m.get("name") for m in g.get("materials",[])],surfaces=names,bones=nodes[:12]),separators=(",",":")))
