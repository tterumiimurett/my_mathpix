#!/usr/bin/env python3
"""Author fixed, non-sensitive development Snippets; never derives truth from OCR."""
import hashlib
import html
import json
import re
from pathlib import Path

ROOT=Path(__file__).resolve().parents[2]
OUT=ROOT/'Sources/MyMathpix/Resources/GoldenSet'

def inline(text):
    parts=re.split(r'(\$[^$]+\$)',text)
    return ''.join('<span class="math" data-tex="'+html.escape(p[1:-1],quote=True)+'"></span>' if p.startswith('$') and p.endswith('$') else html.escape(p) for p in parts)

def table_html(grid):
    return '<table>'+''.join('<tr>'+''.join('<'+('th' if i==0 else 'td')+'>'+inline(c)+'</'+('th' if i==0 else 'td')+'>' for c in row)+'</tr>' for i,row in enumerate(grid))+'</table>'

def table_markdown(grid):
    return '\n'.join('| '+' | '.join(row)+' |' for row in [grid[0],['---']*len(grid[0]),*grid[1:]])

cases=[]
def add(cid,cat,title,source,body,notes,grid=None,style=''):
    cases.append({'id':cid,'category':cat,'title':title,'provenance':'Original authored development fixture; no private source or service-derived truth','goldenMarkdown':source,'fixtureBody':body,'fixtureStyle':style,'reviewNotes':notes,'tableGrids':grid or [],'inputSHA256':''})

formulas=[
('Quadratic roots',r'x=\frac{-b\pm\sqrt{b^2-4ac}}{2a}'),
('Pythagorean identity',r'a^2+b^2=c^2'),
('Euler identity',r'e^{i\pi}+1=0'),
('Gaussian density',r'p(x)=\frac{1}{\sigma\sqrt{2\pi}}\exp\left(-\frac{(x-\mu)^2}{2\sigma^2}\right)'),
('Definite integral',r'\int_0^1 x^2\,dx=\frac{1}{3}'),
('Geometric series',r'\sum_{k=0}^{n}r^k=\frac{1-r^{n+1}}{1-r}'),
('Limit',r'\lim_{x\to 0}\frac{\sin x}{x}=1'),
('Product',r'n!=\prod_{k=1}^{n}k'),
('Partial derivative',r'\frac{\partial f}{\partial x}=2xy+\cos x'),
('Gradient',r'\nabla f=\begin{pmatrix}\partial f/\partial x\\\partial f/\partial y\end{pmatrix}'),
('Matrix',r'A=\begin{pmatrix}1&2\\3&4\end{pmatrix}'),
('Determinant',r'\det\begin{pmatrix}a&b\\c&d\end{pmatrix}=ad-bc'),
('Piecewise function',r'f(x)=\begin{cases}x^2,&x\geq 0\\-x,&x<0\end{cases}'),
('Aligned equations',r'\begin{aligned}a+b&=c\\a-b&=d\end{aligned}'),
('Binomial theorem',r'(x+y)^n=\sum_{k=0}^{n}\binom{n}{k}x^{n-k}y^k'),
('Nested fraction',r'\frac{1}{1+\frac{1}{x}}=\frac{x}{x+1}'),
('Vector dot product',r'\mathbf{u}\cdot\mathbf{v}=\sum_{i=1}^{d}u_i v_i'),
('Norm',r'\lVert x\rVert_2=\sqrt{\sum_{i=1}^{d}x_i^2}'),
('Expectation',r'\mathbb{E}[X]=\sum_x x\,p(x)'),
('Conditional probability',r'P(A\mid B)=\frac{P(B\mid A)P(A)}{P(B)}'),
('Entropy',r'H(p)=-\sum_{i=1}^{n}p_i\log p_i'),
('KL divergence',r'D_{\mathrm{KL}}(p\Vert q)=\sum_i p_i\log\frac{p_i}{q_i}'),
('Softmax',r'p_i=\frac{e^{z_i}}{\sum_{j=1}^{n}e^{z_j}}'),
('Hessian',r'H_{ij}=\frac{\partial^2 f}{\partial x_i\partial x_j}'),
('Fourier transform',r'\widehat{f}(\omega)=\int_{-\infty}^{\infty}f(t)e^{-i\omega t}\,dt'),
('Differential equation',r'\frac{d^2 y}{dt^2}+\omega^2 y=0'),
('Complex conjugate',r'z\overline{z}=|z|^2'),
('Set relation',r'A\cap(B\cup C)=(A\cap B)\cup(A\cap C)'),
('Accents and subscripts',r'\widehat{\theta}_{n+1}=\widehat{\theta}_n-\eta\nabla L(\widehat{\theta}_n)'),
('Row spacing',r'\begin{aligned}a&=b\\[4pt]c&=d\end{aligned}'),
]
for i,(title,tex) in enumerate(formulas,1):
    add(f'F{i:02}','formula',title,'$$\n'+tex+'\n$$','<div class="math display" data-display="1" data-tex="'+html.escape(tex,quote=True)+'"></div>','Check every operator, bound, index, sign, grouping, and displayed row/matrix structure; equivalent LaTeX is acceptable.')

tables=[
[['Variable','Value'],['x','2'],['y','5']],
[['Method','Accuracy','Time (s)'],['Baseline','0.81','1.20'],['Candidate','0.93','0.85']],
[['Epoch','Loss'],['1','2.50'],['2','1.20'],['3','0.65']],
[['Symbol','Meaning'],['α','Learning rate'],['β','Momentum']],
[['Temperature (K)','Pressure (kPa)'],['273','101.3'],['298','110.6']],
[['Class','Precision','Recall'],['A','0.90','0.88'],['B','0.85','0.92']],
[['Condition','Count'],['Control','120'],['Treatment','118']],
[['Item','Mean','SD'],['Length','12.4','0.6'],['Mass','8.2','0.3']],
[['Parameter','Lower','Upper'],['a','-1.5','2.0'],['b','0.0','10.0']],
[['Split','Samples'],['Train','8000'],['Validation','1000'],['Test','1000']],
[['Axis','Unit','Scale'],['x','m','Linear'],['y','s','Log']],
[['Model','Small','Medium','Large'],['A','12','24','48'],['B','10','20','40']],
[['Name','Expression'],['Square','x²'],['Cube','x³']],
[['Metric','Before','After'],['Error','5.2%','2.1%'],['Speed','1.0×','1.8×']],
[['Sample','Result'],['S-01','Pass'],['S-02','Fail'],['S-03','Pass']],
[['Interval','Frequency'],['0–10','12'],['10–20','19'],['20–30','7']],
[['Code','Description'],['A1','Left branch'],['B2','Right branch']],
[['Term','Coefficient'],['Intercept','-0.25'],['Feature 1','1.75'],['Feature 2','0.50']],
[['Source','Destination','Weight'],['A','B','0.4'],['B','C','0.6'],['C','A','1.0']],
[['Threshold','TP','FP','FN'],['0.2','95','12','5'],['0.5','88','4','12'],['0.8','70','1','30']],
]
for i,grid in enumerate(tables,1):
    add(f'T{i:02}','table',f'Simple table {i:02}',table_markdown(grid),table_html(grid),'Check header/data row counts, columns, complete cell text, order, editable Markdown grid and TSV/rich structure.',[grid])

for i in range(1,21):
    tex=formulas[i-1][1]
    grid=tables[(i-1)%len(tables)]
    before=f'Experiment {i}: evaluate $x^2$ before comparing the measurements.'
    after='The result preserves the order of the observations.'
    source=before+'\n\n$$\n'+tex+'\n$$\n\n'+table_markdown(grid)+'\n\n'+after
    body='<p>'+inline(before)+'</p><div class="math display" data-display="1" data-tex="'+html.escape(tex,quote=True)+'"></div>'+table_html(grid)+'<p>'+after+'</p>'
    add(f'M{i:02}','mixed',f'Mixed experiment {i:02}',source,body,'Check text before/after, inline x squared, displayed mathematics and table in reading order. Correct source in isolated Result Editor model, rerender and copy complete edited content.',[grid])

# Ordinary mixed cases deliberately vary reading structure, not just the mathematics.
def replace_mixed(number, source, body, grids):
    item=next(c for c in cases if c['id']==f'M{number:02}')
    item.update(goldenMarkdown=source,fixtureBody=body,tableGrids=grids)

replace_mixed(11,'First measure $a^2+b^2=c^2$.\n\nThen compare the following observations.\n\n'+table_markdown(tables[0])+'\n\nTwo paragraphs precede this table.',
 '<p>'+inline('First measure $a^2+b^2=c^2$.')+'</p><p>Then compare the following observations.</p>'+table_html(tables[0])+'<p>Two paragraphs precede this table.</p>',[tables[0]])
replace_mixed(12,'The first experiment uses $x=2$.\n\n'+table_markdown(tables[0])+'\n\nCompare the second experiment.\n\n'+table_markdown(tables[2])+'\n\nBoth tables are required.',
 '<p>'+inline('The first experiment uses $x=2$.')+'</p>'+table_html(tables[0])+'<p>Compare the second experiment.</p>'+table_html(tables[2])+'<p>Both tables are required.</p>',[tables[0],tables[2]])
math_grid=[['Quantity','Formula'],['Energy','$E=mc^2$'],['Area','$A=\\pi r^2$']]
replace_mixed(13,'Keep the formulas inside their table cells.\n\n'+table_markdown(math_grid)+'\n\nThe symbol $r$ is a radius.',
 '<p>Keep the formulas inside their table cells.</p>'+table_html(math_grid)+'<p>'+inline('The symbol $r$ is a radius.')+'</p>',[math_grid])
replace_mixed(14,'The literal code `x**2` is not an equation; the fee is USD 5.\n\n$$x^2+y^2=z^2$$\n\n'+table_markdown(tables[5]),
 '<p>The literal code <code>x**2</code> is not an equation; the fee is USD 5.</p><div class="math display" data-display="1" data-tex="x^2+y^2=z^2"></div>'+table_html(tables[5]),[tables[5]])
replace_mixed(15,'### Measurement note\n\nFor $n=3$, compare the readings below.\n\n'+table_markdown(tables[6])+'\n\n> Units are unchanged.',
 '<h3>Measurement note</h3><p>'+inline('For $n=3$, compare the readings below.')+'</p>'+table_html(tables[6])+'<blockquote>Units are unchanged.</blockquote>',[tables[6]])
replace_mixed(16,'The mean is $\\mu=12.4$ and the deviation is $\\sigma=0.6$.\n\n'+table_markdown(tables[7])+'\n\nUse both $\\mu$ and $\\sigma$ when comparing samples.',
 '<p>'+inline('The mean is $\\mu=12.4$ and the deviation is $\\sigma=0.6$.')+'</p>'+table_html(tables[7])+'<p>'+inline('Use both $\\mu$ and $\\sigma$ when comparing samples.')+'</p>',[tables[7]])
replace_mixed(17,table_markdown(tables[8])+'\n\nThese limits constrain $a$ and $b$.\n\n$$a+b\\leq 12$$',
 table_html(tables[8])+'<p>'+inline('These limits constrain $a$ and $b$.')+'</p><div class="math display" data-display="1" data-tex="a+b\\leq 12"></div>',[tables[8]])
replace_mixed(18,'$$N=8000+1000+1000=10000$$\n\n'+table_markdown(tables[9])+'\n\nThe total $N$ includes all three splits.',
 '<div class="math display" data-display="1" data-tex="N=8000+1000+1000=10000"></div>'+table_html(tables[9])+'<p>'+inline('The total $N$ includes all three splits.')+'</p>',[tables[9]])
replace_mixed(19,'Read α and β in this order.\n\n'+table_markdown(tables[3])+'\n\nThe update is $v=\\beta v+\\alpha g$.\n\nA second paragraph explains the symbols.',
 '<p>Read α and β in this order.</p>'+table_html(tables[3])+'<p>'+inline('The update is $v=\\beta v+\\alpha g$.')+'</p><p>A second paragraph explains the symbols.</p>',[tables[3]])
replace_mixed(20,'Start with $x=1$.\n\n'+table_markdown(tables[14])+'\n\n$$\\begin{aligned}a+b&=c\\\\a-b&=d\\end{aligned}$$\n\nThen compare another table.\n\n'+table_markdown(tables[16])+'\n\nFinish in the same reading order.',
 '<p>'+inline('Start with $x=1$.')+'</p>'+table_html(tables[14])+'<div class="math display" data-display="1" data-tex="\\begin{aligned}a+b&amp;=c\\\\a-b&amp;=d\\end{aligned}"></div><p>Then compare another table.</p>'+table_html(tables[16])+'<p>Finish in the same reading order.</p>',[tables[14],tables[16]])

boundary=[
('Small formula','$$\\sum_{i=1}^{n}x_i^2$$','<div class="math display" data-display="1" data-tex="\\sum_{i=1}^{n}x_i^2"></div>','body {font-size:11px!important;}','Small subscripts and upper limits; deliberate difficult font size.'),
('Low contrast','$$\\frac{a+b}{c-d}$$','<div class="math display" data-display="1" data-tex="\\frac{a+b}{c-d}"></div>','body {color:#bbb!important;}','Low contrast fraction and minus sign.'),
('Rotated formula','$$E=mc^2$$','<div class="math display" data-display="1" data-tex="E=mc^2" style="transform:rotate(12deg)"></div>','','Rotation is deliberate; require mathematical equivalence.'),
('Dense matrix','$$A=\\begin{pmatrix}1&2&3&4\\\\5&6&7&8\\\\9&10&11&12\\\\13&14&15&16\\end{pmatrix}$$','<div class="math display" data-display="1" data-tex="A=\\begin{pmatrix}1&amp;2&amp;3&amp;4\\\\5&amp;6&amp;7&amp;8\\\\9&amp;10&amp;11&amp;12\\\\13&amp;14&amp;15&amp;16\\end{pmatrix}"></div>','body {font-size:16px!important;}','All sixteen cells, row/column positions and matrix delimiters.'),
('Merged table','| Group | Value |\n| --- | --- |\n| A | 1 |\n|  | 2 |','<table><tr><th>Group</th><th>Value</th></tr><tr><td rowspan="2">A</td><td>1</td></tr><tr><td>2</td></tr></table>','','Merged structure may require safe Complex Table Output, separate from ordinary gate.'),
('Literal code and currency','The code `x**2` costs $5; compare $x^2$.','<p>The code <code>x**2</code> costs $5; compare <span class="math" data-tex="x^2"></span>.</p>','','Code and currency must remain literal; final formula must remain mathematical.'),
('Adjacent nested radicals',r'$$\sqrt{1+\sqrt{1+\sqrt{x}}}$$','<div class="math display" data-display="1" data-tex="\\sqrt{1+\\sqrt{1+\\sqrt{x}}}"></div>','','All nested radical extents and plus signs.'),
('Two tables','| A | B |\n| --- | --- |\n| 1 | 2 |\n\nBetween tables.\n\n| C | D |\n| --- | --- |\n| 3 | 4 |','<table><tr><th>A</th><th>B</th></tr><tr><td>1</td><td>2</td></tr></table><p>Between tables.</p><table><tr><th>C</th><th>D</th></tr><tr><td>3</td><td>4</td></tr></table>','','Preserve both tables with intervening text; rich whole-output copy, not first-table-only.'),
('Table inline math','| Quantity | Formula |\n| --- | --- |\n| Energy | $E=mc^2$ |\n| Area | $A=\\pi r^2$ |','<table><tr><th>Quantity</th><th>Formula</th></tr><tr><td>Energy</td><td><span class="math" data-tex="E=mc^2"></span></td></tr><tr><td>Area</td><td><span class="math" data-tex="A=\\pi r^2"></span></td></tr></table>','','Distinguish formula semantics inside cells and target-specific copy limitation.'),
('Ambiguous glyphs','$$l_1+I_1+O_0+0=1$$','<div class="math display" data-display="1" data-tex="l_1+I_1+O_0+0=1"></div>','body {font-size:15px!important;}','Distinguish lower-case l, upper-case I, upper-case O, zero and one.'),
]
for i,(title,source,body,style,notes) in enumerate(boundary,1):add(f'B{i:02}','boundary',title,source,body,notes,style=style)
assert len(cases)==80
for case in cases:
    case['contentSHA256']=hashlib.sha256(json.dumps({k:case[k] for k in ('goldenMarkdown','fixtureBody','fixtureStyle','tableGrids','reviewNotes')},sort_keys=True,ensure_ascii=False).encode()).hexdigest()
OUT.mkdir(parents=True,exist_ok=True)
manifest={'schema':1,'version':'authored-v1','description':'Fixed original printed development Snippets. Independently authored expected content; not service output, not a representative private screenshot benchmark.','counts':{'formula':30,'table':20,'mixed':20,'boundary':10},'cases':cases}
(OUT/'manifest.json').write_text(json.dumps(manifest,ensure_ascii=False,indent=2)+'\n')
print('Golden Set manifest: 80 authored cases (30/20/20/10)')
