#!/usr/bin/env python3
"""Check one prebuilt signed candidate; never builds, signs, or grants access."""
import argparse
import hashlib
import json
import plistlib
import platform
import re
import subprocess
import time
from pathlib import Path

REQUIRED_ASSETS = {
    'katex.min.css': 10_000,
    'katex.min.js': 100_000,
    'KATEX-LICENSE.txt': 100,
    'fonts/KaTeX_Main-Regular.woff2': 1_000,
}
CHECKS = (
    ('deterministic', '--self-test', r'MyMathpix self-test passed \([0-9]+ checks(?: plus Ticket 04 workflow checks)?\)\.'),
    ('mock_recognition', '--ticket01-mock-recognition-self-test', r'TICKET01_MOCK_PROTOCOL_OK submit=1 polls=multiple png=yes fields=yes fixture=yes guard=yes result=yes'),
    ('overlay_lifecycle', '--ticket01-overlay-lifecycle-self-test', r'TICKET01_OVERLAY_LIFECYCLE_OK'),
    ('offline_resources', '--ticket01-resource-bundle-self-test', r'TICKET01_RESOURCE_BUNDLE_OK'),
    ('local_token_fixture', '--ticket01-local-token-self-test', r'TICKET01_LOCAL_TOKEN_OK'),
    ('recognition_contract', '--ticket02-recognition-self-test', r'TICKET02_RECOGNITION_OK'),
    ('edit_preview_copy_contract', '--ticket03-self-test', r'Ticket 03 self-test passed\.'),
    ('daily_workflow_contract', '--ticket04-daily-workflow-self-test', r'TICKET04_DAILY_WORKFLOW_OK'),
)

def digest(data):
    return hashlib.sha256(data).hexdigest()

def command(args, timeout=30):
    return subprocess.run(args, capture_output=True, timeout=timeout, check=False)

def audit(app):
    info = plistlib.loads((app/'Contents/Info.plist').read_bytes())
    binary = app/'Contents/MacOS'/info['CFBundleExecutable']
    resources = app/'Contents/Resources/MyMathpix_MyMathpix.bundle/Resources'
    if command(['codesign', '--verify', '--deep', '--strict', str(app)]).returncode:
        raise ValueError('signature_verification_failed')
    signed = command(['codesign', '-dvvv', str(app)])
    cdhash = re.search(rb'^CDHash=([0-9a-f]{40})$', signed.stderr, re.M)
    if not cdhash:
        raise ValueError('cdhash_missing')
    ent = command(['codesign', '-d', '--entitlements', ':-', str(app)])
    try:
        entitlements = plistlib.loads(ent.stdout)
    except Exception:
        raise ValueError('entitlements_unreadable') from None
    if info.get('CFBundleIdentifier') != 'com.byterumi.mymathpix':
        raise ValueError('production_bundle_identity_required')
    for key in ('com.apple.security.app-sandbox', 'com.apple.security.network.client',
                'com.apple.security.files.user-selected.read-write'):
        if entitlements.get(key) is not True:
            raise ValueError('required_entitlement_missing')
    assets = {}
    for relative, minimum in REQUIRED_ASSETS.items():
        data = (resources/relative).read_bytes()
        if len(data) < minimum:
            raise ValueError('bundled_asset_missing_or_truncated')
        assets[relative] = {'bytes': len(data), 'sha256': digest(data)}
    if b'MIT' not in (resources/'KATEX-LICENSE.txt').read_bytes():
        raise ValueError('license_notice_missing')
    version = info.get('CFBundleShortVersionString')
    build = info.get('CFBundleVersion')
    if not version or not build:
        raise ValueError('version_metadata_missing')
    files = []
    for path in sorted(app.rglob('*')):
        relative = str(path.relative_to(app))
        if path.is_symlink():
            files.append([relative, 'symlink', str(path.readlink())])
        elif path.is_file():
            files.append([relative, 'file', digest(path.read_bytes())])
    return {
        'appPath': str(app), 'bundleIdentifier': info.get('CFBundleIdentifier'),
        'hostArchitecture': platform.machine(), 'hostMacOS': platform.mac_ver()[0],
        'version': version, 'build': build, 'artifactSHA256': digest(binary.read_bytes()),
        'bundleTreeSHA256': digest(json.dumps(files, ensure_ascii=False, separators=(',', ':')).encode()),
        'cdhash': cdhash.group(1).decode(), 'sandbox': True, 'outboundNetwork': True,
        'userSelectedExport': entitlements.get('com.apple.security.files.user-selected.read-write') is True,
        'resources': assets, 'signatureVerified': True,
    }, binary

def main():
    p = argparse.ArgumentParser(description=__doc__)
    p.add_argument('app', type=Path)
    mode = p.add_mutually_exclusive_group(required=True)
    mode.add_argument('--evidence-dir', type=Path)
    mode.add_argument('--verify-manifest', type=Path)
    p.add_argument('--git-commit', help='Builder-supplied commit; verify separately before sealing candidate.')
    a = p.parse_args()
    app = a.app.resolve(strict=True)
    if a.verify_manifest:
        prior = json.loads(a.verify_manifest.read_text())
        current, _ = audit(app)
        if prior.get('supportingChecksPassed') is not True or current != prior.get('candidate'):
            raise ValueError('candidate_differs_from_verified_manifest')
        print('TICKET06_CANDIDATE_UNCHANGED artifact='+current['artifactSHA256']+' cdhash='+current['cdhash'])
        return
    if not a.git_commit:
        raise ValueError('builder_git_commit_required')
    evidence = a.evidence_dir.resolve()
    if app.suffix != '.app' or evidence == app or app in evidence.parents:
        raise ValueError('invalid_candidate_or_evidence_path')
    evidence.mkdir(parents=True, exist_ok=True)
    report_path = evidence/'supporting-checks.json'
    if report_path.exists():
        raise ValueError('refusing_to_overwrite_prior_evidence')
    before, binary = audit(app)
    report = {
        'schema': 1, 'builderGitCommit': a.git_commit, 'candidate': before,
        'checks': [], 'sameCandidateUnchanged': False,
        'primarySignedAppJourney': 'pending-external-CUA-observation',
        'liveServiceJourney': 'pending-external-CUA-observation',
        'destinationPaste': 'not-asserted', 'dogfoodGate': 'not-asserted',
    }
    try:
        for name, flag, expected in CHECKS:
            start = time.monotonic()
            result = command([str(binary), flag], timeout=90)
            # Keep only the fixed successful signal. No arbitrary service, token,
            # diagnostic or process output is retained in the report.
            lines = (result.stdout+result.stderr).decode(errors='replace').splitlines()
            signal = next((line for line in lines if re.fullmatch(expected, line)), None)
            passed = result.returncode == 0 and signal is not None
            report['checks'].append({'name': name, 'passed': passed, 'signal': signal,
                                     'exitCode': result.returncode, 'seconds': round(time.monotonic()-start, 3)})
            if not passed:
                raise ValueError('supporting_check_failed:'+name)
            after, _ = audit(app)
            if after != before:
                raise ValueError('candidate_changed_during_supporting_checks')
        after, _ = audit(app)
        report['sameCandidateUnchanged'] = after == before
        if not report['sameCandidateUnchanged']:
            raise ValueError('candidate_changed_after_supporting_checks')
        report['supportingChecksPassed'] = True
    except Exception as error:
        report['supportingChecksPassed'] = False
        report['failureCode'] = str(error) if isinstance(error, ValueError) else type(error).__name__
        raise
    finally:
        report_path.write_text(json.dumps(report, indent=2, ensure_ascii=False)+'\n')
    print('TICKET06_SUPPORTING_CHECKS_OK artifact='+before['artifactSHA256']+' cdhash='+before['cdhash'])
    print('PRIMARY_AND_LIVE_GUI_ACCEPTANCE_STILL_REQUIRED')

if __name__ == '__main__':
    try:
        main()
    except Exception as e:
        # Fixed failure class only; do not expose subprocess output or file contents.
        print('TICKET06_SUPPORTING_CHECKS_FAILED class='+type(e).__name__)
        raise SystemExit(1)
