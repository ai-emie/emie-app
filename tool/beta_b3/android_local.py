"""Pinned local Android build/start/stop; never selects an arbitrary adb device."""
import argparse
import hashlib
import json
import os
import re
from pathlib import Path
import runpy
import shutil
import subprocess
import time

support = runpy.run_path(str(Path(__file__).with_name('local_backend.py')))
APP = support['APP']
support['require'](Path(__file__).resolve() == APP/'tool/beta_b3/android_local.py',
                   'Use the active app repository; no candidate build fallback')
FLUTTER = Path(r'C:\Users\Patze\flutter')
SDK = Path(r'C:\Users\Patze\AppData\Local\Android\sdk')
SERIAL = 'emulator-5556'
AVD = 'Emie_B3_Pixel_9_API_36_4c04767e'
PACKAGE = 'ai.emie.app'


def environment(root):
    env = support['system_environment']()
    # Flutter reads APPDATA/.flutter_settings on Windows. Scope JDK selection
    # to this invocation, without changing the user's Flutter configuration.
    config=root/'work/flutter-config'
    config.mkdir(exist_ok=True)
    support['save'](config/'.flutter_settings',{'jdk-dir':str(root/'tools/jdk-21.0.12.1+1')})
    env['PATH'] += r';C:\Program Files\Git\cmd;'+str(Path(env['SystemRoot'])/'System32/WindowsPowerShell/v1.0')
    env.update(JAVA_HOME=str(root/'tools/jdk-21.0.12.1+1'), ANDROID_HOME=str(SDK),
        ANDROID_SDK_ROOT=str(SDK), ANDROID_AVD_HOME=str(root/'avd'),
        APPDATA=str(config), CI='true', FLUTTER_SUPPRESS_ANALYTICS='true',
        GRADLE_OPTS='-Dorg.gradle.jvmargs=-Xmx3G -Dorg.gradle.workers.max=2 -Dorg.gradle.daemon=false',
        JAVA_TOOL_OPTIONS='-Djavax.net.ssl.trustStoreType=Windows-ROOT -Djavax.net.ssl.trustStore=NONE')
    return env


def execute(args, root, *, cwd=None, timeout=60):
    result = subprocess.run([str(x) for x in args], env=environment(root), cwd=cwd,
        capture_output=True, timeout=timeout, creationflags=subprocess.CREATE_NO_WINDOW)
    support['require'](result.returncode == 0, 'Local Android command failed: '+Path(str(args[0])).name+
        ': '+result.stderr.decode('utf-8','replace'))
    return result.stdout


def adb(root, *args):
    return execute([SDK/'platform-tools/adb.exe','-s',SERIAL,*args],root)


def launcher_identity(root):
    record=json.loads((root/'processes/emulator.json').read_text())
    support['require'](record['avd']==AVD and record['serial']==SERIAL and record['started_by_b3'], 'AVD record mismatch')
    info=support['process_info'](record['launcher_pid'])
    support['require'](info and Path(info['ExecutablePath'])==SDK/'emulator/emulator.exe'
        and info['CreationDate']==record['creation'] and AVD in info['CommandLine']
        and '-port 5556' in info['CommandLine'], 'Owned emulator process mismatch')
    return info


def identity(root):
    info=launcher_identity(root)
    support['require'](adb(root,'emu','avd','name').decode().splitlines()[0]==AVD, 'Selected adb target mismatch')
    support['require'](adb(root,'shell','getprop','ro.build.version.sdk').strip()==b'36', 'API36 required')
    support['require'](adb(root,'shell','getprop','ro.product.cpu.abi').strip()==b'x86_64', 'x86_64 required')
    return info


def wait_for_boot(root):
    # Cold boot may outlast a single adb wait on this preserved API36 AVD.
    # Keep every subprocess short, retain the owned emulator on timeout.
    deadline=time.monotonic()+300
    checks=0
    while time.monotonic()<deadline:
        if checks % 5 == 0: launcher_identity(root)
        try:
            result=subprocess.run([str(SDK/'platform-tools/adb.exe'),'-s',SERIAL,
                'shell','getprop','sys.boot_completed'],env=environment(root),
                capture_output=True,timeout=10,creationflags=subprocess.CREATE_NO_WINDOW)
            if result.returncode==0 and result.stdout.strip()==b'1':
                identity(root)
                return
        except subprocess.TimeoutExpired:
            pass
        checks+=1
        time.sleep(2)
    raise RuntimeError('Owned emulator boot exceeded 300 seconds; it is retained with its data. Inspect its state before retrying start.')


def source_manifest():
    files=[]
    for folder in ('lib','assets','android/app/src','android/gradle'):
        files += [p for p in (APP/folder).rglob('*') if p.is_file() and p.name!='gradle-wrapper.jar']
    files += [APP/p for p in ('pubspec.yaml','pubspec.lock','android/app/build.gradle.kts',
        'android/build.gradle.kts','android/settings.gradle.kts','android/gradle.properties')]
    files += list((APP/'android/app').glob('*.gradle.kts'))
    return {p.relative_to(APP).as_posix():hashlib.sha256(p.read_bytes()).hexdigest() for p in sorted(files)}


def build(root):
    support['require'](json.loads((FLUTTER/'bin/cache/flutter.version.json').read_text())['flutterVersion']=='3.38.6', 'Flutter pin mismatch')
    for part in ('gradlew','gradlew.bat','gradle/wrapper/gradle-wrapper.jar'):
        dest=APP/'android'/part
        if not dest.exists(): shutil.copyfile(FLUTTER/'bin/cache/artifacts/gradle_wrapper'/part,dest)
    lock_before=(APP/'pubspec.lock').read_bytes()
    pub=execute([FLUTTER/'bin/flutter.bat','pub','get','--offline','--enforce-lockfile'],root,cwd=APP,timeout=180)
    support['require']((APP/'pubspec.lock').read_bytes()==lock_before,'Lockfile changed; stop')
    (root/'logs/pub-get-enforced.log').write_bytes(pub)
    before=source_manifest()
    args=[str(FLUTTER/'bin/flutter.bat'),'build','apk','--debug','--no-pub',
        '--target-platform','android-x64','--dart-define=EMIE_LOCAL=true','--dart-define=EMIE_ENV=dev', '--dart-define=EMIE_LOCAL_PORT='+str(support['target'](root)[1]['backend_port'])]
    stamp=str(time.time_ns())
    with (root/f'logs/android-build-{stamp}.log').open('wb') as log:
        process=subprocess.run(args,env=environment(root),cwd=APP,stdout=log,stderr=log,
            creationflags=subprocess.CREATE_NO_WINDOW,timeout=600)
    support['save'](root/f'logs/android-build-{stamp}.json',{'command':args,'cwd':str(APP),
        'active_app':str(APP),'exit':process.returncode,'sources':before,
        'flutter':'3.38.6','dart':'3.10.7','lockfile_unchanged':(APP/'pubspec.lock').read_bytes()==lock_before})
    support['require'](process.returncode==0,'Build failed; inspect local build log')
    support['require'](source_manifest()==before,'Sources changed during build; rebuild required')
    package(root,before)


def package(root,sources=None):
    apk=APP/'build/app/outputs/apk/debug/app-debug.apk'
    support['require'](apk.exists(),'Expected debug APK missing')
    dest=root/'artifacts'/('emie-b3-local-debug-'+str(time.time_ns())+'.apk')
    shutil.copyfile(apk,dest)
    details=execute([SDK/'build-tools/36.0.0/aapt.exe','dump','badging',dest],root).decode('utf-8','replace')
    support['require']("package: name='ai.emie.app'" in details and 'application-debuggable' in details,'APK identity/debug mismatch')
    signature=execute([SDK/'build-tools/36.0.0/apksigner.bat','verify','--print-certs',dest],root).decode('utf-8','replace')
    support['save'](root/'artifacts/apk.json',{'path':str(dest),'sha256':hashlib.sha256(dest.read_bytes()).hexdigest(),
        'bytes':dest.stat().st_size,'package':PACKAGE,'mode':'debug EMIE_LOCAL=true android-x64',
        'signature':signature,'backend_port':support['target'](root)[1]['backend_port'],
        'active_app':str(APP),'build_cwd':str(APP),'sources':sources or source_manifest()})
    (root/'logs/apk-badging.txt').write_text(details,encoding='utf-8')


def current_apk(root):
    meta=json.loads((root/'artifacts/apk.json').read_text())
    support['require'](meta.get('active_app')==str(APP) and meta.get('build_cwd')==str(APP),
        'APK was not built from the active repository: run build first')
    support['require'](meta['backend_port']==support['target'](root)[1]['backend_port'],'APK port differs: rebuild before launch')
    support['require'](meta['sources']==source_manifest(),'APK sources differ: run build before launch')
    apk=Path(meta['path']).resolve()
    support['require'](apk.parent==(root/'artifacts').resolve(),'APK escaped own artifact directory')
    support['require'](hashlib.sha256(apk.read_bytes()).hexdigest()==meta['sha256'],'APK hash mismatch')
    return apk,meta


def installed_apk_hash(root):
    paths=adb(root,'shell','pm','path',PACKAGE).decode().strip().splitlines()
    if not paths: return None
    support['require'](len(paths)==1 and paths[0].startswith('package:/data/app/')
        and paths[0].endswith('/base.apk'), 'Unexpected installed package layout; inspect before updating')
    path=paths[0].removeprefix('package:')
    support['require'](re.fullmatch(r'/data/app/[A-Za-z0-9_./=+~-]+/base\.apk',path),'Unexpected package path')
    value=adb(root,'shell','sha256sum',path).decode().split()[0]
    support['require'](re.fullmatch('[0-9a-f]{64}',value),'Installed APK hash unavailable')
    return value


def start(root):
    apk,meta=current_apk(root)
    record=root/'processes/emulator.json'
    if record.exists():
        launcher_identity(root)
    else:
        for port in (5556,5557): support['port_free'](port)
        out=(root/'logs/emulator.log').open('ab')
        process=subprocess.Popen([str(SDK/'emulator/emulator.exe'),'-avd',AVD,'-port','5556',
            '-no-snapshot-load','-no-snapshot-save','-no-audio','-no-boot-anim'],
            env=environment(root),stdout=out,stderr=out,creationflags=subprocess.CREATE_NO_WINDOW)
        out.close()
        info=support['process_info'](process.pid)
        support['require'](info,'Emulator exited during launch')
        support['save'](record,{'launcher_pid':process.pid,'avd':AVD,'serial':SERIAL,'started_by_b3':True,
            'creation':info['CreationDate'],'exe':str(SDK/'emulator/emulator.exe'),'avd_home':str(root/'avd')})
    wait_for_boot(root)
    before_hash=installed_apk_hash(root)
    if before_hash != meta['sha256']:
        # A timeout is not success. A later start first checks the actual APK,
        # so an update that already completed is never blindly repeated.
        execute([SDK/'platform-tools/adb.exe','-s',SERIAL,'install','-r',apk],root,timeout=180)
    support['require'](installed_apk_hash(root)==meta['sha256'],'Installed APK does not match the current build')
    support['save'](root/'logs/apk-install.json',{'before_sha256':before_hash,'after_sha256':meta['sha256'],
        'updated':before_hash!=meta['sha256'],'preserve_data':True,'serial':SERIAL})
    result=adb(root,'shell','am','start','-W','-n',PACKAGE+'/.MainActivity')
    (root/'logs/app-launch.txt').write_bytes(result)
    support['save'](root/'logs/emulator-identity.json',{'process':identity(root),'serial':SERIAL,'avd':AVD,
        'api':36,'abi':'x86_64','apk_sha256':meta['sha256'],'app_pid':adb(root,'shell','pidof',PACKAGE).decode().strip()})
    print('Owned API36 Pixel9: debug APK installed and activity started.')


def stop(root):
    record=root/'processes/emulator.json'
    if record.exists():
        row=identity(root)
        adb(root,'emu','kill')
        for _ in range(40):
            if support['process_info'](row['ProcessId']) is None: break
            time.sleep(.5)
        support['require'](support['process_info'](row['ProcessId']) is None,'Owned emulator did not stop')
        support['require'](all(not support['listeners'](p) for p in (5556,5557)), 'Emulator port remains occupied')
        record.unlink()
        support['save'](root/'logs/emulator-shutdown.json',{'serial':SERIAL,'avd':AVD,'graceful':True,'data_preserved':True})


def flutter(root):
    start(root)
    # A normal Flutter source build/run preserves Flutter's existing hot reload.
    result=subprocess.run([str(FLUTTER/'bin/flutter.bat'),'run','--debug','--no-pub','-d',SERIAL,
        '--dart-define=EMIE_LOCAL=true','--dart-define=EMIE_ENV=dev', '--dart-define=EMIE_LOCAL_PORT='+str(support['target'](root)[1]['backend_port'])],env=environment(root),cwd=APP)
    raise SystemExit(result.returncode)


if __name__=='__main__':
    parser=argparse.ArgumentParser(); parser.add_argument('mode',choices=('build','start','stop','check','flutter')); parser.add_argument('root')
    args=parser.parse_args(); root,_,_=support['target'](args.root)
    if args.mode=='check': print(json.dumps(identity(root)))
    else: globals()[args.mode](root)
