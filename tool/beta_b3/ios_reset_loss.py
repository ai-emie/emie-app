"""Explicit own-target UI evidence/one-shot transport fault, never product middleware."""
import hashlib
import json
import os
import time
from pathlib import Path

class LocalResetEvidence:
    def __init__(self, app, root):
        self.app = app
        self.root = Path(root).resolve(strict=True)
        assert self.root.parent.name.startswith('emiso-confirm-pg-')
        assert self.root.name.startswith('e2e-')
        assert self.root.stat().st_uid == os.getuid() and not self.root.stat().st_mode & 0o077

    def event(self, **data):
        with (self.root / 'http.jsonl').open('a') as f:
            f.write(json.dumps(dict(time_ns=time.time_ns(), **data)) + '\n')

    async def __call__(self, scope, receive, send):
        if scope['type'] != 'http':
            return await self.app(scope, receive, send)
        path = scope.get('path', '')
        scenario = (self.root / 'scenario').read_text().strip()
        finish = path == '/v1/auth/password/reset/finish'
        body = bytearray()
        messages = []
        async def recv():
            message = await receive()
            if finish:
                body.extend(message.get('body', b''))
                if len(body) > 8192: raise RuntimeError('Unexpected oversized local fixture')
            return message
        async def capture(message):
            if message['type'] == 'http.response.start':
                self.event(scenario=scenario, event='response_generated', route=path if path.startswith('/v1/auth/') or path in ('/v1/me', '/v1/profile') else 'other', method=scope['method'], status=message['status'])
            if finish: messages.append(message)
            else: await send(message)
        await self.app(scope, recv, capture)
        if not finish: return
        self.event(scenario=scenario, event='finish_application_returned', status=messages[0]['status'])
        marker = self.root / 'lose-next.json'
        armed = json.loads(marker.read_text()) if marker.exists() else None
        token = json.loads(body).get('token', '')
        if armed and armed['scenario'] == scenario and armed['proof_sha256'] == hashlib.sha256(token.encode()).hexdigest():
            assert messages[0]['status'] == 200, 'Never lose a failed reset'
            response = b''.join(m.get('body', b'') for m in messages[1:])
            assert json.loads(response).get('status') == 'ok', 'Normal valid confirmation required'
            marker.rename(self.root / ('consumed-' + scenario + '.json'))
            self.event(scenario=scenario, event='one_shot_loss_after_application_return', valid_confirmation=True, response_bytes=len(response))
            await send(messages[0])
            # Headers reached the socket, but its declared valid body never does.
            raise ConnectionResetError('Explicit synthetic one-shot response-body loss')
        for message in messages: await send(message)
        self.event(scenario=scenario, event='finish_delivered', status=messages[0]['status'])
