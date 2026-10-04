"""Narrow launcher tests; no app import, DB mutation, provisioning or process kill."""
import copy
import json
from pathlib import Path
import runpy
import socket
import sys
import unittest
from unittest.mock import patch

android = runpy.run_path(str(Path(__file__).with_name('android_local.py')))
support = android['support']
ROOT = r'C:\Users\Patze\Emie-LocalDev\b3-20261002T132620Z-4c04767e'


class StartContract(unittest.TestCase):
    def setUp(self):
        self.root, self.cfg, self.private = support['target'](ROOT)

    def test_active_repositories_and_private_normal_target(self):
        support['validate_target'](self.root, self.cfg)
        self.assertEqual(android['APP'], Path(r'C:\Users\Patze\Emie\app'))
        self.assertEqual(support['BACKEND'], Path(r'C:\Users\Patze\Emie\backend'))

    def test_wrong_data_targets_rejected_before_connection(self):
        for key, value in [('database','emie_b4_restore'),('role','postgres'),
                           ('pg_port',5432),('mail_port',587)]:
            with self.subTest(key=key):
                cfg=dict(self.cfg, **{key:value})
                with self.assertRaisesRegex(RuntimeError,'data target mismatch'):
                    support['connect'](self.root,cfg,self.private)

    def test_candidate_and_8000_never_fallback(self):
        for key, value in [('backend',str(self.root/'candidate/backend')),
                           ('app',str(self.root/'candidate/app')),('backend_port',8000),
                           ('backend_port',8020),('backend_port','8010')]:
            with self.subTest(key=key,value=value), self.assertRaises(RuntimeError):
                support['validate_target'](self.root,dict(self.cfg,**{key:value}))

    def test_foreign_listener_refused_before_pg_start_without_kill(self):
        port=self.cfg['backend_port']
        support['port_free'](port)
        with socket.socket() as listener:
            listener.setsockopt(socket.SOL_SOCKET,socket.SO_EXCLUSIVEADDRUSE,1)
            listener.bind(('127.0.0.1',port));listener.listen()
            with patch.dict(support['start'].__globals__,pg_start=lambda *args:self.fail('PG must not start')):
                with self.assertRaisesRegex(RuntimeError,'occupied'):
                    support['start'](self.root,self.cfg,self.private)
            self.assertEqual(listener.getsockname(),('127.0.0.1',port))

    def test_response_loss_disabled_in_normal_start(self):
        with self.assertRaisesRegex(RuntimeError,'response-loss'):
            support['validate_target'](self.root,dict(self.cfg,allow_response_loss=True))

    def test_stale_or_candidate_apk_cannot_start_emulator(self):
        # Metadata only; the real old APK remains untouched.
        meta=json.loads((self.root/'artifacts/apk.json').read_text())
        meta['active_app']=str(self.root/'candidate/app')
        original=Path.read_text
        def read(path,*args,**kwargs):
            if path==self.root/'artifacts/apk.json': return json.dumps(meta)
            return original(path,*args,**kwargs)
        with patch.object(Path,'read_text',read),self.assertRaisesRegex(RuntimeError,'active repository'):
            android['current_apk'](self.root)

    def test_start_has_no_provisioning_or_migration_call(self):
        events=[]
        def mark(name): return lambda *a,**kw:events.append(name)
        replacements={name:mark(name) for name in ('port_free','pg_start','schema_identity','spawn_worker')}
        replacements.update(command=lambda *a,**kw:b'fixture lifespan',
                            setup=lambda *a:self.fail('setup'),provision=lambda *a:self.fail('provision'),
                            migrate=lambda *a:self.fail('migrate'))
        with patch.dict(support['start'].__globals__,replacements),patch.object(Path,'write_bytes',lambda *a:None):
            support['start'](self.root,self.cfg,self.private)
        self.assertEqual(events,['port_free','pg_start','schema_identity','spawn_worker','spawn_worker'])


if __name__=='__main__':
    unittest.main(verbosity=2)
