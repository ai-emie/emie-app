"""Owned Windows B3 PostgreSQL, SMTP capture and real main:app launcher.

Run with the existing CPython 3.11.9 -I -S -B. No host dotenv or provider
credentials are inherited. This does not execute the POSIX acceptance suite.
"""
from __future__ import annotations
import argparse
import asyncio
import ast
import hashlib
import json
import os
from pathlib import Path
import secrets
import socket
import subprocess
import sys
import time

APP = Path(r'C:\Users\Patze\Emie\app')
BACKEND = APP.parent / 'backend'
DEPENDENCIES = Path(r'C:\Users\Patze\Emie\backend\.venv')
PYTHON = DEPENDENCIES / 'Scripts/python.exe'
SCRIPT = Path(__file__).resolve()
ROOT_PARENT = Path(r'C:\Users\Patze\Emie-LocalDev').resolve()
HEAD = 'd8e4b2a90173'


def require(value, message):
    if not value:
        raise RuntimeError(message)


def save(path, value):
    path.write_text(json.dumps(value, indent=2) + '\n', encoding='utf-8')


def system_environment():
    # Keep Windows loader requirements, not arbitrary inherited service settings.
    result = {k: os.environ[k] for k in ('SystemRoot', 'WINDIR', 'COMSPEC',
              'PATHEXT', 'USERPROFILE', 'LOCALAPPDATA', 'APPDATA', 'TEMP', 'TMP')
              if k in os.environ}
    require('SystemRoot' in result, 'SystemRoot is required')
    result['PATH'] = str(Path(result['SystemRoot']) / 'System32')
    result['PYTHON_DOTENV_DISABLED'] = '1'
    result['PYTHONIOENCODING'] = 'utf-8'
    return result


def command(args, *, env=None, input=None, cwd=None, timeout=30):
    p = subprocess.run([str(x) for x in args], input=input, capture_output=True,
                       env=env or system_environment(), cwd=cwd, timeout=timeout,
                       creationflags=subprocess.CREATE_NO_WINDOW)
    require(p.returncode == 0, 'Command failed: ' + Path(str(args[0])).name +
            ': ' + p.stderr.decode('utf-8', 'replace'))
    return p.stdout


def powershell(code):
    exe = Path(os.environ['SystemRoot']) / 'System32/WindowsPowerShell/v1.0/powershell.exe'
    return command([exe, '-NoProfile', '-NonInteractive', '-Command', code])


def process_info(pid):
    raw = powershell(f'Get-CimInstance Win32_Process -Filter "ProcessId={int(pid)}" | '
                     'Select-Object ProcessId,ParentProcessId,ExecutablePath,CommandLine,CreationDate | ConvertTo-Json -Compress')
    return json.loads(raw) if raw.strip() else None


def listeners(port):
    raw = powershell(f'@(Get-NetTCPConnection -State Listen -LocalPort {int(port)} '
                     '-ErrorAction SilentlyContinue | Select-Object LocalAddress,LocalPort,OwningProcess) | ConvertTo-Json -Compress')
    value = json.loads(raw) if raw.strip() else []
    return value if isinstance(value, list) else [value]


def port_free(port):
    require(not listeners(port), f'Port {port} is occupied; no existing process will be stopped')
    with socket.socket() as s:
        s.setsockopt(socket.SOL_SOCKET, socket.SO_EXCLUSIVEADDRUSE, 1)
        s.bind(('127.0.0.1', port))


def target(root):
    root = Path(root).resolve()
    require(root.parent == ROOT_PARENT and root.name.startswith('b3-'), 'Not an owned B3 directory')
    cfg = json.loads((root / 'target.json').read_text(encoding='utf-8'))
    require(cfg['root'] == str(root) and cfg['profile'] == 'emie-b3-local-v1', 'Target binding mismatch')
    validate_target(root, cfg)
    private = json.loads((root / 'private/secrets.json').read_text(encoding='utf-8'))
    return root, cfg, private


def validate_target(root, cfg):
    require(SCRIPT == APP / 'tool/beta_b3/local_backend.py', 'Use the active repository launcher; no candidate fallback')
    require(cfg.get('backend') == str(BACKEND) and cfg.get('app') == str(APP)
            and cfg.get('python') == str(PYTHON), 'Active repository/tool binding mismatch')
    require((cfg.get('pg_port'), cfg.get('database'), cfg.get('role'), cfg.get('mail_port'))
            == (55439, 'emie_b3', 'b3_app', 8025), 'Normal development data target mismatch; no B4/test target')
    require(type(cfg.get('backend_port')) is int and cfg['backend_port'] in range(8010, 8020),
            'Backend port must be 8010..8019; port 8000 is not a local launcher target')
    require(cfg.get('probe_directory') == str(root/'work/local-probes')
            and cfg.get('probe_log') == str(root/'logs/local-probe.jsonl'), 'Local diagnostic path mismatch')
    require(not cfg.get('allow_response_loss', False), 'Normal start never enables response-loss control')


def packages():
    require(sys.version_info[:3] == (3, 11, 9) and sys.flags.isolated and sys.flags.no_site,
            'Use existing CPython 3.11.9 -I -S -B')
    sys.path.insert(0, str(DEPENDENCIES / 'Lib/site-packages'))
    sys.path.insert(0, str(BACKEND))


def pg_identity(root, cfg):
    pgdata = root / 'pgdata'
    lines = (pgdata / 'postmaster.pid').read_text().splitlines()
    pid = int(lines[0])
    require(Path(lines[1]).resolve() == pgdata.resolve() and int(lines[3]) == cfg['pg_port'], 'PG pidfile binding mismatch')
    info = process_info(pid)
    require(info and Path(info['ExecutablePath']).resolve() == (root / 'tools/pgsql/bin/postgres.exe').resolve(), 'PG executable mismatch')
    cmd = info['CommandLine'].replace('\\', '/').lower()
    require(pgdata.as_posix().lower() in cmd and '-d' in cmd, 'PG command/datadir mismatch')
    sockets = listeners(cfg['pg_port'])
    require(sockets and all(x['LocalAddress'] == '127.0.0.1' and x['OwningProcess'] == pid for x in sockets), 'PG listener ownership mismatch')
    return {'pid': pid, 'process': info, 'listeners': sockets, 'data_directory': str(pgdata)}


def connect(root, cfg, private, bootstrap=False):
    validate_target(root, cfg)
    pg_identity(root, cfg)  # Before every explicit management connection.
    packages_if_needed()
    import psycopg2
    return psycopg2.connect(host='127.0.0.1', port=cfg['pg_port'],
        dbname='postgres' if bootstrap else cfg['database'],
        user='b3_bootstrap' if bootstrap else cfg['role'],
        password=private['bootstrap_password'] if bootstrap else private['db_password'],
        connect_timeout=5, options='-c statement_timeout=15000 -c lock_timeout=3000')


def packages_if_needed():
    if str(DEPENDENCIES / 'Lib/site-packages') not in sys.path:
        packages()


def schema_identity(root, cfg, private, require_schema=True):
    process = pg_identity(root, cfg)
    with connect(root, cfg, private, True) as db:
        with db.cursor() as c:
            c.execute("SELECT current_setting('server_version_num'), current_setting('data_directory'), "
                      "current_setting('listen_addresses'), current_setting('TimeZone'), "
                      "current_setting('fsync'), current_setting('full_page_writes'), "
                      "current_setting('synchronous_commit'), current_setting('password_encryption')")
            values = c.fetchone()
            require(values[0] == '170011' and Path(values[1]).resolve() == (root/'pgdata').resolve(), 'Actual server identity mismatch')
            require(values[2:] == ('127.0.0.1','UTC','on','on','on','scram-sha-256'), 'Server safety settings mismatch')
    with connect(root, cfg, private) as db:
        with db.cursor() as c:
            c.execute('SELECT current_database(), current_user, rolsuper, rolcreatedb, rolcreaterole FROM pg_roles WHERE rolname=current_user')
            role = c.fetchone()
            require(role == (cfg['database'], cfg['role'], False, False, False), 'App role/database identity mismatch')
            if require_schema:
                c.execute('SELECT version_num FROM alembic_version ORDER BY version_num')
                require(c.fetchall() == [(HEAD,)], 'Migration head is not B2')
                c.execute("SELECT tablename FROM pg_tables WHERE schemaname='public' ORDER BY tablename")
                tables = [r[0] for r in c.fetchall()]
                c.execute("SELECT indexname FROM pg_indexes WHERE schemaname='public' AND tablename='projects'")
                indexes = [r[0] for r in c.fetchall()]
                require('ix_projects_owner_created_id' in indexes, 'Missing project index')
                c.execute("SELECT pg_get_constraintdef(oid) FROM pg_constraint WHERE conrelid='projects'::regclass AND contype='f'")
                foreign_keys = [r[0] for r in c.fetchall()]
                require(any('users(id)' in r and 'ON DELETE CASCADE' in r for r in foreign_keys), 'Missing project owner FK')
            else:
                tables, indexes, foreign_keys = [], [], []
    result = {'os_identity':process,'server_version_num':values[0], 'settings':list(values[2:]),
              'app_identity':list(role),'revision':HEAD if require_schema else None,
              'tables':tables,'project_indexes':indexes,'project_foreign_keys':foreign_keys}
    save(root/'logs/db-identity.json', result)
    return result


def pg_start(root, cfg):
    if (root/'pgdata/postmaster.pid').exists():
        pg_identity(root, cfg)
        return
    port_free(cfg['pg_port'])
    # A detached Windows postgres can retain a PIPE handle after pg_ctl exits.
    # A real log file avoids blocking communicate() on that inherited handle.
    with (root/'logs/pg-ctl-start.log').open('ab') as log:
        result = subprocess.run([str(root/'tools/pgsql/bin/pg_ctl.exe'),'start','-D',str(root/'pgdata'),
            '-l',str(root/'logs/postgresql.log'),'-w','-t','30'], stdout=log,stderr=log,
            env=system_environment(),creationflags=subprocess.CREATE_NO_WINDOW,timeout=40)
    require(result.returncode==0,'Owned pg_ctl start failed')
    own = pg_identity(root, cfg)
    save(root/'processes/postgres.json', {'pid':own['pid'], 'creation':own['process']['CreationDate'],
        'data_directory':str(root/'pgdata'), 'started_by_b3':True})


def controlled_environment(root, cfg, private):
    validate_target(root, cfg)
    from urllib.parse import quote
    env = system_environment()
    env.update(ENVIRONMENT='local', DEV_ALLOW_HEADER='false',
        DATABASE_URL=f"postgresql+psycopg2://{cfg['role']}:{quote(private['db_password'])}@127.0.0.1:{cfg['pg_port']}/{cfg['database']}?connect_timeout=5",
        JWT_SECRET=private['jwt_secret'], UPLOAD_DIR=str(root/'uploads/public'),
        PRIVATE_UPLOAD_DIR=str(root/'uploads/private'), ADMIN_EMAILS='',
        APPLE_CONFIRMATION_ENABLED='false', APPLE_ACCOUNT_DELETION_ENABLED='false',
        APPLE_REVOCATION_WORKER_ENABLED='false', SMTP_HOST='127.0.0.1',
        SMTP_PORT=str(cfg['mail_port']), SMTP_TLS='0', SMTP_FROM='emie-local@example.com',
        PUBLIC_BASE_URL=f"http://10.0.2.2:{cfg['backend_port']}",
        FRONTEND_BASE_URL=f"http://10.0.2.2:{cfg['backend_port']}",
        CORS_ORIGINS=f"http://10.0.2.2:{cfg['backend_port']}", LOG_LEVEL='INFO')
    os.environ.clear()
    os.environ.update(env)
    os.chdir(root/'work')
    def audit(event, args):
        if event == 'open' and isinstance(args[0], (str,bytes)):
            name = Path(os.fsdecode(args[0])).name.lower()
            if name.startswith('.env'):
                raise RuntimeError('Existing dotenv files are forbidden in B3')
        if event == 'socket.connect':
            address = args[1]
            if isinstance(address, tuple) and address[0] not in ('127.0.0.1','::1'):
                raise RuntimeError('B3 backend permits loopback connections only')
    sys.addaudithook(audit)


def import_identity(root, main, phase):
    require(Path(main.__file__).resolve() == BACKEND/'main.py', 'Backend imported from an unexpected source')
    paths = {}
    for name, module in list(sys.modules.items()):
        if (name == 'app' or name.startswith('app.')) and getattr(module, '__file__', None):
            path = Path(module.__file__).resolve()
            require(path.is_relative_to(BACKEND), 'App module escaped active backend repository')
            paths[name] = str(path)
    save(root/f'logs/import-{phase}.json', {'main':str(Path(main.__file__).resolve()),
        'main_sha256':hashlib.sha256(Path(main.__file__).read_bytes()).hexdigest(),
        'cwd':os.getcwd(), 'python':sys.executable, 'app_modules':paths,
        'dotenv_disabled':os.environ.get('PYTHON_DOTENV_DISABLED') == '1',
        'header_auth':os.environ.get('DEV_ALLOW_HEADER'), 'apple_worker':os.environ.get('APPLE_REVOCATION_WORKER_ENABLED')})


def migration_graph(root):
    rows=[]
    for p in sorted((BACKEND/'alembic/versions').glob('*.py')):
        tree=ast.parse(p.read_bytes()); values={}
        for n in tree.body:
            if isinstance(n, ast.Assign):
                for t in n.targets:
                    if isinstance(t,ast.Name) and t.id in ('revision','down_revision'):
                        values[t.id]=ast.literal_eval(n.value)
            elif isinstance(n, ast.AnnAssign) and isinstance(n.target,ast.Name) and n.target.id in ('revision','down_revision'):
                values[n.target.id]=ast.literal_eval(n.value)
        if values: rows.append({'path':str(p.relative_to(BACKEND)),**values,'sha256':hashlib.sha256(p.read_bytes()).hexdigest()})
    require(len(rows)==16, 'Expected 16 existing migrations')
    require({x['revision'] for x in rows}-{x['down_revision'] for x in rows}=={HEAD}, 'Unexpected migration head')
    require(next(x for x in rows if x['revision']==HEAD)['down_revision']=='c92f6a10d847', 'Unexpected B2 migration parent')
    save(root/'logs/migration-graph.json',rows)
    return rows


def setup(root):
    root=Path(root).resolve()
    require(root.parent==ROOT_PARENT and root.name.startswith('b3-') and root.is_dir(),'Own pre-created B3 directory required')
    require(not (root/'target.json').exists() and not any((root/'pgdata').iterdir()), 'Setup never overwrites an existing target')
    cfg={'profile':'emie-b3-local-v1','root':str(root),'backend':str(BACKEND),'python':str(PYTHON),
         'pg_port':55439,'backend_port':8000,'mail_port':8025,'database':'emie_b3','role':'b3_app'}
    for key in ('pg_port','backend_port','mail_port'): port_free(cfg[key])
    private={'bootstrap_password':secrets.token_urlsafe(32),'db_password':secrets.token_urlsafe(32),'jwt_secret':secrets.token_urlsafe(64)}
    save(root/'private/secrets.json',private); save(root/'target.json',cfg)
    pw=root/'private/bootstrap-password.txt'; pw.write_text(private['bootstrap_password'],encoding='ascii')
    out=command([root/'tools/pgsql/bin/initdb.exe','-D',root/'pgdata','--username=b3_bootstrap',
                 '--pwfile='+str(pw),'--auth-host=scram-sha-256','--auth-local=scram-sha-256',
                 '--encoding=UTF8','--locale=C','--data-checksums'])
    (root/'logs/initdb.log').write_bytes(out)
    with (root/'pgdata/postgresql.conf').open('a',encoding='utf-8') as f:
        f.write("\n# Owned Emie B3 Windows development target\nlisten_addresses='127.0.0.1'\nport=55439\ntimezone='UTC'\nlog_timezone='UTC'\npassword_encryption='scram-sha-256'\nfsync=on\nfull_page_writes=on\nsynchronous_commit=on\nstatement_timeout='15s'\nlock_timeout='3s'\nidle_in_transaction_session_timeout='15s'\nlog_statement='none'\nlog_min_error_statement='panic'\n")
    (root/'pgdata/pg_hba.conf').write_text('host all all 127.0.0.1/32 scram-sha-256\n',encoding='ascii')
    pg_start(root,cfg)
    provision(root,cfg,private)


def provision(root,cfg,private):
    db=connect(root,cfg,private,True)
    try:
        db.autocommit=True
        from psycopg2 import sql
        with db.cursor() as c:
            c.execute(sql.SQL('CREATE ROLE {} LOGIN NOSUPERUSER NOCREATEDB NOCREATEROLE NOREPLICATION PASSWORD %s').format(sql.Identifier(cfg['role'])),(private['db_password'],))
            c.execute(sql.SQL('CREATE DATABASE {} OWNER {}').format(sql.Identifier(cfg['database']),sql.Identifier(cfg['role'])))
    finally:
        db.close()
    schema_identity(root,cfg,private,False)
    print('Owned PG17.11 cluster initialized with SCRAM and a non-superuser app role.')


def migrate(root,cfg,private):
    schema_identity(root,cfg,private,False)
    graph=migration_graph(root)
    controlled_environment(root,cfg,private)
    from alembic import command as alembic_command
    from alembic.config import Config
    conf=Config(str(BACKEND/'alembic.ini')); conf.set_main_option('script_location',str(BACKEND/'alembic'))
    alembic_command.upgrade(conf,'head')
    require(graph==migration_graph(root),'Migration source bytes changed')
    schema_identity(root,cfg,private)
    print('All 16 original migrations applied; B2 head and physical project FK/index verified.')


def lifespan(root,cfg,private):
    schema_identity(root,cfg,private)
    controlled_environment(root,cfg,private)
    import main
    import_identity(root, main, 'lifespan')
    async def exercise():
        async with main.lifespan(main.app):
            save(root/'logs/lifespan.json',{'entry':'main.lifespan(main.app)','context_memory_guards':'real','mocks':False,'revision':HEAD,'success':True})
    asyncio.run(exercise())
    print('Real main.lifespan(main.app) completed successfully.')


def worker_identity(root,mode):
    row=json.loads((root/f'processes/{mode}.json').read_text())
    info=process_info(row['pid'])
    require(info and Path(info['ExecutablePath']).resolve()==Path(row['executable']).resolve(), 'Worker executable mismatch')
    require(info['CreationDate']==row['creation'] and str(SCRIPT) in info['CommandLine'] and str(root) in info['CommandLine'] and f' {mode} ' in info['CommandLine'], 'Worker process binding mismatch')
    return row


def spawn_worker(root,mode,port):
    record=root/f'processes/{mode}.json'
    if record.exists():
        row=worker_identity(root,mode)
        sockets=listeners(port)
        require(sockets and all(x['OwningProcess']==row['pid'] and x['LocalAddress']=='127.0.0.1' for x in sockets),'Worker listener mismatch')
        return
    port_free(port)
    request=root/f'processes/{mode}.stop'
    if request.exists(): request.unlink()  # Only the exact prior owned stop request.
    out=(root/f'logs/{mode}.log').open('ab')
    p=subprocess.Popen([str(PYTHON),'-I','-S','-B','-X','utf8',str(SCRIPT),mode,str(root)],
                       env=system_environment(),cwd=root/'work',stdout=out,stderr=out,
                       creationflags=subprocess.CREATE_NO_WINDOW)
    out.close()
    for _ in range(100):
        info=process_info(p.pid)
        if info and listeners(port): break
        require(p.poll() is None,mode+' exited before listening; inspect its private local log')
        time.sleep(.2)
    require(info and listeners(port),mode+' did not listen')
    bind_listener(root,mode,port,p.pid)
    worker_identity(root,mode)


def bind_listener(root,mode,port,launcher_pid):
    sockets=listeners(port)
    require(sockets and all(x['LocalAddress']=='127.0.0.1' for x in sockets), 'Worker bind is not loopback')
    pids={x['OwningProcess'] for x in sockets}
    require(len(pids)==1, 'Ambiguous worker listener')
    info=process_info(pids.pop())
    require(info and (info['ProcessId']==launcher_pid or info['ParentProcessId']==launcher_pid), 'Worker is not the launched child')
    require(str(SCRIPT) in info['CommandLine'] and str(root) in info['CommandLine'] and f' {mode} ' in info['CommandLine'], 'Worker command mismatch')
    require(Path(info['ExecutablePath']).resolve() in (PYTHON.resolve(), Path(sys._base_executable).resolve()), 'Worker interpreter mismatch')
    save(root/f'processes/{mode}.json',{'pid':info['ProcessId'],'launcher_pid':launcher_pid,'executable':info['ExecutablePath'],'creation':info['CreationDate'],'port':port})


def smtp_worker(root,cfg):
    import smtpd,asyncore
    class Capture(smtpd.SMTPServer):
        def process_message(self,peer,mailfrom,rcpttos,data,**kwargs):
            if not all(x.endswith('@example.com') for x in rcpttos): return '550 Synthetic example.com recipients only'
            (root/'mail'/(str(time.time_ns())+'.eml')).write_bytes(data)
            return None
    capture=Capture(('127.0.0.1',cfg['mail_port']),None,decode_data=False)
    try:
        while not (root/'processes/smtp.stop').exists(): asyncore.loop(timeout=.2,count=1)
    finally: capture.close()


def backend_worker(root,cfg,private):
    schema_identity(root,cfg,private)
    controlled_environment(root,cfg,private)
    import uvicorn,main
    import_identity(root, main, 'server')
    import runpy
    LocalProbeMiddleware = runpy.run_path(str(SCRIPT.with_name('local_probe.py')))['LocalProbeMiddleware']
    local_app = LocalProbeMiddleware(main.app, cfg)
    server=uvicorn.Server(uvicorn.Config(local_app,host='127.0.0.1',port=cfg['backend_port'],
        access_log=False,lifespan='on',reload=False,workers=1,proxy_headers=False))
    async def serve():
        async def stop_request():
            while not (root/'processes/backend.stop').exists(): await asyncio.sleep(.3)
            server.should_exit=True
        task=asyncio.create_task(stop_request())
        try: await server.serve()
        finally: task.cancel()
    asyncio.run(serve())


def start(root,cfg,private):
    validate_target(root, cfg)
    if not (root/'processes/backend.json').exists():
        port_free(cfg['backend_port'])  # Before starting PG or mail; never probe HTTP on occupied ports.
    pg_start(root,cfg)
    schema_identity(root,cfg,private)
    # Separate, fresh process proves the real lifespan before serving HTTP.
    out=command([PYTHON,'-I','-S','-B','-X','utf8',SCRIPT,'lifespan',root], timeout=90)
    (root/'logs/lifespan-command.log').write_bytes(out)
    spawn_worker(root,'smtp',cfg['mail_port'])
    spawn_worker(root,'backend',cfg['backend_port'])
    print('Owned SMTP capture and real Uvicorn main:app are listening on loopback.')


def stop(root,cfg):
    stopped=[]
    for mode in ('backend','smtp'):
        record=root/f'processes/{mode}.json'
        if not record.exists(): continue
        row=worker_identity(root,mode)
        (root/f'processes/{mode}.stop').write_text('graceful stop',encoding='ascii')
        for _ in range(60):
            if process_info(row['pid']) is None: break
            time.sleep(.25)
        require(process_info(row['pid']) is None,mode+' did not stop; no forced termination')
        require(not listeners(row['port']),mode+' listener still occupied')
        record.unlink(); stopped.append(mode)
    pg_record = root/'processes/postgres.json'
    if pg_record.exists():
        row=json.loads(pg_record.read_text())
        current=pg_identity(root,cfg)
        require(row.get('started_by_b3') and row['pid']==current['pid']
                and row['creation']==current['process']['CreationDate']
                and row['data_directory']==str(root/'pgdata'), 'PG start ownership mismatch; no stop')
        command([root/'tools/pgsql/bin/pg_ctl.exe','stop','-D',root/'pgdata','-m','fast','-w','-t','30'])
        pg_record.unlink()
        stopped.append('postgres')
    released=[cfg[x] for x in ('pg_port','backend_port','mail_port') if not listeners(cfg[x])]
    for port in released: port_free(port)
    require(not listeners(cfg['backend_port']) and not listeners(cfg['mail_port']), 'Owned worker listener remains')
    save(root/'logs/shutdown.json',{'graceful_stopped':stopped,'ports_released':released,'data_and_tools_preserved':True})
    print('Owned processes stopped; listeners released; data and tools retained.')


def main():
    parser=argparse.ArgumentParser(); parser.add_argument('mode',choices=('check','lifespan','start','stop','smtp','backend')); parser.add_argument('root')
    args=parser.parse_args(); packages()
    root,cfg,private=target(args.root)
    if args.mode=='check': schema_identity(root,cfg,private); print('Owned process, database, role and B2 schema verified.')
    elif args.mode=='lifespan': lifespan(root,cfg,private)
    elif args.mode=='start': start(root,cfg,private)
    elif args.mode=='stop': stop(root,cfg)
    elif args.mode=='smtp': smtp_worker(root,cfg)
    elif args.mode=='backend': backend_worker(root,cfg,private)


if __name__=='__main__': main()
