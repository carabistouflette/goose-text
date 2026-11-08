#!/usr/bin/env python3
# SPDX-License-Identifier: Apache-2.0
"""Prove that one incorrect diagnostic makes the differential oracle fail."""
from pathlib import Path
import subprocess
import sys
import tempfile

adapter = Path(sys.argv[1]).resolve()
model = Path(__file__).with_name('diagnostics-model.py')
with tempfile.TemporaryDirectory(prefix='utf8-oracle-control-') as raw:
    proxy = Path(raw) / 'wrong-diagnostic.py'
    proxy.write_text(
        '#!/usr/bin/env python3\n'
        'import subprocess,sys\n'
        f'result=subprocess.run([{str(adapter)!r}], input=sys.stdin.read(), '
        'text=True, capture_output=True)\n'
        'if result.returncode: sys.exit(result.returncode)\n'
        'rows=result.stdout.splitlines()\n'
        'rows[0]="-1\\t9"\n'
        'print("\\n".join(rows))\n')
    proxy.chmod(0o700)
    result = subprocess.run([sys.executable, str(model), str(proxy), '--cases', '0'],
                            capture_output=True, text=True, timeout=60)
    if result.returncode == 0 or '1 diagnostic mismatches' not in result.stderr:
        sys.exit('oracle failed to reject exactly one incorrect result:\n'
                 + result.stdout + result.stderr)
print('Diagnostic oracle negative control: one incorrect result rejected')
