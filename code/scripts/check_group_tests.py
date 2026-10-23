#!/usr/bin/env python3
"""Build and run the upstream Buddy and SLUB tests in the test configuration."""
import os
from pathlib import Path
import signal
import subprocess
import time

root = Path(__file__).resolve().parent.parent
path = root / 'logs/group-tests.log'
with path.open('w') as output:
    process = subprocess.Popen(['make', 'test'], cwd=root, stdout=output,
                               stderr=subprocess.STDOUT, start_new_session=True)
    try:
        deadline = time.monotonic() + 20
        while time.monotonic() < deadline:
            if process.poll() is not None:
                break
            text = path.read_text()
            if '[Buddy Test] ALL PASS' in text and '[SLUB Test] ALL PASS' in text:
                break
            if 'kernel panic' in text.lower():
                break
            time.sleep(.1)
    finally:
        if process.poll() is None:
            os.killpg(process.pid, signal.SIGTERM)
            process.wait(timeout=5)
text = path.read_text()
assert 'memory management: bs_pmm_manager' in text, text
assert '[Buddy Test] ALL PASS' in text, text
assert '[SLUB Test] ALL PASS' in text, text
assert 'kernel panic' not in text.lower(), text
print('Group Buddy and SLUB tests: PASS (logs/group-tests.log)')
