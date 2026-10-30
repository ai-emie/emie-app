"""Run the default-client regression against a synthetic loopback HTTP server.

Requires existing Flutter and Chrome; installs nothing. From any directory:
python3 /path/to/repo/test/api/run_platform_transport.py \
    --flutter /path/to/flutter/bin/flutter --chrome /path/to/chrome
Use --platform vm to check the native transport with the same fixture.
"""
import argparse
import http.server
import json
import os
from pathlib import Path
import signal
import subprocess
import threading


class Handler(http.server.BaseHTTPRequestHandler):
    def log_message(self, *_):
        pass

    def do_OPTIONS(self):
        self.send_response(204)
        self.send_header('Access-Control-Allow-Origin', '*')
        self.send_header('Access-Control-Allow-Headers', '*')
        self.send_header('Access-Control-Allow-Methods', 'GET,OPTIONS')
        self.end_headers()

    def do_GET(self):
        if self.path != '/health':
            self.send_error(404)
            return
        body = json.dumps({'m10': 'synthetic_transport_ok'}).encode()
        self.send_response(200)
        self.send_header('Access-Control-Allow-Origin', '*')
        self.send_header('Content-Type', 'application/json')
        self.send_header('Content-Length', str(len(body)))
        self.end_headers()
        self.wfile.write(body)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--flutter', required=True, type=Path)
    parser.add_argument('--chrome', required=True, type=Path)
    parser.add_argument('--platform', choices=('chrome', 'vm'), default='chrome')
    args = parser.parse_args()
    flutter = args.flutter.resolve(strict=True)
    chrome = args.chrome.resolve(strict=True)
    root = Path(__file__).resolve().parents[2]
    env = dict(PATH='/usr/bin:/bin:/usr/sbin:/sbin', HOME=str(Path.home()),
               LANG='en_US.UTF-8', LC_ALL='en_US.UTF-8', CI='true',
               PUB_CACHE=str(Path.home()/'.pub-cache'),
               FLUTTER_SUPPRESS_ANALYTICS='true', DART_SUPPRESS_ANALYTICS='true',
               CHROME_EXECUTABLE=str(chrome))
    server = http.server.ThreadingHTTPServer(('127.0.0.1', 0), Handler)
    worker = threading.Thread(target=server.serve_forever, daemon=True)
    worker.start()
    child = None
    try:
        command = [str(flutter), '--no-version-check', 'test', '--no-pub',
                   '--reporter', 'expanded', '--platform',
                   'tester' if args.platform == 'vm' else 'chrome',
                   f'--dart-define=M10_TRANSPORT_TEST_ORIGIN=http://127.0.0.1:{server.server_port}',
                   'test/api/platform_transport_test.dart']
        child = subprocess.Popen(command, cwd=root, env=env, start_new_session=True)
        return child.wait(timeout=150)
    finally:
        if child is not None and child.poll() is None:
            os.killpg(child.pid, signal.SIGTERM)
            try:
                child.wait(timeout=10)
            except subprocess.TimeoutExpired:
                os.killpg(child.pid, signal.SIGKILL)
                child.wait(timeout=5)
        server.shutdown()
        server.server_close()
        worker.join(timeout=5)


if __name__ == '__main__':
    raise SystemExit(main())
