#!/usr/bin/env python3
"""Bind the handoff source/artifact to the reviewed Golden Set pipeline, without rerunning API calls."""
import argparse
import hashlib
import json
import subprocess
from pathlib import Path

ACCEPTANCE_ONLY = {
    'Sources/MyMathpix/AppModel.swift': 'Supplies current acceptance source to the optional clipboard reporter; quality model path has no reporter.',
    'Sources/MyMathpix/MyMathpixApp.swift': 'Explicit isolated acceptance launch and fail-closed arguments; normal and Golden Set entry paths retained.',
    'Sources/MyMathpix/ResultEditorView.swift': 'Reports actual Edit disclosure visibility without changing rendering/copy behavior.',
    'Sources/MyMathpix/Ticket01AcceptanceReporter.swift': 'Truthful Edit visibility telemetry.',
    'Sources/MyMathpix/Ticket03AcceptanceFixture.swift': 'Known-fixture public clipboard inspector accepts initial/edited three-row workflow.',
    'Sources/MyMathpix/Ticket03AcceptanceReporter.swift': 'Requires actual edit/original observations for acceptance completion.',
    'Sources/MyMathpix/Ticket03SelfCheck.swift': 'Public clipboard acceptance-stage regressions.',
    'Sources/MyMathpix/SelfCheck.swift': 'Disposable acceptance persistence regression.',
    'Sources/MyMathpix/Ticket06Acceptance.swift': 'Explicit UUID-scoped history/usage/defaults and live/fault launch factory.',
}
PIPELINE = (
    'DatalabClient.swift', 'RecognitionService.swift', 'ClipboardService.swift',
    'ComplexTableOutputSanitizer.swift', 'MarkdownNormalizer.swift', 'MarkdownRenderer.swift',
    'TableCellText.swift', 'HTMLTextEntities.swift', 'MarkdownCodeFence.swift',
    'LarkClipboardDocument.swift', 'NotionClipboardDocument.swift', 'AppResources.swift',
    'HistoryStore.swift', 'Models.swift', 'UsageRecordStore.swift', 'GoldenSetRunner.swift',
)
def sha(data): return hashlib.sha256(data).hexdigest()
def main():
    p=argparse.ArgumentParser(description=__doc__)
    p.add_argument('repo',type=Path)
    p.add_argument('app',type=Path)
    p.add_argument('golden_provenance',type=Path)
    p.add_argument('--output',type=Path,required=True)
    a=p.parse_args();root=a.repo.resolve();app=a.app.resolve();before=json.loads(a.golden_provenance.read_text())
    if a.output.exists():raise ValueError('refusing_to_overwrite_provenance')
    dirty=subprocess.check_output(['git','status','--porcelain','--','Sources','Config','Package.swift','scripts/build_app.sh'],cwd=root)
    if dirty.strip():raise ValueError('build_inputs_not_committed_and_clean')
    baseline={x['path']:x['sha256'] for x in before['sourceInputs']['files']}
    paths={Path(x) for x in baseline}
    paths.update(x.relative_to(root) for x in (root/'Sources').rglob('*') if x.is_file())
    current={str(path):sha((root/path).read_bytes()) for path in sorted(paths) if (root/path).is_file()}
    changed=[name for name in sorted(set(baseline)|set(current)) if baseline.get(name)!=current.get(name)]
    if any(name not in ACCEPTANCE_ONLY for name in changed):raise ValueError('unreviewed_build_input_change')
    pipeline_paths=['Sources/MyMathpix/'+x for x in PIPELINE]
    pipeline_paths.extend(x for x in baseline if x.startswith('Sources/MyMathpix/Resources/'))
    if any(x not in current or x not in baseline or current[x]!=baseline[x] for x in pipeline_paths):
        raise ValueError('golden_quality_pipeline_changed_or_missing')
    entries=[{'path':name,'sha256':current[name]} for name in sorted(current)]
    revision=subprocess.check_output(['git','rev-parse','HEAD'],cwd=root,text=True).strip()
    report={
        'schema':1,'candidateSourceRevision':revision,'candidateArtifactSHA256':sha((app/'Contents/MacOS/MyMathpix').read_bytes()),
        'goldenSourceRevision':before['sourceRevision'],'goldenArtifactSHA256':before['artifactSHA256'],
        'corpusSHA256':before['corpusSHA256'],'goldenConfigurationSHA256':before['configurationSHA256'],
        'qualityPipelineInputsUnchanged':True,'verifiedQualityPipelineFiles':len(pipeline_paths),
        'acceptanceOnlyChanges':[{'path':x,'previousSHA256':baseline.get(x),'sha256':current.get(x),'reviewReason':ACCEPTANCE_ONLY[x]} for x in changed],
        'sourceInputs':{'sha256':sha(json.dumps(entries,separators=(',',':')).encode()),'files':entries},
        'limit':'Source comparison bridges unchanged recognition/normalization/rendering/clipboard/history pipeline. Host-only differences require diff review; this is not a fresh API run or GUI acceptance.',
    }
    a.output.parent.mkdir(parents=True,exist_ok=True);a.output.write_text(json.dumps(report,indent=2)+'\n')
    print('TICKET06_SOURCE_BRIDGE_OK pipeline=unchanged host_changes='+str(len(changed)))
if __name__=='__main__':main()
