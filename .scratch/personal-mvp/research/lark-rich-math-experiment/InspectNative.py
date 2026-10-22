import base64, collections, html.parser, json, re, sys, urllib.parse

raw = json.load(sys.stdin)
known = {'x^2', r'\frac{a}{b}', 'y = x + 1', 'u^2+v^2', 'u^2 + v^2', 'z_0', r'\frac{1}{2}'}

def scrub(value):
    if isinstance(value, dict):
        return {re.sub(r'[0-9]{10,}|[a-f0-9]{8}-(?:[a-f0-9]{4}-){3}[a-f0-9]{12}|[A-Za-z0-9]{27}', '<id>', k): scrub(v) for k, v in value.items()}
    if isinstance(value, list): return [scrub(v) for v in value[:30]]
    if isinstance(value, str):
        if value in known: return value
        value = re.sub(r'https?[^\s\"<>]+', '<url>', value)
        return re.sub(r'[A-Za-z0-9_-]{16,}', '<id-or-opaque>', value)[:500]
    if isinstance(value, (int, float)) and abs(value) > 1_000_000: return 0
    return value

class Inspector(html.parser.HTMLParser):
    def __init__(self):
        super().__init__(); self.tags = collections.Counter(); self.nodes = []; self.math_node = None; self.schema = {}
    def handle_starttag(self, tag, attrs):
        self.tags[tag] += 1
        attrs = dict(attrs)
        relevant = tag in ('table', 'td', 'th') or any(re.search('equation|formula|math|sheet|table', v or '', re.I) for v in attrs.values())
        if not relevant or len(self.nodes) >= 250: return
        safe = {}
        meta_shape = {}
        for k, value in attrs.items():
            if k == 'data-lark-record-data':
                record = json.loads(value)
                examples = {}
                keys = {}
                math_text = []
                mark_names = set()
                for item in record.get('recordMap', {}).values():
                    snapshot = item.get('snapshot', {})
                    kind = snapshot.get('type', 'unknown')
                    for pair in snapshot.get('text', {}).get('apool', {}).get('numToAttrib', {}).values():
                        if isinstance(pair, list) and len(pair) == 2 and pair[0] not in ('author', 'objectID', 'equation'): mark_names.add(tuple(pair))
                    keys[kind] = sorted(snapshot.keys())
                    clean = {key: val for key, val in snapshot.items() if not re.search('author|editor|doc_info|revision|comment|time|token|url|link', key, re.I)}
                    if kind not in examples: examples[kind] = scrub(clean)
                    if kind == 'text' and 'Before ' in str(snapshot.get('text', '')):
                        math_text.append(scrub(clean))
                self.schema = {'snapshot_keys': keys, 'examples': examples, 'math_text_examples': math_text[:1], 'style_attributes': sorted(mark_names)}
                safe[k] = {'present': True, 'owner_metadata_retained': False}
                continue
            if re.search('record|data', k) and value and len(value) > 150:
                decoded = None
                encoding = "opaque"
                for encoding_name, candidate in (("json", value), ("uri-json", urllib.parse.unquote(value))):
                    try: decoded = json.loads(candidate); encoding = encoding_name; break
                    except (ValueError, TypeError): pass
                    try: decoded = json.loads(base64.b64decode(candidate)); encoding = "base64-json"; break
                    except (ValueError, TypeError, UnicodeError): pass
                if k == "data-meta-block-props" and isinstance(decoded, dict):
                    bid = str(decoded.get("blockId", ""))
                    meta_shape = {"encoding": encoding, "block_id_length": len(bid), "block_id_numeric": bid.isdigit(), "block_id_prefix": "numeric" if bid.isdigit() else bid[:5]}
                safe[k] = scrub(decoded) if decoded is not None else {'opaque_bytes': len(value)}
            else:
                safe[k] = value if k == 'class' and value == 'lark-record-clipboard' else scrub(value)
        self.nodes.append({'tag': tag, 'attributes': safe, 'meta_shape': meta_shape})
        if meta_shape: self.math_node = self.nodes[-1]
    def handle_data(self, data):
        if self.math_node is not None: self.math_node['inner_text'] = self.math_node.get('inner_text', '') + scrub(data)
    def handle_endtag(self, tag):
        if tag == 'span': self.math_node = None

p = Inspector(); p.feed(raw['html'])
print(json.dumps({'types': raw['types'], 'custom_keys': raw.get('customKeys', []), 'tags': p.tags, 'relevant_nodes': p.nodes, 'schema': p.schema}, ensure_ascii=False, indent=2))
