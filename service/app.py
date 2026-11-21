"""A small, dependency-free HTTP service for the local kind exercise.

Environment variables are the initial configuration. If Kubernetes projects the
same ConfigMap as files, those files are re-read for each request so a live
ConfigMap patch becomes visible without restarting the pod (after kubelet sync).
"""
import json
import os
import socket
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from pathlib import Path

CONFIG_DIR = Path('/etc/demo-config')


def get_config(key: str, default: str = '') -> str:
    """Read initial environment configuration, with projected-volume refresh."""
    env_value = os.environ.get(key, default)
    file_path = CONFIG_DIR / key
    try:
        return file_path.read_text(encoding='utf-8').strip() if file_path.is_file() else env_value
    except OSError:
        return env_value


class Handler(BaseHTTPRequestHandler):
    def do_GET(self):
        if self.path == '/':
            body = {'app': get_config('APP_NAME', 'demo'),
                    'version': get_config('VERSION', '0.0.0'),
                    'pod': socket.gethostname()}
            self.respond(200, body)
        elif self.path == '/healthz':
            self.respond(200, {'status': 'ok'})
        else:
            self.respond(404, {'error': 'not found'})

    def respond(self, status: int, payload: dict) -> None:
        data = json.dumps(payload, separators=(',', ':')).encode('utf-8')
        self.send_response(status)
        self.send_header('Content-Type', 'application/json')
        self.send_header('Content-Length', str(len(data)))
        self.end_headers()
        self.wfile.write(data)


if __name__ == '__main__':
    port = int(os.environ.get('PORT', '8080'))
    server = ThreadingHTTPServer(('0.0.0.0', port), Handler)
    server.serve_forever()
