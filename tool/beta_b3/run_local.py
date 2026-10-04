"""Three usual commands: setup, start, stop. Keeps the already provisioned data."""
import argparse
from pathlib import Path
import runpy

ROOT=r'C:\Users\Patze\Emie-LocalDev\b3-20261002T132620Z-4c04767e'
android=runpy.run_path(str(Path(__file__).with_name('android_local.py')))
support=android['support']

if __name__=='__main__':
    parser=argparse.ArgumentParser(); parser.add_argument('mode',choices=('setup','start','stop'))
    args=parser.parse_args(); root,cfg,private=support['target'](ROOT); support['packages']()
    if args.mode=='setup': android['build'](root)
    elif args.mode=='start':
        support['start'](root,cfg,private)
        android['start'](root)
    else:
        try: android['stop'](root)
        finally: support['stop'](root,cfg)
