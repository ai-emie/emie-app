"""Build/start/stop the active repositories; keep the existing private data."""
import argparse
from pathlib import Path
import runpy

ROOT=r'C:\Users\Patze\Emie-LocalDev\b3-20261002T132620Z-4c04767e'
android=runpy.run_path(str(Path(__file__).with_name('android_local.py')))
support=android['support']

if __name__=='__main__':
    parser=argparse.ArgumentParser(); parser.add_argument('mode',choices=('build','start','stop','backend','flutter'))
    args=parser.parse_args(); root,cfg,private=support['target'](ROOT); support['packages']()
    if args.mode=='build': android['build'](root)
    elif args.mode=='start':
        android['current_apk'](root)  # Fail before starting services for stale APKs.
        support['start'](root,cfg,private)
        android['start'](root)
    elif args.mode=='backend': support['start'](root,cfg,private)
    elif args.mode=='flutter': android['flutter'](root)
    else:
        try: android['stop'](root)
        finally: support['stop'](root,cfg)
