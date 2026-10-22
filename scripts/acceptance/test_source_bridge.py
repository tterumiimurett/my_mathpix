#!/usr/bin/env python3
"""Public provenance CLI integration checks; reads an already-built candidate only."""
import json
import os
import shutil
import subprocess
import tempfile
import unittest
from pathlib import Path

REPO = Path(__file__).resolve().parents[2]
CLI = REPO / 'scripts/acceptance/source_bridge.py'
GOLDEN = REPO / '.scratch/personal-mvp/evidence/ticket05-golden-set/baseline-v2/build-provenance.json'
RAW = Path(os.environ.get('MYMATHPIX_BRIDGE_EVIDENCE', '/private/tmp/my_mathpix-remaining-context/window-candidate-evidence'))

class SourceBridgeCLI(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory(prefix='mymathpix-public-bridge-')
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name)
        self.repo = self.root / 'source'
        self.repo.mkdir()
        for directory in ('Sources', 'Config'):
            shutil.copytree(REPO / directory, self.repo / directory)
        (self.repo / 'scripts').mkdir()
        for name in ('Package.swift', 'scripts/build_app.sh'):
            shutil.copyfile(REPO / name, self.repo / name)
        for name in ('supporting-checks.json', 'build-stage-provenance.json'):
            shutil.copyfile(RAW / name, self.root / name)
        self.app = json.loads((RAW / 'supporting-checks.json').read_text())['candidate']['appPath']
        self.git('init', '-q')
        self.commit()

    def git(self, *args):
        subprocess.run(['git', '-c', 'core.hooksPath=/dev/null', '-c', 'user.name=BridgeFixture',
                        '-c', 'user.email=fixture@invalid', '-c', 'commit.gpgsign=false', *args],
                       cwd=self.repo, capture_output=True, check=True)

    def commit(self):
        self.git('add', '.')
        self.git('commit', '-qm', 'public CLI fixture')

    def invoke(self, golden=GOLDEN):
        output = self.root / 'bridge.json'
        result = subprocess.run(['python3', str(CLI), str(self.repo), str(self.app), str(golden),
                                 '--output', str(output)], capture_output=True, text=True)
        return result, output

    def test_reviewed_window_roles_are_distinct_from_acceptance_telemetry(self):
        result, output = self.invoke()
        self.assertEqual(result.returncode, 0, result.stderr)
        report = json.loads(output.read_text())
        self.assertEqual(len(report['productionWindowShellChanges']), 6)
        self.assertEqual(len(report['windowContractTestChanges']), 2)
        self.assertEqual(len(report['acceptanceOnlyChanges']), 6)
        self.assertEqual(len(report['reviewedGoldenRunnerRefactor']), 1)
        self.assertFalse(report['qualityPipelineInputsUnchanged'])
        self.assertTrue(report['ordinaryContentResourceInputsUnchanged'])
        shell = {entry['path'] for entry in report['productionWindowShellChanges']}
        acceptance = {entry['path'] for entry in report['acceptanceOnlyChanges']}
        self.assertFalse(shell & acceptance)
        self.assertIn('Sources/MyMathpix/ResultEditorView.swift', shell)
        self.assertEqual(report['builderSourceRevision'], '01dffed1f9cd653c8c296c3dc6083863c7d04f1f')

    def rejected(self, reason, golden=GOLDEN):
        result, output = self.invoke(golden)
        self.assertNotEqual(result.returncode, 0)
        self.assertIn(reason, result.stderr)
        self.assertFalse(output.exists())

    def test_one_byte_production_shell_edit_is_rejected(self):
        path = self.repo / 'Sources/MyMathpix/AppModel.swift'
        path.write_bytes(path.read_bytes() + b'\n')
        self.commit()
        self.rejected('reviewed_source_hash_mismatch')

    def test_unreviewed_content_edit_is_rejected(self):
        path = self.repo / 'Sources/MyMathpix/MarkdownRenderer.swift'
        path.write_bytes(path.read_bytes() + b'\n')
        self.commit()
        self.rejected('unreviewed_build_input_change')

    def test_missing_reviewed_addition_is_rejected(self):
        (self.repo / 'Sources/MyMathpix/AppWindowShell.swift').unlink()
        self.commit()
        self.rejected('reviewed_source_hash_mismatch')

    def test_missing_ordinary_file_is_rejected(self):
        (self.repo / 'Sources/MyMathpix/MarkdownRenderer.swift').unlink()
        self.commit()
        self.rejected('unreviewed_build_input_change')

    def test_unknown_new_config_path_is_rejected(self):
        (self.repo / 'Config/Unreviewed.config').write_text('unknown')
        self.commit()
        self.rejected('unreviewed_build_input_change')

    def test_unknown_new_source_path_is_rejected(self):
        (self.repo / 'Sources/MyMathpix/Unreviewed.swift').write_text('// unknown')
        self.commit()
        self.rejected('unreviewed_build_input_change')

    def test_acceptance_file_is_not_a_broad_path_exception(self):
        path = self.repo / 'Sources/MyMathpix/Ticket01AcceptanceReporter.swift'
        path.write_bytes(path.read_bytes() + b'\n')
        self.commit()
        self.rejected('reviewed_source_hash_mismatch')

    def test_existing_golden_runner_pin_still_rejects_edits(self):
        path = self.repo / 'Sources/MyMathpix/GoldenSetRunner.swift'
        path.write_bytes(path.read_bytes() + b'\n')
        self.commit()
        self.rejected('reviewed_source_hash_mismatch')

    def test_old_baseline_hash_cannot_be_replaced(self):
        baseline = json.loads(GOLDEN.read_text())
        baseline['sourceInputs']['files'][0]['sha256'] = '0' * 64
        changed = self.root / 'wrong-baseline.json'
        changed.write_text(json.dumps(baseline))
        self.rejected('baseline_provenance_mismatch', changed)

    def test_rejected_candidate_manifest_cannot_bind_new_source(self):
        old = REPO / '.scratch/personal-mvp/evidence/history/gui-rejected-ea7ad5f1/supporting-checks.json'
        shutil.copyfile(old, self.root / 'supporting-checks.json')
        self.rejected('candidate_differs_from_audited_manifests')

    def test_builder_inputs_must_match_actual_reviewed_source(self):
        path = self.root / 'build-stage-provenance.json'
        data = json.loads(path.read_text())
        data['buildInputs'][0]['sha256'] = '0' * 64
        path.write_text(json.dumps(data))
        self.rejected('builder_source_inputs_do_not_match_reviewed_bytes')

    def test_supplemental_package_input_cannot_change(self):
        path = self.repo / 'Package.swift'
        path.write_bytes(path.read_bytes() + b'\n')
        self.commit()
        self.rejected('supplemental_build_input_changed_or_missing')

    def test_dirty_build_source_is_rejected(self):
        path = self.repo / 'Sources/MyMathpix/AppModel.swift'
        path.write_bytes(path.read_bytes() + b'\n')
        self.rejected('build_inputs_not_committed_and_clean')

if __name__ == '__main__':
    unittest.main()
