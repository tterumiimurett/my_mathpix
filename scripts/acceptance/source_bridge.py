#!/usr/bin/env python3
"""Join reviewed source pairs to a prebuilt audited candidate; no build or service calls."""
import argparse
import hashlib
import json
import re
import subprocess
from pathlib import Path
from candidate_checks import audit

PAIR_FILE = Path(__file__).with_name('reviewed_source_pairs.json')
CATEGORIES = ('productionWindowShellChanges', 'windowContractTestChanges',
              'acceptanceOnlyChanges', 'reviewedGoldenRunnerRefactor')

def sha(data):
    return hashlib.sha256(data).hexdigest()

def input_index(entries):
    result = {}
    for entry in entries:
        path, digest = entry['path'], entry['sha256']
        if path in result or not isinstance(path, str) or not re.fullmatch('[0-9a-f]{64}', digest):
            raise ValueError('invalid_or_duplicate_input')
        result[path] = digest
    return result

def main():
    p = argparse.ArgumentParser(description=__doc__)
    p.add_argument('repo', type=Path)
    p.add_argument('app', type=Path)
    p.add_argument('golden_provenance', type=Path)
    p.add_argument('--output', type=Path, required=True)
    p.add_argument('--candidate-manifest', type=Path, help='Defaults to output sibling supporting-checks.json.')
    p.add_argument('--build-provenance', type=Path, help='Defaults to output sibling build-stage-provenance.json.')
    a = p.parse_args()
    root, app = a.repo.resolve(), a.app.resolve()
    if a.output.exists():
        raise ValueError('refusing_to_overwrite_provenance')
    pairs = json.loads(PAIR_FILE.read_text())
    baseline_data = a.golden_provenance.read_bytes()
    if sha(baseline_data) != pairs['baselineProvenanceSHA256']:
        raise ValueError('baseline_provenance_mismatch')
    before = json.loads(baseline_data)
    recorded_baseline = input_index(before['sourceInputs']['files'])
    baseline = dict(recorded_baseline)
    supplement = pairs['baselineCoverageSupplement']
    for entry in supplement:
        if entry['path'] in baseline or entry['sourceRevision'] != before['sourceRevision']:
            raise ValueError('baseline_coverage_supplement_mismatch')
        baseline[entry['path']] = entry['sha256']
    dirty = subprocess.check_output(['git', 'status', '--porcelain', '--',
                                    'Sources', 'Config', 'Package.swift', 'scripts/build_app.sh'], cwd=root)
    if dirty.strip():
        raise ValueError('build_inputs_not_committed_and_clean')
    paths = set(baseline) | {'Package.swift', 'scripts/build_app.sh'}
    for directory in ('Sources', 'Config'):
        paths.update(str(path.relative_to(root)) for path in (root / directory).rglob('*') if path.is_file())
    if any((root / path).is_symlink() for path in paths):
        raise ValueError('symlink_build_input')
    current = {path: sha((root / path).read_bytes()) for path in sorted(paths) if (root / path).is_file()}
    if any(current.get(entry['path']) != entry['sha256'] for entry in supplement):
        raise ValueError('supplemental_build_input_changed_or_missing')
    pinned = {}
    for category in CATEGORIES:
        for entry in pairs['categories'][category]:
            name = entry['path']
            if name in pinned:
                raise ValueError('overlapping_reviewed_categories')
            pinned[name] = entry
            if baseline.get(name) != entry['previousSHA256'] or current.get(name) != entry['sha256']:
                raise ValueError('reviewed_source_hash_mismatch:' + name)
    changed = {name for name in set(baseline) | set(current) if baseline.get(name) != current.get(name)}
    if changed != set(pinned):
        raise ValueError('unreviewed_build_input_change')
    unchanged = [{'path': name, 'sha256': baseline[name]} for name in sorted(baseline)
                 if name not in pinned and current.get(name) == baseline[name]]
    content = [entry for entry in unchanged if entry['path'].startswith('Sources/')]
    resources = [entry for entry in content if '/Resources/' in entry['path']]
    # This joins externally observed builder provenance; it never infers a build
    # from the audit checkout HEAD or from an old candidate's successful tests.
    manifest_path = a.candidate_manifest or a.output.parent / 'supporting-checks.json'
    build_path = a.build_provenance or a.output.parent / 'build-stage-provenance.json'
    support, build = json.loads(manifest_path.read_text()), json.loads(build_path.read_text())
    candidate, _ = audit(app)
    if (support.get('supportingChecksPassed') is not True
            or support.get('sameCandidateUnchanged') is not True
            or support.get('candidate') != candidate or build.get('candidate') != candidate):
        raise ValueError('candidate_differs_from_audited_manifests')
    builder = build.get('builderGitCommit')
    if (not isinstance(builder, str) or not re.fullmatch('[0-9a-f]{40}', builder)
            or support.get('builderGitCommit') != builder or build.get('builderClean') is not True
            or input_index(build['buildInputs']) != current):
        raise ValueError('builder_source_inputs_do_not_match_reviewed_bytes')
    entries = [{'path': name, 'sha256': current[name]} for name in sorted(current)]
    report = {
        'schema': 3,
        'auditSourceRevision': subprocess.check_output(['git', 'rev-parse', 'HEAD'], cwd=root, text=True).strip(),
        'builderSourceRevision': builder,
        'reviewedProductionSourceRevision': pairs['reviewedProductionSourceRevision'],
        'reviewedIntegrationRevision': pairs['reviewedIntegrationRevision'],
        'candidateArtifactSHA256': candidate['artifactSHA256'], 'candidateCDHash': candidate['cdhash'],
        'candidateBundleTreeSHA256': candidate['bundleTreeSHA256'],
        'goldenSourceRevision': before['sourceRevision'], 'goldenArtifactSHA256': before['artifactSHA256'],
        'corpusSHA256': before['corpusSHA256'], 'goldenConfigurationSHA256': before['configurationSHA256'],
        'qualityPipelineInputsUnchanged': False, 'ordinaryContentResourceInputsUnchanged': True,
        'counts': {'recordedBaselineInputs': len(recorded_baseline),
                   'baselineCoverageSupplement': len(supplement), 'effectiveBaselineInputs': len(baseline),
                   'candidateInputs': len(current),
                   'unchangedBuildInputs': len(unchanged), 'unchangedContentResourceInputs': len(content),
                   'unchangedResources': len(resources),
                   **{name: len(pairs['categories'][name]) for name in CATEGORIES}},
        **{name: pairs['categories'][name] for name in CATEGORIES},
        'baselineCoverageSupplement': supplement,
        'unchangedBuildInputs': unchanged,
        'sourceInputs': {'sha256': sha(json.dumps(entries, separators=(',', ':')).encode()), 'files': entries},
        'manifestBindings': {'supportingChecksSHA256': sha(manifest_path.read_bytes()),
                             'buildProvenanceSHA256': sha(build_path.read_bytes()),
                             'reviewedPairsSHA256': sha(PAIR_FILE.read_bytes())},
        'actualWindowRoleJourney': 'pending-parent-observation',
        'limit': 'Unclassified content/resources/build inputs match the frozen baseline plus explicitly listed original-commit coverage supplements byte-for-byte. '
                 'Production window shell, window tests, acceptance telemetry and the Golden runner have disjoint exact reviewed pairs. '
                 'This is source continuity plus external build/audit provenance, not a new paid quality run, binary equivalence or actual GUI/live acceptance.'
    }
    a.output.parent.mkdir(parents=True, exist_ok=True)
    a.output.write_text(json.dumps(report, indent=2) + '\n')
    print('TICKET06_SOURCE_BRIDGE_OK production_shell=' + str(report['counts']['productionWindowShellChanges'])
          + ' window_tests=' + str(report['counts']['windowContractTestChanges'])
          + ' acceptance_only=' + str(report['counts']['acceptanceOnlyChanges'])
          + ' unchanged_inputs=' + str(len(unchanged)))

if __name__ == '__main__':
    main()
