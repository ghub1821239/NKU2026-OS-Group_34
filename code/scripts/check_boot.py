#!/usr/bin/env python3
"""Boot the kernel at several RAM sizes and save the actual console output."""
import argparse
import os
from pathlib import Path
import signal
import subprocess

parser = argparse.ArgumentParser()
parser.add_argument('--qemu', default='qemu-system-riscv64')
parser.add_argument('--label', default='qemu6')
parser.add_argument('--memory', nargs='+', type=int, default=[64, 128, 256])
args = parser.parse_args()
root = Path(__file__).resolve().parent.parent
for size in args.memory:
    path = root / 'logs' / ('boot-%s-%dM.log' % (args.label, size))
    with path.open('w') as output:
        process = subprocess.Popen([
            args.qemu, '-machine', 'virt', '-m', str(size), '-nographic',
            '-bios', 'default', '-kernel', 'bin/ucore.img',
        ], cwd=root, stdout=output, stderr=subprocess.STDOUT,
            start_new_session=True)
        try:
            process.wait(timeout=3)
        except subprocess.TimeoutExpired:
            os.killpg(process.pid, signal.SIGTERM)
            process.wait(timeout=3)
    text = path.read_text()
    assert 'check_alloc_page() succeeded!' in text, text
    assert 'satp physical address:' in text, text
    assert ('(%d MB)' % size) in text, text
    assert 'panic' not in text.lower(), text
    print('%s %d MiB: PASS (%s)' % (args.label, size, path.name), flush=True)
