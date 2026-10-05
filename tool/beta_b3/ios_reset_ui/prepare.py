"""Private fixture orchestration. Never sends a successful finish; only explicit replay counterchecks."""
import json, os, secrets, urllib.request, urllib.error, email, email.policy, re, sys, time, hashlib, subprocess
from pathlib import Path
os.umask(0o077)
export=Path(sys.argv[1]); mode=sys.argv[2]; state=json.loads((export/'state.json').read_text()); root=Path(state['pgroot']); control=Path(state['control']); store=control/'accounts.json'
for key in ['postgres','smtp','backend_process']:
 row=state[key]
 assert subprocess.check_output(['/bin/ps','-p',str(row['pid']),'-o','pid=,uid=,lstart=,command='],text=True)==row['identity']
 assert '127.0.0.1:'+str(row['port']) in subprocess.check_output(['/usr/sbin/lsof','-nP','-a','-p',str(row['pid']),'-iTCP','-sTCP:LISTEN'],text=True)
def request(path, body=None, token=None):
 headers={'Content-Type':'application/json'}
 if token: headers['Authorization']='Bearer '+token
 req=urllib.request.Request('http://127.0.0.1:8010'+path,data=json.dumps(body).encode() if body is not None else None,headers=headers)
 try:
  with urllib.request.urlopen(req,timeout=15) as response:return response.status,json.load(response)
 except urllib.error.HTTPError as error:return error.code,json.load(error)
def mailproof(before, route):
 deadline=time.monotonic()+5
 while time.monotonic()<deadline:
  new=set((root/'mail').glob('*.eml'))-before
  if new:break
  time.sleep(.1)
 assert len(new)==1
 mail=email.message_from_bytes(new.pop().read_bytes(),policy=email.policy.default)
 body='\n'.join(p.get_content() for p in mail.walk() if p.get_content_type() in ('text/plain','text/html'))
 match=re.search(route+r'\?token=([A-Za-z0-9_-]+)',body);assert match
 return match.group(1)
if mode=='accounts':
 assert not store.exists()
 accounts={}; evidence=[]
 for label in ['A','B']:
  address='ios-e2e-'+label.lower()+'-'+secrets.token_hex(3)+'@example.com'; password=secrets.token_urlsafe(15)
  before=set((root/'mail').glob('*.eml'))
  code,_=request('/v1/auth/register',{'name':'E2E '+label,'email':address,'password':password});assert code==201
  proof=mailproof(before,'/v1/auth/verify');code,_=request('/v1/auth/verify',{'token':proof});assert code==200
  code,tokens=request('/v1/auth/login',{'email':address,'password':password});assert code==200
  accounts[label]={'email':address,'password':password,**tokens};evidence.append({'label':label,'register':201,'local_mail':True,'verify_post':200,'login':200})
 store.write_text(json.dumps(accounts));(export/'review/evidence/accounts.json').write_text(json.dumps(evidence,indent=2))
elif mode in ['I1','I2','I3','I4']:
 assert not (control/(mode+'.json')).exists(), 'Do not replace an existing reset attempt'
 accounts=json.loads(store.read_text());a=accounts['A'];code,tokens=request('/v1/auth/login',{'email':a['email'],'password':a['password']});assert code==200
 before=set((root/'mail').glob('*.eml'));code,_=request('/v1/auth/password/reset/start',{'email':a['email']});assert code==200
 proof=mailproof(before,'/reset-password');new=secrets.token_urlsafe(15)
 bcode,bprofile=request('/v1/profile',token=accounts['B']['access_token']);assert bcode==200
 config={'scenario':mode,'email':a['email'],'old_password':a['password'],'new_password':new,'old_refresh':tokens['refresh_token'],'proof':proof,'url':'emie-local-recovery://recover/reset-password?token='+proof,'b_email':accounts['B']['email'],'b_password':accounts['B']['password'],'b_profile':bprofile}
 (control/(mode+'.json')).write_text(json.dumps(config));(export/'private/ui-config.json').write_text(json.dumps(config));(control/'scenario').write_text(mode)
 if mode=='I4':(control/'lose-next.json').write_text(json.dumps({'scenario':mode,'proof_sha256':hashlib.sha256(proof.encode()).hexdigest()}))
elif mode=='verify':
 case=sys.argv[3];config=json.loads((control/(case+'.json')).read_text());accounts=json.loads(store.read_text());a=accounts['A'];b=accounts['B']
 events=[json.loads(l) for l in (control/'http.jsonl').read_text().splitlines()];selected=[e for e in events if e['scenario']==case]
 finishes=[e for e in selected if e['event']=='finish_application_returned'];assert len(finishes)==1 and finishes[0]['status']==200
 assert not any(e.get('route')=='/v1/auth/refresh' for e in selected)
 (control/'scenario').write_text(case+'-explicit-postchecks')
 out={'scenario':case,'ui_finish_count':len(finishes),'ui_http_events':selected}
 out['old_password']=request('/v1/auth/login',{'email':a['email'],'password':config['old_password']})[0];assert out['old_password']==401
 out['old_refresh']=request('/v1/auth/refresh',{'refresh_token':config['old_refresh']})[0];assert out['old_refresh']==401
 out['new_password'],tokens=request('/v1/auth/login',{'email':a['email'],'password':config['new_password']});assert out['new_password']==200
 out['explicit_replay']=request('/v1/auth/password/reset/finish',{'token':config['proof'],'new_password':'never-apply-replay'})[0];assert out['explicit_replay']==400
 out['new_password_after_replay']=request('/v1/auth/login',{'email':a['email'],'password':config['new_password']})[0];assert out['new_password_after_replay']==200
 out['b_profile_status'],profile=request('/v1/profile',token=b['access_token']);assert out['b_profile_status']==200 and profile==config['b_profile'];out['b_profile_unchanged']=True
 out['b_refresh'],btokens=request('/v1/auth/refresh',{'refresh_token':b['refresh_token']});assert out['b_refresh']==200
 b.update(btokens);a.update(tokens);a['password']=config['new_password'];store.write_text(json.dumps(accounts))
 (export/'review/evidence'/(case+'-postchecks.json')).write_text(json.dumps(out,indent=2))
else:raise ValueError(mode)
print(mode,'completed; credentials/proofs remain private')
