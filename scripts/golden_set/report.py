#!/usr/bin/env python3
"""Generate a fail-closed Golden Set report from outputs and independent reviews."""
import argparse
import json
from pathlib import Path

COUNTS = {'formula': 30, 'table': 20, 'mixed': 20, 'boundary': 10}
CHECKS = {
    'formula': ('meaning', 'layout', 'preview', 'copy'),
    'table': ('table_structure', 'canonical', 'preview', 'copy'),
    'mixed': ('meaning', 'layout', 'table_structure', 'canonical', 'preview', 'correction', 'copy'),
    'boundary': ('meaning', 'layout', 'canonical', 'preview', 'copy'),
}

def summarize(cases, results, reviews, mode):
    if len({c['id'] for c in cases}) != 80 or any(sum(c['category'] == k for c in cases) != n for k,n in COUNTS.items()):
        raise ValueError('Golden Set must contain exactly 30/20/20/10 unique cases')
    rows = []
    for case in cases:
        matches = [r for r in results if r['caseID'] == case['id'] and r['mode'] == mode and r['inputSHA256'] == case.get('inputSHA256')]
        if len(matches) > 1:
            raise ValueError('Ambiguous duplicate result: ' + case['id'])
        result = matches[0] if matches else None
        verdict = 'pending'
        reason = 'No matching recognition output'
        if result:
            if result.get('status') != 'complete':
                verdict,reason = 'fail','Recognition failed: ' + result.get('errorCode','unknown')
            else:
                accepted = [r for r in reviews if r.get('caseID') == case['id'] and r.get('mode') == mode and r.get('inputSHA256') == result['inputSHA256'] and r.get('outputSHA256') == result['outputSHA256']]
                if len(accepted) > 1: raise ValueError('Ambiguous duplicate review: ' + case['id'])
                review = accepted[0] if accepted else None
                reason = 'Semantic/layout and consumption review pending'
                if review and review.get('reviewer') and review.get('reviewedAt') and review.get('notes'):
                    checks = review.get('checks',{})
                    values = [checks.get(key) for key in CHECKS[case['category']]]
                    if any(v == 'fail' for v in values): verdict,reason = 'fail',review['notes']
                    elif all(v == 'pass' for v in values): verdict,reason = 'pass',review['notes']
        rows.append({'caseID':case['id'],'category':case['category'],'verdict':verdict,'reason':reason})
    def group(categories):
        selected = [r for r in rows if r['category'] in categories]
        return {'total':len(selected),'passed':sum(r['verdict']=='pass' for r in selected),'failed':sum(r['verdict']=='fail' for r in selected),'pending':sum(r['verdict']=='pending' for r in selected)}
    ordinary=group(('formula','table','mixed'))
    category={c:group((c,)) for c in COUNTS}
    gate='pending' if ordinary['pending'] else ('pass' if ordinary['passed'] >= 67 and category['formula']['passed'] >= 27 and category['table']['passed'] >= 18 and category['mixed']['passed'] >= 18 else 'fail')
    matching=[r for r in results if r['mode']==mode and any(c['id']==r['caseID'] and c.get('inputSHA256')==r['inputSHA256'] for c in cases)]
    latencies=sorted(r['wallSeconds'] for r in matching if r.get('status')=='complete' and isinstance(r.get('wallSeconds'),(int,float)))
    costs=[r['costCents'] for r in matching if isinstance(r.get('costCents'),(int,float))]
    return {'mode':mode,'gate':gate,'ordinary':ordinary,'categories':category,'boundary':category['boundary'],'rows':rows,'measurement':{'attempts':len(matching),'automaticRetries':sum(r.get('automaticRetryCount',0) for r in matching),'medianWallSeconds':latencies[len(latencies)//2] if latencies else None,'underFiveSeconds':sum(x<5 for x in latencies),'knownCostCents':sum(costs) if costs else None,'costAvailableAttempts':len(costs)},'policy':'Fast and balanced evaluated separately. No cherry-picked best-of gate. Notion inline paste remains a known deferred defect; serialization checks do not establish destination compatibility.'}

def main():
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('manifest',type=Path)
    parser.add_argument('run',type=Path)
    parser.add_argument('--reviews',type=Path)
    parser.add_argument('--output',type=Path,required=True)
    args=parser.parse_args()
    manifest=json.loads(args.manifest.read_text())
    results=[json.loads(p.read_text()) for p in sorted(args.run.glob('results/*.json'))]
    reviews=json.loads(args.reviews.read_text()) if args.reviews else []
    report={'schema':1,'corpus':manifest['version'],'modes':[summarize(manifest['cases'],results,reviews,m) for m in ('fast','balanced')]}
    args.output.parent.mkdir(parents=True,exist_ok=True)
    args.output.write_text(json.dumps(report,ensure_ascii=False,indent=2)+'\n')
    for entry in report['modes']:
        print(f"{entry['mode']}: gate={entry['gate']} ordinary={entry['ordinary']['passed']}/70 pending={entry['ordinary']['pending']} boundary={entry['boundary']['passed']}/10")

if __name__=='__main__': main()
