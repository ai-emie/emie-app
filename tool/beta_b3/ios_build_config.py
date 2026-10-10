"""Prepare an explicit iOS plist; never invent provider or domain configuration.

Local: --local-port 8010 --output /owned/build/Info.plist
Release: --release-config confirmed.json --output /owned/build/Info.plist
Pass INFOPLIST_FILE to xcodebuild. Local additionally requires Debug and
SWIFT_ACTIVE_COMPILATION_CONDITIONS="DEBUG EMIE_LOCAL" and EMIE_LOCAL=true Dart define.
"""
import argparse
import json
import ipaddress
from pathlib import Path
import plistlib
import re
from urllib.parse import urlsplit


def private_device_host(host):
    try:
        address = ipaddress.IPv4Address(host)
    except (ValueError, TypeError):
        raise ValueError('Canonical RFC1918 IPv4 required') from None
    if str(address) != host or not any(address in ipaddress.IPv4Network(net) for net in
                                       ('10.0.0.0/8', '172.16.0.0/12', '192.168.0.0/16')):
        raise ValueError('Canonical RFC1918 IPv4 required')
    return host


def prepare(base, *, local_port=None, local_device=False, local_host=None, release=None):
    if (local_device or local_host is not None) and (
            local_port is None or not local_device or local_host is None or release is not None):
        raise ValueError('Device host requires explicit Local Debug activation')
    if not local_device and any(key in base for key in ('EMIELocalDevice', 'EMIELocalHost')):
        raise ValueError('Device plist cannot be reused as simulator/release configuration')
    info = dict(base)
    if local_port is not None:
        if release is not None or not 8010 <= local_port <= 8019:
            raise ValueError('Explicit Local Debug port 8010..8019 required')
        info['EMIELocalPort'] = local_port
        ats = dict(info.get('NSAppTransportSecurity', {}))
        if ats.get('NSAllowsArbitraryLoads'): raise ValueError('Broad ATS override is forbidden')
        ats['NSAllowsLocalNetworking'] = True
        if local_device:
            # This physical-device build needs only the exact IPv4 exception.
            ats.pop('NSAllowsLocalNetworking', None)
            host = private_device_host(local_host)
            info['EMIELocalDevice'] = True
            info['EMIELocalHost'] = host
            info['NSLocalNetworkUsageDescription'] = 'Emie Local Debug verbindet sich nur mit dem ausdrücklich gewählten Mac-Testbackend.'
            domains = dict(ats.get('NSExceptionDomains', {}))
            domains[host] = {'NSExceptionAllowsInsecureHTTPLoads': True, 'NSIncludesSubdomains': False}
            ats['NSExceptionDomains'] = domains
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
    parser.add_argument('--local-device', action='store_true')
    parser.add_argument('--local-host')
    parser.add_argument('--output', type=Path, required=True)
    args=parser.parse_args()
    source=Path(__file__).resolve().parents[2]/'ios/Runner/Info.plist'
    info=prepare(plistlib.loads(source.read_bytes()), local_port=args.local_port, local_device=args.local_device, local_host=args.local_host,
                 release=json.loads(args.release_config.read_text()) if args.release_config else None)
    args.output.parent.mkdir(parents=True, exist_ok=True)
    args.output.write_bytes(plistlib.dumps(info))

if __name__ == '__main__': main()
