#!/usr/bin/env python3
"""Daily Kodi thumbnail-cache cleanup for a low-end HTPC.

Removes cached remote (plugin) thumbnails not used for KEEP_DAYS via Kodi's own
JSON-RPC Textures.RemoveTexture, so the DB row and the file are removed together while
Kodi runs. If the Thumbnails folder is still larger than MAX_THUMBS_MB, the oldest
remote thumbnails are removed first. Local library artwork is left untouched. Skips the
run while something is playing, so playback never stutters.

Reads Kodi JSON-RPC credentials from /etc/htpc-remote.conf:
    KODI_RPC_URL, KODI_RPC_USER, KODI_RPC_PASSWORD
Edit REMOTE_HOSTS for the thumbnail sources you want pruned (default: YouTube).
"""

import base64
import json
import os
import subprocess
import syslog
import time
import urllib.request

KEEP_DAYS = 3
MAX_THUMBS_MB = 500
REMOTE_HOSTS = ('ytimg.com', 'ggpht.com', 'googleusercontent.com')

cfg = {}
try:
    for line in open('/etc/htpc-remote.conf'):
        line = line.strip()
        if line and not line.startswith('#') and '=' in line:
            k, v = line.split('=', 1)
            cfg[k.strip()] = v.strip().strip('"').strip("'")
except FileNotFoundError:
    pass

URL = cfg.get('KODI_RPC_URL', 'http://127.0.0.1:8080/jsonrpc')
USER = cfg.get('KODI_RPC_USER', 'kodi')
PW = cfg.get('KODI_RPC_PASSWORD', '')
THUMBS = os.path.expanduser(cfg.get('THUMBNAILS_DIR', '~/.kodi/userdata/Thumbnails'))
AUTH = 'Basic ' + base64.b64encode(f'{USER}:{PW}'.encode()).decode()


def log(msg):
    syslog.syslog(syslog.LOG_INFO, msg)
    print(msg)


def rpc(method, params=None):
    body = {'jsonrpc': '2.0', 'id': 1, 'method': method}
    if params is not None:
        body['params'] = params
    req = urllib.request.Request(
        URL, data=json.dumps(body).encode(), headers={'Content-Type': 'application/json', 'Authorization': AUTH}
    )
    opener = urllib.request.build_opener(urllib.request.ProxyHandler({}))
    with opener.open(req, timeout=60) as r:
        return json.load(r).get('result')


def dir_mb(path):
    out = subprocess.run(['du', '-sm', path], capture_output=True, text=True).stdout.split()
    return int(out[0]) if out else 0


def last_used(tex):
    best = 0.0
    for s in tex.get('sizes') or []:
        t = s.get('lastused')
        if t:
            try:
                best = max(best, time.mktime(time.strptime(t, '%Y-%m-%d %H:%M:%S')))
            except ValueError:
                pass
    return best


def main():
    syslog.openlog('kodi-cache-clean')
    try:
        if rpc('Player.GetActivePlayers'):
            log('skip: playback active')
            return
        textures = rpc('Textures.GetTextures', {'properties': ['url', 'sizes']})['textures']
    except Exception as ex:
        log(f'skip: Kodi not reachable ({ex})')
        return
    before = dir_mb(THUMBS)
    remote = sorted((t for t in textures if any(k in t['url'] for k in REMOTE_HOSTS)), key=last_used)
    cutoff = time.time() - KEEP_DAYS * 86400
    removed = 0
    for t in remote:
        if last_used(t) >= cutoff:
            break
        rpc('Textures.RemoveTexture', {'textureid': t['textureid']})
        removed += 1
    rest = remote[removed:]
    while rest and dir_mb(THUMBS) > MAX_THUMBS_MB:
        for t in rest[:200]:
            rpc('Textures.RemoveTexture', {'textureid': t['textureid']})
            removed += 1
        rest = rest[200:]
    log(f'textures={len(textures)} remote={len(remote)} removed={removed} thumbs_mb {before}->{dir_mb(THUMBS)}')


if __name__ == '__main__':
    main()
