"""Transport-only countercases. These do not stand in for the native reset scenarios."""
import asyncio, hashlib, json, tempfile, unittest
from pathlib import Path
from ios_reset_loss import LocalResetEvidence

class LossTests(unittest.IsolatedAsyncioTestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory(prefix='emiso-confirm-pg-')
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name) / 'e2e-test'; self.root.mkdir(mode=0o700)
        (self.root/'scenario').write_text('I4')
        self.returned = False; self.sent = []
    async def app(self, scope, receive, send):
        await receive()
        await send({'type':'http.response.start','status':200,'headers':[(b'content-length',b'15')]})
        await send({'type':'http.response.body','body':b'{"status":"ok"}','more_body':False})
        self.returned = True
    async def call(self):
        async def receive():return {'type':'http.request','body':b'{"token":"synthetic"}'}
        async def send(message):
            self.assertTrue(self.returned)
            self.sent.append(message)
        await LocalResetEvidence(self.app,self.root)({'type':'http','method':'POST','path':'/v1/auth/password/reset/finish'},receive,send)
    def arm(self, proof='synthetic'):
        (self.root/'lose-next.json').write_text(json.dumps({'scenario':'I4','proof_sha256':hashlib.sha256(proof.encode()).hexdigest()}))
    async def test_unarmed_delivers_complete_response(self):
        await self.call();self.assertEqual(len(self.sent),2)
    async def test_wrong_proof_does_not_consume_arm(self):
        self.arm('other');await self.call();self.assertEqual(len(self.sent),2);self.assertTrue((self.root/'lose-next.json').exists())
    async def test_explicit_loss_after_return_is_once_only(self):
        self.arm()
        with self.assertRaises(ConnectionResetError):await self.call()
        self.assertTrue(self.returned);self.assertEqual(len(self.sent),1)
        self.assertFalse((self.root/'lose-next.json').exists())
        self.sent=[];await self.call();self.assertEqual(len(self.sent),2)

if __name__=='__main__':unittest.main(verbosity=2)
