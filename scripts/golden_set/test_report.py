#!/usr/bin/env python3
"""Public report contract: unreviewed/missing results cannot pass the Golden Set."""
import importlib.util
import unittest
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

if __name__ == '__main__': unittest.main()
