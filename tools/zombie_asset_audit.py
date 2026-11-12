"""Read-only GLB/asset inventory. Run with Python; no third-party dependencies.

python tools/zombie_asset_audit.py --source-root <original-checkout> --out docs/captures/before/assets.json
Source root is explicit because user_supplied is ignored by Git and absent from worktrees.
"""
import argparse
import collections
import hashlib
import json
from pathlib import Path
import struct


def inspect_glb(path):
    with path.open('rb') as stream:
        magic, version, size = struct.unpack('<4sII', stream.read(12))
        if magic != b'glTF' or version != 2 or size != path.stat().st_size:
            raise ValueError('Invalid GLB header (possibly an LFS pointer)')
        length, kind = struct.unpack('<II', stream.read(8))
        if kind != 0x4E4F534A:
            raise ValueError('Missing JSON chunk')
        data = json.loads(stream.read(length))
    nodes = data.get('nodes', [])
    return {
        'meshes': [m.get('name', '') for m in data.get('meshes', [])],
        'skins': [{'name': s.get('name', ''), 'joints': [nodes[i].get('name', '') for i in s['joints']]} for s in data.get('skins', [])],
        'animations': [{'name': a.get('name', ''), 'channels': len(a.get('channels', []))} for a in data.get('animations', [])],
        'materials': [m.get('name', '') for m in data.get('materials', [])],
    }


def main():
    parser = argparse.ArgumentParser(__doc__)
    parser.add_argument('--source-root', type=Path, required=True)
    parser.add_argument('--out', type=Path, required=True)
    args = parser.parse_args()
    root = args.source_root.resolve()
    result = {'source_root': str(root), 'files': [], 'glbs': {}, 'errors': [], 'extension_counts': {}}
    for folder in ['assets/third_party', 'assets/user_supplied', 'assets/ours/characters/zombie_base']:
        counts = collections.Counter()
        for path in sorted((root / folder).rglob('*')):
            if not path.is_file() or path.suffix == '.import':
                continue
            rel = path.relative_to(root).as_posix()
            counts[path.suffix.lower()] += 1
            result['files'].append({'path': rel, 'bytes': path.stat().st_size})
            if path.suffix.lower() == '.glb':
                try:
                    result['glbs'][rel] = inspect_glb(path)
                except Exception as exc:
                    result['errors'].append({'path': rel, 'error': str(exc)})
        result['extension_counts'][folder] = dict(counts)
    args.out.parent.mkdir(parents=True, exist_ok=True)
    args.out.write_text(json.dumps(result, indent=2), encoding='utf-8')
    print(f"Inventoried {len(result['files'])} files and {len(result['glbs'])} GLBs; {len(result['errors'])} errors")
    return bool(result['errors'])


if __name__ == '__main__':
    raise SystemExit(main())
