import os
from pathlib import Path
import signal
import subprocess
import tempfile
import time
import unittest


SCRIPT = Path(__file__).with_name("get_k8s_debugging_info.sh")
HELPERS = SCRIPT.read_text().split("# Warnings")[0]


class PrometheusDiagnosticsTest(unittest.TestCase):
    def test_redaction_preserves_validated_labels_and_samples(self):
        data = '''# HELP example Contact person@example.com at 10.20.30.40
# TYPE example counter
example{method="GET",status_code="200",tenant_id="private",path="/private",le="-Inf"} 123456789012345
example{method="POST",status_code="500",quantile="NaN",le="+Inf"} 12345.6789 1234567890123
example{method="secret",status_code="private",le="NaN"} -1.2e+09
example{le="0.00001",quantile="0.99"} +Inf
example{route="escaped\\\"private"} NaN # {trace_id="private"} 1
sk-abcdefghijklmnopqrstuvwxyz_total 42
-----BEGIN PRIVATE KEY-----
private-key-material
-----END PRIVATE KEY-----
'''
        for mode in ("--redact", "--redact-strict"):
            with self.subTest(mode=mode), tempfile.TemporaryDirectory() as root:
                snapshot = Path(root) / "test.prom"
                snapshot.write_text(data)
                subprocess.run(
                    ["bash", "-c", HELPERS + '\nredact_file "$SNAPSHOT"',
                     "test", "--namespace", "test", mode],
                    env=dict(os.environ, SNAPSHOT=str(snapshot)),
                    check=True, capture_output=True, text=True,
                )
                output = snapshot.read_text()
                for value in ("private", "secret", "person@example.com", "sk-abcdefghijklmnopqrstuvwxyz"):
                    self.assertNotIn(value, output)
                for value in ('method="GET"', 'method="POST"', 'status_code="200"',
                              'status_code="500"', 'le="-Inf"', 'le="+Inf"',
                              'le="NaN"', 'quantile="NaN"', 'le="0.00001"',
                              '123456789012345', '12345.6789 1234567890123', '-1.2e+09'):
                    self.assertIn(value, output)
                self.assertNotIn('trace_id=', output)
                if mode == "--redact-strict":
                    self.assertNotIn("10.20.30.40", output)

    def test_interrupt_aborts_after_first_target_and_cleans_forward(self):
        for sig in (signal.SIGINT, signal.SIGTERM):
            with self.subTest(signal=sig), tempfile.TemporaryDirectory() as root:
                root = Path(root)
                kubectl = root / "kubectl"
                kubectl.write_text('#!/bin/bash\necho "$BASHPID" > "$PIDFILE"\nexec sleep 60\n')
                kubectl.chmod(0o755)
                caller = SCRIPT.read_text().split('        collect_prometheus "$POD"')[1].split('      done <')[0]
                command = HELPERS + '\nPOD=pod; PORT=1989; DIR="$TESTDIR"; mkdir "$DIR/metrics"\ncollect_prometheus "$POD"' + caller + '\necho continued > "$DIR/continued"\n'
                process = subprocess.Popen(
                    ["bash", "-c", command, "test", "--namespace", "test"],
                    env=dict(os.environ, PATH=f"{root}:" + os.environ["PATH"],
                             PIDFILE=str(root / "pid"), TESTDIR=str(root)),
                    start_new_session=True, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL,
                )
                try:
                    for _ in range(100):
                        if (root / "pid").exists():
                            break
                        time.sleep(0.02)
                    self.assertTrue((root / "pid").exists())
                    os.killpg(process.pid, sig)
                    self.assertIn(process.wait(timeout=5), (-sig, 128 + sig))
                    self.assertFalse((root / "continued").exists())
                    with self.assertRaises(ProcessLookupError):
                        os.kill(int((root / "pid").read_text()), 0)
                finally:
                    if process.poll() is None:
                        os.killpg(process.pid, signal.SIGKILL)
                        process.wait()


if __name__ == "__main__":
    unittest.main()
