"""New narrow Windows launcher checks; not the existing POSIX PG suite."""
import hashlib
import json
import os
from pathlib import Path
import runpy
import socket
import sys

script=Path(__file__).with_name('local_backend.py')
support=runpy.run_path(str(script))
root,cfg,private=support['target'](sys.argv[1])
support['packages']()
report=[]


def check(name, action, denied=False):
    try:
        value=action()
    except RuntimeError:
        if not denied: raise
    else:
        support['require'](not denied and value is not False,'Expected check did not hold: '+name)
    report.append({'id':'b3.windows.launcher.'+name,'success':True})


check('real_owned_pg_and_schema',lambda:support['schema_identity'](root,cfg,private))
check('occupied_port_refused_without_kill',lambda:support['port_free'](cfg['backend_port']),True)
check('unbound_directory_refused',lambda:support['target'](root.parent),True)
os.environ['OPENAI_API_KEY']='synthetic-inherited-must-disappear'
os.environ['EMIE_DB']='synthetic-inherited-must-disappear'
support['controlled_environment'](root,cfg,private)
check('inherited_provider_and_alt_db_removed',lambda:'OPENAI_API_KEY' not in os.environ and 'EMIE_DB' not in os.environ)
check('system_root_preserved_and_dev_auth_disabled',lambda:bool(os.environ.get('SystemRoot')) and os.environ['DEV_ALLOW_HEADER']=='false')
check('dotenv_read_denied_before_open',lambda:open(root/'work/.env-b3-denied'),True)
check('external_socket_denied_before_connect',lambda:socket.create_connection(('192.0.2.1',1),timeout=.2),True)
import dotenv
check('dotenv_loader_disabled',lambda:dotenv.load_dotenv() is False)
support['save'](root/'logs/windows-launcher-checks.json',{'kind':'new Windows owned-target checks',
    'launcher_sha256':hashlib.sha256(script.read_bytes()).hexdigest(),'tests':report,'success':True})
print(json.dumps({'passed':len(report),'POSIX_suite_run':False}))
