#!/usr/bin/env python3
"""Create hash-bound pending reviews; this command cannot approve an output."""
import argparse
import json
from pathlib import Path
from report import CHECKS

p=argparse.ArgumentParser(description=__doc__)
p.add_argument('run',type=Path)
p.add_argument('--output',type=Path,required=True)
a=p.parse_args()
manifest=json.loads((a.run/'manifest.json').read_text())
cases={c['id']:c for c in manifest['cases']}
reviews=[]
for path in sorted((a.run/'results').glob('*.json')):
    result=json.loads(path.read_text())
    if result.get('status')!='complete':continue
    case=cases[result['caseID']]
    required=CHECKS[case['category']]+(('table_structure',) if case['category']=='boundary' and case.get('tableGrids') else ())
    review={key:result[key] for key in ('caseID','mode','inputSHA256','contentSHA256','outputSHA256','corpusSHA256','configurationSHA256','artifactSHA256')}
    review.update(reviewer='',reviewedAt='',notes='',checks={key:'pending' for key in required})
    reviews.append(review)
if a.output.exists():raise SystemExit('Refusing to overwrite an existing review file')
a.output.write_text(json.dumps(reviews,indent=2,ensure_ascii=False)+'\n')
print(f'Created {len(reviews)} pending review records; no quality verdicts assigned')
