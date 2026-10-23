#!/usr/bin/env python3
"""Check low-PC translation at paging activation by changing debug RAM only."""
import os
from pathlib import Path
import re
import signal
import socket
import subprocess
import time

root = Path(__file__).resolve().parent.parent
port = 2235
symbols = subprocess.check_output([
    'riscv64-unknown-elf-nm', '-n', 'bin/kernel'], cwd=root, text=True)
pt_va = int(re.search(r'^([0-9a-f]+) \w boot_page_table_sv39$',
                      symbols, re.M).group(1), 16)
pt_pa = pt_va - 0xffffffff40000000
disassembly = subprocess.check_output([
    'riscv64-unknown-elf-objdump', '-d', 'bin/kernel'], cwd=root, text=True)
csr_va = int(re.search(r'^([0-9a-f]+):.*\bcsrw\s+satp,',
                       disassembly, re.M).group(1), 16)
csr_pa = csr_va - 0xffffffff40000000
commands = f'''set pagination off
set confirm off
set architecture riscv:rv64
set trace-commands on
file bin/kernel
target remote 127.0.0.1:{port}
thbreak *{csr_pa:#x}
continue
x/gx {pt_pa + 2 * 8:#x}
set {{unsigned long long}}{pt_pa + 2 * 8:#x} = 0
info registers pc satp
si
info registers pc satp
python
try:
    gdb.execute("x/i $pc")
except gdb.error as error:
    print("EXPECTED_UNMAPPED_LOW_PC:", error)
end
set {{unsigned long long}}{pt_va + 2 * 8:#x} = 0x200000cf
x/i $pc
thbreak *kern_init
continue
info registers pc scause stval satp
detach
quit
'''
(root / 'logs/bootstrap-mapping.gdb').write_text(commands)
with socket.socket() as check:
    check.bind(('127.0.0.1', port))
with (root / 'logs/bootstrap-mapping-qemu.log').open('w') as output:
    qemu = subprocess.Popen([
        'qemu-system-riscv64', '-machine', 'virt', '-nographic', '-bios',
        'default', '-kernel', 'bin/ucore.img', '-S', '-gdb',
        'tcp:127.0.0.1:' + str(port),
    ], cwd=root, stdout=output, stderr=subprocess.STDOUT,
        start_new_session=True)
    try:
        deadline = time.monotonic() + 5
        while True:
            try:
                with socket.create_connection(('127.0.0.1', port), .1):
                    break
            except OSError:
                if time.monotonic() > deadline:
                    raise TimeoutError('QEMU port did not open')
                time.sleep(.05)
        result = subprocess.run([
            'gdb-multiarch', '-q', '-nx', '-batch', '-x',
            'logs/bootstrap-mapping.gdb',
        ], cwd=root, stdout=subprocess.PIPE, stderr=subprocess.STDOUT,
            text=True, timeout=15)
        (root / 'logs/bootstrap-mapping.log').write_text(result.stdout)
        print(result.stdout)
        assert result.returncode == 0, result.stdout
        assert 'EXPECTED_UNMAPPED_LOW_PC:' in result.stdout, result.stdout
        assert 'kern_init ()' in result.stdout, result.stdout
        print('Removing/restoring the identity mapping changes low-PC visibility: PASS')
    finally:
        os.killpg(qemu.pid, signal.SIGTERM)
        qemu.wait(timeout=5)
