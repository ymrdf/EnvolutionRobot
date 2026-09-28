#!/usr/bin/env python3
"""Live RGB/HP synchronization regression check (requires a rendering display).

Run in the envolution environment with --godot /path/to/godot4.
The robot turns in place; both eyes must change on each step after warmup.
Client delays must not advance physics while the server is waiting for an action.
"""
import argparse
import json
from pathlib import Path
import subprocess
import time

import numpy as np
from godot_rl.core.godot_env import GodotEnv

p = argparse.ArgumentParser(description=__doc__)
p.add_argument('--godot', required=True)
p.add_argument('--steps', type=int, default=96)
p.add_argument('--port', type=int, default=11018)
p.add_argument('--output', type=Path, required=True)
p.add_argument('--report-only', action='store_true')
a = p.parse_args()
if a.steps < 16:
    p.error('--steps must be at least 16 (including 8 warmup steps)')
root = Path(__file__).resolve().parents[1]
a.output.parent.mkdir(parents=True, exist_ok=True)

def eyes(obs):
    result = []
    for key in ('left_eye', 'right_eye'):
        val = obs[key]
        while isinstance(val, (list, tuple)) and len(val) == 1:
            val = val[0]
        arr = np.frombuffer(bytes.fromhex(val), dtype=np.uint8)
        assert arr.size == 300 * 320 * 3, (key, arr.size)
        result.append(arr)
    return result

records = []
env = None
with a.output.with_suffix('.godot.log').open('w') as log:
    game = subprocess.Popen([a.godot, '--path', str(root), f'--port={a.port}'], stdout=log, stderr=subprocess.STDOUT)
    try:
        env = GodotEnv(port=a.port, show_window=True)
        obs = env.reset()[0][0]
        prev = eyes(obs)
        hp = float(obs['hp'][0])
        # order_ij follows the sorted action_spaces keys, not GDScript insertion order.
        values = dict(accelerate_forward=1, accelerate_sideways=1, shoot=0, turn=2)
        action = [values[key] for key in env.action_spaces[0]]
        for i in range(a.steps):
            delay = 0.15 if i % 16 == 0 else 0.07
            time.sleep(delay)
            obs_list, _, terminated, truncated, _ = env.step([action], order_ij=True)
            obs = obs_list[0]
            assert not terminated[0] and not truncated[0], 'Unexpected death during rotation check'
            current = eyes(obs)
            next_hp = float(obs['hp'][0])
            records.append(dict(step=i+1, changed=[bool(np.any(x != y)) for x,y in zip(prev,current)],
                                hp_loss=hp-next_hp, delay=delay))
            hp, prev = next_hp, current
            if (i+1) % 32 == 0:
                obs = env.reset()[0][0]
                prev = eyes(obs)
                hp = float(obs['hp'][0])
        tail = records[8:]
        result = dict(steps=a.steps, checked_after_warmup=len(tail),
                      changed_counts=np.sum([x['changed'] for x in tail],axis=0).tolist(),
                      expected_hp_loss=1/180/20,
                      max_hp_loss_error=max(abs(x['hp_loss']-1/180/20) for x in tail), records=records)
        a.output.write_text(json.dumps(result, indent=2))
        print(json.dumps({k:v for k,v in result.items() if k!='records'}, indent=2))
        if not a.report_only:
            assert all(all(x['changed']) for x in tail), 'Stale RGB frames while turning'
            assert result['max_hp_loss_error'] < 2e-6, 'Client delay changed the number of physics steps'
    finally:
        if env is not None:
            env.close()
        try:
            game.wait(timeout=10)
        except subprocess.TimeoutExpired:
            game.terminate()
            game.wait(timeout=10)
