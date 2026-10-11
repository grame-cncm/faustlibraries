"""Regression checks for arity-only Usage evaluation; requires faust on PATH."""
import shutil
import sys
import tempfile
import unittest
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[1] / "scripts"))
import check_usage


@unittest.skipUnless(shutil.which("faust"), "faust not installed")
class UsageEvaluationTests(unittest.TestCase):
    def evaluate(self, expr, bindings=None):
        sym = {"qname": "ef.transpose_correlated", "prefix": "ef",
               "file": "misceffects.lib", "test": ""}
        prefixes = {"ef": "misceffects.lib", "ma": "maths.lib"}
        with tempfile.TemporaryDirectory() as workdir:
            return check_usage.evaluate(sym, expr, bindings or {}, [], prefixes,
                                        workdir, [])

    def counts(self, expr, inputs, outputs, bindings=None):
        text, failure = self.evaluate(expr, bindings)
        self.assertIsNone(failure)
        self.assertRegex(text, rf"=\s*{inputs}\s*,\s*{outputs}\s*;")

    def test_large_feedback_graph(self):
        # Printing this graph with plain faust -e exceeds the Usage timeout.
        self.counts("_ : ef.transpose_correlated(w,s) : _", 1, 1,
                    {"w": "0.030*ma.SR", "s": "-12"})

    def test_mono(self):
        self.counts("_ : +(1) : _", 1, 1)

    def test_sink(self):
        self.counts("_ : !", 1, 0)

    def test_bus_mismatches(self):
        for expr in ("_,_ : +(1) : _", "_ : +(1) : _,_",
                     "_,_,_ <: _,_", "(_,_ ) ~ (_,_,_)"):
            with self.subTest(expr=expr):
                _, failure = self.evaluate(expr)
                self.assertIsNotNone(failure)
                self.assertEqual(failure[0], "arity")

    def test_unknown_function(self):
        _, failure = self.evaluate("unknown_function(1) : _")
        self.assertIsNotNone(failure)

    def test_syntax_error(self):
        _, failure = self.evaluate("(_ :")
        self.assertIsNotNone(failure)
        self.assertEqual(failure[0], "syntax")


if __name__ == "__main__":
    unittest.main()
