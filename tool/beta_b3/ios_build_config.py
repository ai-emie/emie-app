"""Prepare an explicit iOS plist; never invent provider or domain configuration.

Local: --local-port 8010 --output /owned/build/Info.plist
Release: --release-config confirmed.json --output /owned/build/Info.plist
Pass INFOPLIST_FILE to xcodebuild. Local additionally requires Debug and
SWIFT_ACTIVE_COMPILATION_CONDITIONS="DEBUG EMIE_LOCAL" and EMIE_LOCAL=true Dart define.
"""
import argparse
import json
from pathlib import Path
import plistlib
import re
from urllib.parse import urlsplit


def prepare(base, *, local_port=None, release=None):
    info = dict(base)
    if local_port is not None:
        if release is not None or not 8010 <= local_port <= 8019:
            raise ValueError('Explicit Local Debug port 8010..8019 required')
        info['EMIELocalPort'] = local_port
        ats = dict(info.get('NSAppTransportSecurity', {}))
        if ats.get('NSAllowsArbitraryLoads'): raise ValueError('Broad ATS override is forbidden')
        ats['NSAllowsLocalNetworking'] = True
        info['NSAppTransportSecurity'] = ats
        info['CFBundleURLTypes'] = list(info.get('CFBundleURLTypes', [])) + [{'CFBundleURLSchemes': ['emie-local-recovery']}]
        info['EMIERecoveryOrigin'] = ''
    elif release is not None:
        if release.get('bundle_id') != 'ai.emiso.emie':
            raise ValueError('Confirmed iOS bundle association required')
        client, server = release['ios_client_id'], release['server_client_id']
        pattern = r'[A-Za-z0-9_-]+\.apps\.googleusercontent\.com'
        if not re.fullmatch(pattern, client) or not re.fullmatch(pattern, server):
            raise ValueError('Real iOS and backend OAuth client IDs required')
        scheme = '.'.join(reversed(client.split('.')))
        if release['reversed_client_id'] != scheme:
            raise ValueError('iOS callback scheme mismatch')
        origin = urlsplit(release['recovery_origin'])
        if origin.scheme != 'https' or not origin.hostname or origin.username or origin.password or origin.query or origin.fragment or origin.path not in ('', '/'):
            raise ValueError('Confirmed exact HTTPS recovery origin required')
        info.update(GIDClientID=client, GIDServerClientID=server,
                    EMIERecoveryOrigin=release['recovery_origin'])
        info['CFBundleURLTypes'] = list(info.get('CFBundleURLTypes', [])) + [{'CFBundleURLSchemes': [scheme]}]
    else:
        raise ValueError('Select explicit local or confirmed release configuration')
    return info


def main():
    parser=argparse.ArgumentParser()
    group=parser.add_mutually_exclusive_group(required=True)
    group.add_argument('--local-port', type=int)
    group.add_argument('--release-config', type=Path)
    parser.add_argument('--output', type=Path, required=True)
    args=parser.parse_args()
    source=Path(__file__).resolve().parents[2]/'ios/Runner/Info.plist'
    info=prepare(plistlib.loads(source.read_bytes()), local_port=args.local_port,
                 release=json.loads(args.release_config.read_text()) if args.release_config else None)
    args.output.parent.mkdir(parents=True, exist_ok=True)
    args.output.write_bytes(plistlib.dumps(info))

if __name__ == '__main__': main()
