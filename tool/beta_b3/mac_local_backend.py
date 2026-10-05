"""Mac-only synthetic server helper. Uses one externally verified owned PG cluster.
Run CPython 3.11.9 -I -S -B; no host dotenv, providers, production DSN or migrations.
The setup mode applies existing migrations only to a new dedicated synthetic UI DB.
"""
from pathlib import Path
import os,sys,json,subprocess,socket,secrets,time,signal,datetime
BACKEND=Path('/Users/emiso/Documents/ChatGPT/Emiso Backend')
PACKAGES=Path('/Users/emiso/Emie-Recovery/toolchains/r3c-20260927T223712Z-9f6a/venv/lib/python3.11/site-packages')
assert sys.version_info[:3]==(3,11,9) and sys.flags.isolated and sys.flags.no_site and os.name=='posix'
sys.path[:0]=[str(BACKEND),str(PACKAGES)]
os.umask(0o077)
mode=sys.argv[1];root=Path(sys.argv[2]).resolve(strict=True)
assert root.parent==Path('/private/tmp') and root.name.startswith('emiso-confirm-pg-') and root.stat().st_uid==os.getuid() and not root.stat().st_mode & 0o077
pg=json.loads((root/'postgres-target.json').read_text());pid=(root/'pgdata/postmaster.pid').read_text().splitlines()
assert int(pid[0])==pg['postmaster_pid'] and pid[1]==str(root/'pgdata') and int(pid[2])==pg['started_at'] and int(pid[3])==pg['port']
os.kill(pg['postmaster_pid'],0)
# All management connections follow an external process/listener identity check.
process=subprocess.run(['/bin/ps','-p',str(pg['postmaster_pid']),'-o','uid=,command='],capture_output=True,text=True,timeout=10)
assert str(root/'pgdata') in process.stdout and str(os.getuid()) in process.stdout
listeners=subprocess.run(['/usr/sbin/lsof','-nP','-a','-p',str(pg['postmaster_pid']),'-iTCP','-sTCP:LISTEN'],capture_output=True,text=True,timeout=10)
assert '127.0.0.1:'+str(pg['port']) in listeners.stdout
import psycopg2
if mode=='setup':
 assert not (root/'ui-target.json').exists(), 'Never repeat setup or overwrite UI data'
 with socket.socket() as probe: probe.bind(('127.0.0.1',8010))
 with socket.socket() as probe: probe.bind(('127.0.0.1',0));mailport=probe.getsockname()[1]
 cfg={'database':'emiso_ui_'+secrets.token_hex(6),'role':pg['role'],'port':pg['port'],'backend_port':8010,'mail_port':mailport}
 admin=psycopg2.connect(host='127.0.0.1',port=pg['port'],dbname='postgres',user='emie_harness_admin',password=(root/'admin-password').read_text().strip(),connect_timeout=5,passfile=str(root/'empty.pgpass'));admin.autocommit=True
 from psycopg2 import sql
 with admin.cursor() as c:
  c.execute(sql.SQL('CREATE DATABASE {} OWNER {}').format(sql.Identifier(cfg['database']),sql.Identifier(cfg['role'])))
  c.execute(sql.SQL('REVOKE CONNECT ON DATABASE {} FROM PUBLIC').format(sql.Identifier(cfg['database'])))
 admin.close();(root/'ui-target.json').write_text(json.dumps(cfg));(root/'ui-jwt').write_text(secrets.token_urlsafe(48))
 for n in ['ui-work','mail','ui-public','ui-private']: (root/n).mkdir(mode=0o700)
else: cfg=json.loads((root/'ui-target.json').read_text())
password=(root/'pg-password').read_text().strip();jwt=(root/'ui-jwt').read_text().strip()
if mode=='smtp':
 import smtpd,asyncore
 class Capture(smtpd.SMTPServer):
  def process_message(self,peer,mailfrom,rcpttos,data,**kwargs):
   if not all(x.endswith('@example.com') for x in rcpttos): return '550 Synthetic recipients only'
   (root/'mail'/(str(time.time_ns())+'.eml')).write_bytes(data)
 capture=Capture(('127.0.0.1',cfg['mail_port']),None,decode_data=False)
 signal.signal(signal.SIGTERM,lambda *_: sys.exit(0));signal.alarm(6000)
 try: asyncore.loop(timeout=.2)
 finally: capture.close()
 sys.exit()
from urllib.parse import quote
os.environ.clear();os.environ.update(ENVIRONMENT='test',DEV_ALLOW_HEADER='false',PYTHON_DOTENV_DISABLED='1',DATABASE_URL=f"postgresql+psycopg2://{cfg['role']}:{quote(password)}@127.0.0.1:{cfg['port']}/{cfg['database']}",JWT_SECRET=jwt,UPLOAD_DIR=str(root/'ui-public'),PRIVATE_UPLOAD_DIR=str(root/'ui-private'),APPLE_CONFIRMATION_ENABLED='false',APPLE_ACCOUNT_DELETION_ENABLED='false',APPLE_REVOCATION_WORKER_ENABLED='false',APPLE_CLIENT_ID='synthetic.apple.client',GOOGLE_CLIENT_ID='synthetic.google.client',SMTP_HOST='127.0.0.1',SMTP_PORT=str(cfg['mail_port']),SMTP_TLS='0',SMTP_FROM='emie-local@example.com',FRONTEND_BASE_URL='http://127.0.0.1:8010',PUBLIC_BASE_URL='http://127.0.0.1:8010',ADMIN_EMAILS='',PGPASSFILE=str(root/'empty.pgpass'),PGSYSCONFDIR=str(root))
os.chdir(root/'ui-work')
import dotenv
from unittest.mock import patch
patch.object(dotenv,'load_dotenv',return_value=False).start()
def deny(*a,**kw):raise RuntimeError('External application access forbidden')
patch.object(dotenv,'dotenv_values',deny).start()
def audit(event,args):
 if event=='open' and isinstance(args[0],(str,bytes)):
  name=Path(os.fsdecode(args[0])).name.lower()
  if name.startswith('.env') or name.endswith(('.p8','.p12','.pem','.key')):deny()
 if event=='socket.connect':
  address=args[1]
  if isinstance(address,tuple) and address!=('127.0.0.1',cfg['mail_port']):deny()
 if event=='subprocess.Popen':deny()
sys.addaudithook(audit)
from psycopg2.extensions import parse_dsn
native=psycopg2._connect
def checked(dsn,*a,**kw):
 d=parse_dsn(dsn)
 for key,value in {'host':'127.0.0.1','port':str(cfg['port']),'dbname':cfg['database'],'user':cfg['role'],'password':password}.items():
  if d.get(key)!=value:deny()
 if d.get('hostaddr') or d.get('service'):deny()
 return native(dsn,*a,**kw)
patch.object(psycopg2,'_connect',checked).start()
import httpx
patch.object(httpx.HTTPTransport,'handle_request',deny).start();patch.object(httpx.AsyncHTTPTransport,'handle_async_request',deny).start()
import sqlalchemy as sa
from app.db.session import engine
with engine.connect() as c:
 actual=c.exec_driver_sql("SELECT current_database(),current_user,current_setting('data_directory'),current_setting('server_version_num'),current_setting('fsync'),current_setting('synchronous_commit')").one()
 assert tuple(actual)==(cfg['database'],cfg['role'],str(root/'pgdata'),'170011','on','on')
if mode=='setup':
 from app.tests.memory_test_support import migrate
 migrate(engine,'d8e4b2a90173')
 with engine.connect() as c:assert c.exec_driver_sql('SELECT version_num FROM alembic_version').scalars().all()==['d8e4b2a90173']
 print('Dedicated UI database migrated through unchanged full chain; no application bypass')
elif mode=='backend':
 import asyncio,uvicorn,main
 assert Path(main.__file__).resolve()==BACKEND/'main.py'
 accounts = json.loads((root/'ui-accounts.json').read_text()) if (root/'ui-accounts.json').exists() else {}
 class SafeEvidence:
  def __init__(self,app):self.app=app
  async def __call__(self,scope,receive,send):
   async def tracked(message):
    if scope['type']=='http' and message['type']=='http.response.start':
     # No query, headers, body, identities or proofs are recorded.
     path=scope.get('path',''); known={'/v1/auth/login','/v1/auth/register','/v1/auth/verify','/v1/auth/password/reset/start','/v1/auth/password/reset/finish','/v1/auth/refresh','/v1/auth/logout','/v1/me','/v1/profile','/v1/home','/v1/projects','/v1/memory'}
     with (root/'ui-http-evidence.jsonl').open('a') as f:f.write(json.dumps({'utc':datetime.datetime.now(datetime.timezone.utc).isoformat(),'method':scope['method'],'route':path if path in known else 'other','status':message['status']})+'\n')
    await send(message)
   body = bytearray()
   async def checked_receive():
    message = await receive()
    if scope.get('path') == '/v1/auth/login' and message['type'] == 'http.request':
     body.extend(message.get('body', b''))
     if len(body) > 4096: body.clear()
     elif not message.get('more_body'):
      try:
       supplied = json.loads(body)
       matched = {name: {'email_match': supplied.get('email','').lower().strip() == account['email'],
                         'password_match': supplied.get('password') == account['password']}
                  for name, account in accounts.items()}
       with (root/'ui-input-check.jsonl').open('a') as out: out.write(json.dumps(matched)+'\n')
      finally: body.clear()
    return message
   await self.app(scope,checked_receive,tracked)
 signal.alarm(6000)
 uvicorn.run(SafeEvidence(main.app),host='127.0.0.1',port=cfg['backend_port'],access_log=False,proxy_headers=False,log_level='warning')
else:raise ValueError('mode')
