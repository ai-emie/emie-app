"""Explicit HTTP acceptance against the verified owned Windows B3 target.

Credentials and mail proofs stay in its private directory, never in evidence.
Does not replace the existing POSIX 20-case suite or native UI evidence.
"""
import argparse
import base64
from datetime import datetime, timezone
from email import policy
from email.parser import BytesParser
import json
from pathlib import Path
import re
import runpy
import secrets
import time
from urllib.parse import urlparse, parse_qs

support=runpy.run_path(str(Path(__file__).with_name('local_backend.py')))


def run(mode, directory):
    root,cfg,private=support['target'](directory)
    support['packages']()
    support['schema_identity'](root,cfg,private)
    owner=support['worker_identity'](root,'backend')
    support['require'](all(x['OwningProcess']==owner['pid'] for x in support['listeners'](cfg['backend_port'])),'Backend listener identity')
    import httpx
    http=httpx.Client(base_url=f"http://127.0.0.1:{cfg['backend_port']}",timeout=25,trust_env=False)
    path=root/'private/accounts.json'
    accounts=json.loads(path.read_text()) if path.exists() else {}
    report=[]
    def persist():
        support['save'](path,accounts)
        support['save'](root/f'logs/api-{mode}.json',report)
    def request(id,method,path,*,body=None,account=None,status=(200,)):
        headers={'Authorization':'Bearer '+accounts[account]['access_token']} if account else {}
        response=http.request(method,path,json=body,headers=headers)
        ok=response.status_code in status
        report.append({'id':id,'kind':'HTTP against real local backend/PG','method':method,
            'path':path.split('?')[0],'status':response.status_code,'expected':list(status),'success':ok})
        persist()
        support['require'](ok, id+' HTTP status '+str(response.status_code)+'; response body intentionally not logged')
        return response
    def mail_token(email,route):
        for p in sorted((root/'mail').glob('*.eml'),reverse=True):
            msg=BytesParser(policy=policy.default).parsebytes(p.read_bytes())
            if msg['To']!=email: continue
            body=msg.get_body(preferencelist=('plain',))
            if body is None: continue
            for url in re.findall(r'https?://[^\s<>"\']+',body.get_content()):
                parsed=urlparse(url)
                if parsed.path==route and parsed.hostname=='10.0.2.2' and parsed.port==cfg['backend_port']:
                    token=parse_qs(parsed.query).get('token',[''])[0]
                    if re.fullmatch(r'[A-Za-z0-9_-]{20,256}',token): return token
        raise RuntimeError('Expected synthetic mail not found')
    try:
        if mode=='accounts':
            support['require'](not any('access_token' in v for v in accounts.values()),'Accounts are already fully provisioned; no reinitialization')
            request('b3.http.health','GET','/healthz')
            for key in ('A','B'):
                account=accounts.get(key) or {'email':f'b3-{key.lower()}-{root.name[-8:]}@example.com','password':secrets.token_urlsafe(18),'name':'B3 Test '+key}
                accounts[key]=account; persist()
                request('b3.auth.'+key+'.register','POST','/v1/auth/register',body={'email':account['email'],'password':account['password'],'name':account['name']},status=(201,))
                token=mail_token(account['email'],'/v1/auth/verify')
                request('b3.auth.'+key+'.verify_get_no_consume','GET','/v1/auth/verify?token='+token)
                request('b3.auth.'+key+'.unverified_login_rejected','POST','/v1/auth/login',body={'email':account['email'],'password':account['password']},status=(401,))
                request('b3.auth.'+key+'.verify_explicit_post','POST','/v1/auth/verify',body={'token':token})
                request('b3.auth.'+key+'.verify_replay_rejected','POST','/v1/auth/verify',body={'token':token},status=(400,))
                pair=request('b3.auth.'+key+'.login','POST','/v1/auth/login',body={'email':account['email'],'password':account['password']}).json()
                account.update(pair); persist()
                profile=request('b3.auth.'+key+'.authenticated_db_read','GET','/v1/profile',account=key).json()
                account['user_id']=profile['id']; persist()
        elif mode=='projects':
            item={'name':'B3 API project A','description':'synthetic local data','content':'first note'}
            project=request('b3.project.create','POST','/v1/projects',body=item,account='A',status=(201,)).json()
            accounts['A']['project_id']=project['id']; persist()
            request('b3.project.reopen','GET','/v1/projects/'+project['id'],account='A')
            item['content']='edited local note'
            edited=request('b3.project.edit','PUT','/v1/projects/'+project['id'],body=item,account='A').json()
            support['require'](edited['content']==item['content'],'Saved project note mismatch')
            request('b3.project.cross_owner_rejected','GET','/v1/projects/'+project['id'],account='B',status=(404,))
            other=request('b3.project.B_empty','GET','/v1/projects',account='B').json()
            support['require'](other['total_items']==0,'A project leaked to B')
            summary=request('b3.home.real_project_count','GET','/v1/home/summary',account='A').json()
            support['require'](summary['user_stats']['total_projects']>=1,'Home count missing')
            request('b3.project.delete','DELETE','/v1/projects/'+project['id'],account='A')
            request('b3.project.deleted_missing','GET','/v1/projects/'+project['id'],account='A',status=(404,))
        elif mode=='profile':
            data={'username':'B3 Account A','bio':'Local synthetic profile','daily_goal':'Check the local Android build'}
            request('b3.profile.save','PUT','/v1/profile',body=data,account='A')
            actual=request('b3.profile.reload','GET','/v1/profile',account='A').json()
            support['require'](all(actual[k]==v for k,v in data.items()),'Profile did not persist')
        elif mode=='memory':
            # Distinct supported extraction keys, not repetitions of one key.
            samples = [f'Meine Lieblings{x} ist B3 Test {x}.' for x in ('serie','essen','film','farbe','musik','spiel')]
            samples += ['Ich heisse Testname.', 'Ich bin 30 Jahre alt.',
                'Ich habe am 1.1.1996 Geburtstag.', 'Ich wohne in Teststadt.',
                'Ich arbeite als Testperson.', 'Ich habe ein synthetisches Testobjekt.',
                'Mein Ziel ist ein lokaler Test.', 'Mein Hobby ist Testen.',
                'Ich mag Tests.', 'Ich hasse Fehler.', 'Ich trinke morgens Testtee.']
            for i, sample in enumerate(samples):
                request('b3.memory.ingest.'+str(i),'POST','/v1/memory/ingest',body={'user_message':sample},account='A',status=(201,))
            for field, value in {'display_name':'B3 Testname','languages':'de,en',
                    'goal1':'Synthetisches Testziel','work_hours':'9-17'}.items():
                request('b3.memory.onboarding.'+field,'POST','/v1/onboarding/answer',
                    body={'question_id':field,'answer':value},account='A')
            a=request('b3.memory.page0','GET','/v1/memory/list?limit=20&offset=0',account='A').json()
            b=request('b3.memory.page20','GET','/v1/memory/list?limit=20&offset=20',account='A').json()
            support['require'](a['total_items']>20 and len(a['items'])==20 and b['items'],'More than 20 memories not established')
            support['require'](not ({x['id'] for x in a['items']} & {x['id'] for x in b['items']}),'Pagination overlap')
            support['save'](root/'logs/memory-pagination.json',{'total':a['total_items'],
                'first_page':len(a['items']),'second_page':len(b['items']),'overlap':False,
                'setup':'Normal authenticated ingest and onboarding HTTP routes'})
        elif mode=='reset':
            a=accounts['A']; old=a['password']; old_refresh=a['refresh_token']
            request('b3.reset.request','POST','/v1/auth/password/reset/start',body={'email':a['email']})
            proof=mail_token(a['email'],'/reset-password'); new=secrets.token_urlsafe(18)
            request('b3.reset.finish_while_B_active','POST','/v1/auth/password/reset/finish',body={'token':proof,'new_password':new},account='B')
            a['password']=new; persist()
            request('b3.reset.old_password_rejected','POST','/v1/auth/login',body={'email':a['email'],'password':old},status=(401,))
            request('b3.reset.old_refresh_revoked','POST','/v1/auth/refresh',body={'refresh_token':old_refresh},status=(401,))
            pair=request('b3.reset.new_password_login','POST','/v1/auth/login',body={'email':a['email'],'password':new}).json(); a.update(pair); persist()
            request('b3.reset.B_session_unchanged','GET','/v1/profile',account='B')
        elif mode=='chat':
            response=request('b3.chat.no_paid_provider','POST','/v1/chat/respond',body={'message':'Bitte antworte auf diesen lokalen Test.','chat_session_id':None},account='A',status=(200,503))
            # No provider key is configured and outbound transport is denied by launcher.
            support['save'](root/'logs/chat-result.json',{'status':response.status_code,'body':response.json()})
        elif mode=='welcome':
            # Reproduce only; this existing product/schema defect is outside B3.
            response=request('b3.defect.daily_welcome_enum','GET','/v1/get-daily-welcome',account='A',status=(500,))
            support['save'](root/'logs/daily-welcome-defect.json',{'status':response.status_code,
                'expected_product_behavior':'200 greeting','acceptance':'FAIL',
                'observed_backend_error':'invalid input value for enum memory_category: emotion',
                'action':'Component stopped; no product or migration modification'})
        elif mode=='native-reset-check':
            a=accounts['A']; old=a['password']; new=a['new_password']; old_refresh=a['refresh_token']
            request('b3.native_reset.old_password_rejected','POST','/v1/auth/login',body={'email':a['email'],'password':old},status=(401,))
            request('b3.native_reset.old_refresh_revoked','POST','/v1/auth/refresh',body={'refresh_token':old_refresh},status=(401,))
            pair=request('b3.native_reset.new_password_login','POST','/v1/auth/login',body={'email':a['email'],'password':new}).json()
            a['password']=new; a.update(pair); persist()
            request('b3.native_reset.B_session_unchanged','GET','/v1/profile',account='B')
        elif mode=='profile-read':
            data=request('b3.profile.native_failure_http_comparison','GET','/v1/profile',account='A').json()
            types={key:type(value).__name__ for key,value in data.items()}
            support['require'](all(types.get(k)=='str' for k in ('id','email','username','bio','daily_goal')),'Unexpected profile field types')
            support['save'](root/'logs/profile-native-defect.json',{'http_status':200,'fields':types,
                'native_observation':'ProfileEditor load and retry show failure',
                'native_acceptance':'FAIL','cause':'Not established; product component left unchanged'})
        elif mode=='B-refresh':
            b=accounts['B']; payload=b['access_token'].split('.')[1]
            claims=json.loads(base64.urlsafe_b64decode(payload+'='*(-len(payload)%4)))
            expired=claims['exp']<time.time()
            pair=request('b3.native_reset.B_refresh_still_valid','POST','/v1/auth/refresh',body={'refresh_token':b['refresh_token']}).json()
            b.update(pair); persist()
            result=request('b3.native_reset.B_profile_after_refresh','GET','/v1/profile',account='B').json()
            support['require'](result['id']==b['user_id'],'B identity changed')
            support['save'](root/'logs/B-access-expiry.json',{'previous_access_expired':expired,
                'previous_access_exp_utc':datetime.fromtimestamp(claims['exp'],timezone.utc).isoformat(),
                'refresh_retained_across_A_reset':True,'native_B_login_was_separate':True})
        elif mode=='delete-prepare':
            created=request('b3.native_deletion.prepare_project','POST','/v1/projects',body={'name':'B3 deleted with B','content':'synthetic'},account='B',status=(201,)).json()
            accounts['B']['deletion_project_id']=created['id']; persist()
        elif mode=='delete-check':
            request('b3.native_deletion.old_access_rejected','GET','/v1/profile',account='B',status=(401,))
            with support['connect'](root,cfg,private) as db:
                with db.cursor() as c:
                    c.execute('SELECT count(*) FROM projects WHERE id=%s',(accounts['B']['deletion_project_id'],))
                    support['require'](c.fetchone()[0]==0,'Deleted B project survived')
                    c.execute('SELECT count(*) FROM users WHERE id=%s',(accounts['B']['user_id'],))
                    support['require'](c.fetchone()[0]==0,'Deleted B account survived')
            accounts['B']['deleted']=True; persist()
            support['save'](root/'logs/native-deletion-db-check.json',{'B_user_rows':0,'B_project_rows':0,'old_access_http':401})
        elif mode=='delete':
            created=request('b3.deletion.project','POST','/v1/projects',body={'name':'B3 deleted with B','content':'synthetic'},account='B',status=(201,)).json()
            request('b3.deletion.non_apple','DELETE','/v1/me',account='B')
            request('b3.deletion.old_token_rejected','GET','/v1/profile',account='B',status=(401,))
            with support['connect'](root,cfg,private) as db:
                with db.cursor() as c:
                    c.execute('SELECT count(*) FROM projects WHERE id=%s',(created['id'],))
                    support['require'](c.fetchone()[0]==0,'Deleted account project survived')
            accounts['B']['deleted']=True; persist()
        print(json.dumps({'mode':mode,'checks':len(report),'success':all(x['success'] for x in report),'kind':'HTTP, not native UI'},indent=2))
    except Exception as error:
        report.append({'id':'b3.'+mode+'.completion','success':False,'failure':str(error)})
        persist(); raise
    finally: http.close()


if __name__=='__main__':
    p=argparse.ArgumentParser(); p.add_argument('mode',choices=('accounts','projects','profile','profile-read','memory','reset','native-reset-check','B-refresh','delete-prepare','delete-check','chat','welcome','delete')); p.add_argument('root')
    a=p.parse_args(); run(a.mode,a.root)
