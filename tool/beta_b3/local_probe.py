"""Explicit local-only metadata and one-shot lost-confirmation test, never product middleware."""
import json,re,time
from pathlib import Path
class LocalProbeMiddleware:
 def __init__(self,app,cfg):
  self.app=app;self.log=Path(cfg['probe_log']);self.folder=Path(cfg['probe_directory']);self.allow_response_loss=cfg.get('allow_response_loss',False)
 async def __call__(self,scope,receive,send):
  if scope['type']!='http':return await self.app(scope,receive,send)
  routes={'/v1/me':'me','/v1/profile':'profile','/v1/auth/login':'login','/v1/auth/refresh':'refresh','/v1/auth/password/reset/finish':'reset_finish','/v1/auth/password/reset/start':'reset_start','/v1/get-daily-welcome':'welcome','/v1/home/summary':'home'}
  phase=routes.get(scope.get('path'));started=time.monotonic();headers=dict(scope.get('headers',[]));probe=headers.get(b'x-emie-local-probe',b'').decode('ascii','ignore');probe=probe if re.fullmatch('[0-9]{1,12}',probe) else None
  flag=self.folder/'drop-reset-next';drop=self.allow_response_loss and phase=='reset_finish' and flag.exists();messages=[];status=None
  def record(event,**extra):
   if phase:
    with self.log.open('a',encoding='utf-8') as f:f.write(json.dumps({'event':event,'phase':phase,'probe':probe,'elapsed_ms':round((time.monotonic()-started)*1000),'status':status,**extra})+'\n')
  record('request')
  async def capture(message):
   nonlocal status
   if message['type']=='http.response.start':status=message['status']
   if drop:messages.append(message)
   else:await send(message)
  try:
   await self.app(scope,receive,capture)
   if drop:
    if status==200:
     flag.rename(self.folder/'drop-reset-consumed')
     record('committed_ack_suppressed',original_status=200)
     await send(next(m for m in messages if m['type']=='http.response.start'))
     # Commit has succeeded; omit the response body and close through Uvicorn's
     # existing response-started exception path. No proof replay or fake success.
     raise RuntimeError('Synthetic lost response body after successful reset')
    for message in messages:await send(message)
   record('response')
  except BaseException as error:
   record('exception',error_class=type(error).__name__);raise
