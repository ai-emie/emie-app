"""ADB UI evidence on the one owned emulator; private credentials never printed."""
import argparse
from datetime import datetime, timezone
from email import policy
from email.parser import BytesParser
import json
from pathlib import Path
import re
import runpy
import secrets
import time
from urllib.parse import parse_qs, urlparse
import xml.etree.ElementTree as ET

android=runpy.run_path(str(Path(__file__).with_name('android_local.py')))
support=android['support']


def run(mode,directory,values):
    root,cfg,private=support['target'](directory)
    android['identity'](root)
    adb=lambda *args:android['adb'](root,*args)
    accounts_path=root/'private/accounts.json'
    accounts=json.loads(accounts_path.read_text())
    stamp=datetime.now(timezone.utc).strftime('%Y%m%dT%H%M%S%fZ')
    def redact(value):
        for item in accounts.values():
            for k,v in item.items():
                if k in ('email','password','access_token','refresh_token','new_password') and isinstance(v,str):
                    value=value.replace(v,'[private synthetic '+k+']')
        return re.sub(r'(token=)[^\s"<>]+',r'\1[REDACTED]',value)
    def snapshot():
        adb('shell','uiautomator','dump','/sdcard/emie-b3-ui.xml')
        raw=adb('shell','cat','/sdcard/emie-b3-ui.xml').decode('utf-8','replace')
        tree=ET.fromstring(raw)
        rows=[{k:n.get(k) for k in ('text','content-desc','class','bounds','clickable','password','focused')}
            for n in tree.iter('node') if n.get('text') or n.get('content-desc') or n.get('class')=='android.widget.EditText' or n.get('clickable')=='true']
        safe=json.loads(redact(json.dumps(rows,ensure_ascii=False)))
        support['save'](root/f'logs/ui-{stamp}.json',safe)
        return rows,safe
    detail=[]
    if mode=='snapshot':
        _,safe=snapshot(); print(json.dumps(safe,ensure_ascii=False,indent=2))
    elif mode=='tap':
        rows,_=snapshot()
        matches=[r for r in rows if values[0] in (r['text'],r['content-desc'])]
        if len(matches)>1: matches=[r for r in matches if r['clickable']=='true']
        support['require'](len(matches)==1,'UI label must match exactly one observed node')
        x1,y1,x2,y2=map(int,re.findall(r'\d+',matches[0]['bounds']))
        adb('shell','input','tap',str((x1+x2)//2),str((y1+y2)//2)); detail=values
    elif mode=='tapxy':
        support['require'](len(values)==2 and all(x.isdigit() for x in values),'Two observed coordinates required')
        adb('shell','input','tap',*values); detail=values
    elif mode in ('type','credential'):
        if mode=='credential':
            key,field=values
            support['require'](key in accounts and field in ('email','password','new_password'),'Private synthetic field required')
            if field=='new_password' and field not in accounts[key]:
                accounts[key][field]=secrets.token_urlsafe(18); support['save'](accounts_path,accounts)
            value=accounts[key][field]; detail=[key,field,'value not logged']
        else: value=values[0]; detail=values
        support['require'](re.fullmatch(r'[A-Za-z0-9@._ :/\-]+',value),'Only bounded synthetic ASCII input')
        adb('shell','input','text',value.replace(' ','%s'))
    elif mode=='key':
        support['require'](values[0] in ('KEYCODE_BACK','KEYCODE_ENTER','KEYCODE_TAB','KEYCODE_MOVE_END','KEYCODE_DEL','KEYCODE_HOME'),'Unsupported key')
        adb('shell','input','keyevent',values[0]); detail=values
    elif mode=='swipe':
        support['require'](len(values)==4 and all(x.isdigit() for x in values),'Four observed coordinates required')
        adb('shell','input','swipe',*values,'400'); detail=values
    elif mode=='restart':
        adb('shell','am','force-stop',android['PACKAGE'])
        adb('shell','am','start','-W','-n',android['PACKAGE']+'/.MainActivity')
    elif mode=='reset':
        key,state=values
        support['require'](key in accounts and state in ('cold','warm','logged-in'),'Reset scenario')
        support['schema_identity'](root,cfg,private); support['worker_identity'](root,'backend'); support['packages']()
        import httpx
        with httpx.Client(trust_env=False,timeout=15) as client:
            response=client.post(f"http://127.0.0.1:{cfg['backend_port']}/v1/auth/password/reset/start",json={'email':accounts[key]['email']})
        support['require'](response.status_code==200,'Native reset preparation failed')
        uri=None
        for path in sorted((root/'mail').glob('*.eml'),reverse=True):
            message=BytesParser(policy=policy.default).parsebytes(path.read_bytes())
            if message['To']!=accounts[key]['email']: continue
            body=message.get_body(preferencelist=('plain',))
            if body is None: continue
            for candidate in re.findall(r'https?://[^\s<>"\']+',body.get_content()):
                parsed=urlparse(candidate)
                if parsed.path=='/reset-password' and parsed.hostname=='10.0.2.2' and parsed.port==cfg['backend_port']:
                    proof=parse_qs(parsed.query).get('token',[''])[0]
                    if re.fullmatch(r'[A-Za-z0-9_-]{20,256}',proof): uri=candidate; break
            if uri: break
        support['require'](uri,'Private reset mail missing')
        if state=='cold': adb('shell','am','force-stop',android['PACKAGE'])
        # Captured stdout is discarded: am echoes the URI, so it is never a raw log.
        adb('shell','am','start','-W','-a','android.intent.action.VIEW','-d',uri,'-n',android['PACKAGE']+'/.MainActivity')
        detail=[key,state,'private mail proof delivered; not logged']
    elif mode=='screenshot':
        dest=root/'private'/('screen-'+stamp+'.png')
        dest.write_bytes(adb('exec-out','screencap','-p')); print(str(dest))
    with (root/'logs/native-actions.jsonl').open('a',encoding='utf-8') as f:
        f.write(json.dumps({'utc':stamp,'mode':mode,'detail':detail,'serial':android['SERIAL'],'exit':0})+'\n')


if __name__=='__main__':
    p=argparse.ArgumentParser(); p.add_argument('mode',choices=('snapshot','tap','tapxy','type','credential','key','swipe','restart','reset','screenshot')); p.add_argument('root'); p.add_argument('values',nargs='*')
    a=p.parse_args(); run(a.mode,a.root,a.values)
