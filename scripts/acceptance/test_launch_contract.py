#!/usr/bin/env python3
"""Verify explicit acceptance launch arguments fail closed without opening owner state."""
import argparse
import subprocess
from pathlib import Path

p=argparse.ArgumentParser(description=__doc__)
p.add_argument('executable',type=Path)
a=p.parse_args()
# The existing self-test switch makes the pre-fix failure safe: an old App exits
# from its ordinary test seam rather than opening its normal history/window.
invalid_options = [
    ['--ticket06-acceptance=not-a-uuid'],
    ['--ticket06-acceptance=../../owner-history'],
    ['--ticket06-service=live'],
    ['--ticket06-acceptance=00000000-0000-0000-0000-000000000001', '--ticket06-service=unknown'],
    ['--ticket06-acceptance=00000000-0000-0000-0000-000000000001', '--ticket06-acceptance=00000000-0000-0000-0000-000000000002'],
    ['--ticket06-unknown'],
    ['--ticket06'],
    ['--ticket06-acceptance=00000000-0000-0000-0000-000000000001'],
]
for options in invalid_options:
    result=subprocess.run([str(a.executable.resolve()),'--self-test',*options],capture_output=True,timeout=30)
    if result.returncode != 2 or b'TICKET06_ACCEPTANCE_INVALID' not in result.stdout.splitlines():
        raise SystemExit('RED: malformed or conflicting acceptance arguments did not fail closed before normal App initialization')
print('TICKET06_LAUNCH_CONTRACT_OK invalid-uuid-and-options=closed')
