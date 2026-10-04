"""Owned-target HTTP proofs. Private responses never go to stdout."""
import argparse,json,runpy,secrets,time
from pathlib import Path
from email import policy
from email.parser import BytesParser
from urllib.parse import urlparse,parse_qs
import re

def run(mode,root_path,run_path):
 support=runpy.run_path(str(Path(__file__).with_name('local_backend.py')))
 root,cfg,private=support['target'](root_path); out=Path(run_path)
 support['packages'](); support['schema_identity'](root,cfg,private)
 owner=support['worker_identity'](root,'backend'); sockets=support['listeners'](cfg['backend_port'])
 support['require'](sockets and all(x['OwningProcess']==owner['pid'] and x['LocalAddress']=='127.0.0.1' for x in sockets),'HTTP target binding failed')
 support['controlled_environment'](root,cfg,private)
 import httpx
 accounts_path=root/'private/accounts.json'; accounts=json.loads(accounts_path.read_text())
 checks=[]; replies={}
 def save():
  support['save'](accounts_path,accounts); support['save'](out/f'logs/http-{mode}.json',checks)
 def request(id,method,path,account=None,body=None,status=200):
  headers={'Authorization':'Bearer '+accounts[account]['access_token']} if account else {}
  response=client.request(method,path,json=body,headers=headers)
  checks.append({'id':id,'method':method,'path':path.split('?')[0],'http_status':response.status_code,'expected':status,'passed':response.status_code==status})
  save(); support['require'](response.status_code==status,id+' unexpected HTTP status; private body not printed')
  return response.json() if response.headers.get('content-type','').startswith('application/json') else None
 def login(key):
  a=accounts[key]; pair=request('login.'+key,'POST','/v1/auth/login',body={'email':a['email'],'password':a['password']}); a.update(pair); save()
 def token(email,route):
  for file in sorted((root/'mail').glob('*.eml'),reverse=True):
   msg=BytesParser(policy=policy.default).parsebytes(file.read_bytes())
   if msg['To']!=email: continue
   body=msg.get_body(preferencelist=('plain',))
   for raw in re.findall(r'https?://[^\s<>"\']+',body.get_content() if body else ''):
    uri=urlparse(raw)
    if uri.path==route and uri.hostname=='10.0.2.2' and uri.port==cfg['backend_port']:
     proof=parse_qs(uri.query).get('token',[''])[0]
     if re.fullmatch(r'[A-Za-z0-9_-]{20,256}',proof): return proof
  raise RuntimeError('Own local synthetic mail missing')
 def register(key):
  if key in accounts: login(key); return
  a={'email':key.lower()+'-'+out.name[-8:]+'@example.com','password':secrets.token_urlsafe(18),'name':'B3 '+key}; accounts[key]=a; save()
  request('register.'+key,'POST','/v1/auth/register',body={'email':a['email'],'password':a['password'],'name':a['name']},status=201)
  proof=token(a['email'],'/v1/auth/verify')
  request('verify.'+key,'POST','/v1/auth/verify',body={'token':proof}); login(key)
  profile=request('identity.'+key,'GET','/v1/profile',key); a['user_id']=profile['id']; save()
 with httpx.Client(base_url=f"http://127.0.0.1:{cfg['backend_port']}",trust_env=False,timeout=20) as client:
  if mode=='red':
   login('A')
   replies['me']=request('red.me','GET','/v1/me','A'); replies['profile']=request('red.profile','GET','/v1/profile','A')
   request('red.daily_welcome','GET','/v1/get-daily-welcome','A',status=500)
   support['require']('id' not in replies['me'] and isinstance(replies['profile'].get('id'),str),'Expected ID gap not reproduced')
   support['save'](out/'logs/red-identity-gap.json',{'me_id_present':False,'profile_id_is_nonempty_string':bool(replies['profile']['id']),
    'Dart_parser_missing_id_becomes_empty':True,'identity_equal':False,'product_acceptance':'FAIL: red reproduction, not target PASS'})
   support['save'](out/'private/profile-red.json',replies)
  elif mode=='green':
   for key in ('A','R1B','R1P','R1Old'):
    login(key) if key=='A' else register(key)
   for key in ('A','R1B'):
    me=request('green.me.'+key,'GET','/v1/me',key); profile=request('green.profile.'+key,'GET','/v1/profile',key)
    support['require'](me['id']==profile['id']==accounts[key]['user_id'],'Server identity differs')
    replies[key]={'me':me,'profile':profile}
   support['save'](out/'private/profile-green.json',replies)
  else: raise RuntimeError('Unknown mode')
 save(); print(json.dumps({'mode':mode,'checks':len(checks),'all_expected_statuses':all(x['passed'] for x in checks),'product_pass':mode!='red'}))

if __name__=='__main__':
 p=argparse.ArgumentParser(); p.add_argument('mode',choices=('red','green')); p.add_argument('root'); p.add_argument('run'); a=p.parse_args(); run(a.mode,a.root,a.run)
