#!/usr/bin/env python3
"""Public report contract: unreviewed/missing results cannot pass the Golden Set."""
import importlib.util
import unittest
import hashlib
from pathlib import Path

spec = importlib.util.spec_from_file_location('report', Path(__file__).with_name('report.py'))
module = importlib.util.module_from_spec(spec)
spec.loader.exec_module(module)

class GoldenReportTests(unittest.TestCase):
    def test_unreviewed_results_keep_the_fixed_denominator(self):
        cases = [{'id': f'F{i:02}', 'category': 'formula', 'inputSHA256':'input'} for i in range(30)]
        cases += [{'id': f'T{i:02}', 'category': 'table', 'inputSHA256':'input'} for i in range(20)]
        cases += [{'id': f'M{i:02}', 'category': 'mixed', 'inputSHA256':'input'} for i in range(20)]
        cases += [{'id': f'B{i:02}', 'category': 'boundary', 'inputSHA256':'input'} for i in range(10)]
        report = module.summarize(cases, [], [], 'fast')
        self.assertEqual(report['ordinary']['total'], 70)
        self.assertEqual(report['ordinary']['passed'], 0)
        self.assertEqual(report['gate'], 'pending')
        self.assertEqual(report['boundary']['total'], 10)

    def test_stale_output_review_does_not_pass_modified_content(self):
        cases = [{'id': f'{prefix}{i:02}', 'category': category, 'inputSHA256':'input', 'contentSHA256':'truth'} for prefix,category,count in [('F','formula',30),('T','table',20),('M','mixed',20),('B','boundary',10)] for i in range(count)]
        binding={'corpusSHA256':'corpus','configurationSHA256':'config','artifactSHA256':'binary'}
        results = [dict(binding,**{'caseID':c['id'],'mode':'fast','inputSHA256':'input','contentSHA256':'truth','outputSHA256':'old-hash','status':'complete','canonicalMarkdown':'edited after review','complexTableHTML':None}) for c in cases]
        reviews = [dict(binding,**{'caseID':c['id'],'mode':'fast','inputSHA256':'input','contentSHA256':'truth','outputSHA256':'old-hash','reviewer':'independent reviewer','reviewedAt':'2026-10-21','notes':'Reviewed previous output','checks':{key:'pass' for key in ('meaning','layout','preview','copy','table_structure','canonical','correction')}}) for c in cases]
        report=module.summarize(cases,results,reviews,'fast',binding)
        self.assertEqual(report['gate'],'pending')
        self.assertEqual(report['ordinary']['passed'],0)

    def test_semantic_reviews_accept_equivalent_latex_and_enforce_category_floor(self):
        binding={'corpusSHA256':'corpus','configurationSHA256':'configuration','artifactSHA256':'binary'}
        cases=[{'id':f'{prefix}{i:02}','category':category,'inputSHA256':'input','contentSHA256':'truth','goldenMarkdown':r'$$\frac{1}{2}$$'} for prefix,category,count in [('F','formula',30),('T','table',20),('M','mixed',20),('B','boundary',10)] for i in range(count)]
        output=r'$$\dfrac{1}{2}$$'
        output_hash=hashlib.sha256((output+'\0').encode()).hexdigest()
        results=[dict(binding,caseID=c['id'],mode='fast',inputSHA256='input',contentSHA256='truth',outputSHA256=output_hash,status='complete',canonicalMarkdown=output,complexTableHTML=None) for c in cases]
        reviews=[dict(binding,caseID=c['id'],mode='fast',inputSHA256='input',contentSHA256='truth',outputSHA256=output_hash,reviewer='independent reviewer',reviewedAt='2026-10-21',notes='Equivalent fraction with display style; all required consumption reviewed',checks={key:'pass' for key in ('meaning','layout','preview','copy','table_structure','canonical','correction')}) for c in cases]
        for review in reviews[:3]:review['checks']['meaning']='fail'
        report=module.summarize(cases,results,reviews,'fast',binding)
        self.assertEqual(report['ordinary']['passed'],67)
        self.assertEqual(report['gate'],'pass')
        for review in reviews[:3]:review['checks']['meaning']='pass'
        for review in reviews[30:33]:review['checks']['table_structure']='fail'
        report=module.summarize(cases,results,reviews,'fast',binding)
        self.assertEqual(report['ordinary']['passed'],67)
        self.assertEqual(report['gate'],'fail')

    def test_actual_final_cost_cents_response_is_reported_with_provenance(self):
        cases=[{'id':f'{prefix}{i:02}','category':category,'inputSHA256':'input','contentSHA256':'truth'} for prefix,category,count in [('F','formula',30),('T','table',20),('M','mixed',20),('B','boundary',10)] for i in range(count)]
        binding={'corpusSHA256':'corpus','configurationSHA256':'config','artifactSHA256':'binary'}
        results=[dict(binding,caseID=cid,mode='fast',inputSHA256='input',contentSHA256='truth',status='complete',outputSHA256='unreviewed',canonicalMarkdown='x',costCents=None,costBreakdownJSON='{"final_cost_cents":0.40000000000000002}') for cid in ('F00','F01')]
        results[0]['wallSeconds']=2
        results[1]['wallSeconds']=4
        report=module.summarize(cases,results,[],'fast',binding)
        self.assertAlmostEqual(report['measurement']['knownCostCents'],0.8)
        self.assertEqual(report['measurement']['medianWallSeconds'],3)
        self.assertEqual(report['measurement']['costAvailableAttempts'],2)
        self.assertEqual(report['measurement']['costEvidence'][0]['source'],'cost_breakdown.final_cost_cents')

    def test_confirmed_failures_can_make_gate_impossible_before_all_reviews_arrive(self):
        cases=[{'id':f'{prefix}{i:02}','category':category,'inputSHA256':'input','contentSHA256':'truth'} for prefix,category,count in [('F','formula',30),('T','table',20),('M','mixed',20),('B','boundary',10)] for i in range(count)]
        binding={'corpusSHA256':'corpus','configurationSHA256':'config','artifactSHA256':'binary'}
        results=[dict(binding,caseID=f'F{i:02}',mode='fast',inputSHA256='input',contentSHA256='truth',status='failed',errorCode='timeout') for i in range(4)]
        report=module.summarize(cases,results,[],'fast',binding)
        self.assertEqual(report['ordinary']['failed'],4)
        self.assertEqual(report['ordinary']['pending'],66)
        self.assertEqual(report['ordinary']['total'],70)
        self.assertEqual(report['gate'],'fail')

if __name__ == '__main__': unittest.main()
