"""Unit tests for ../bin/rex-extrakto's text extraction. Run: python3 -I ~/.config/rex/tests/test_extrakto.py"""
import importlib.machinery
import importlib.util
import pathlib
import unittest

script = pathlib.Path(__file__).resolve().parent.parent / "bin" / "rex-extrakto"
loader = importlib.machinery.SourceFileLoader("rex_extrakto", str(script))
spec = importlib.util.spec_from_loader("rex_extrakto", loader)
rex_extrakto = importlib.util.module_from_spec(spec)
loader.exec_module(rex_extrakto)
candidates = rex_extrakto.candidates


class CandidatesTest(unittest.TestCase):
    def test_order_is_urls_paths_words_then_lines(self):
        got = candidates("see https://example.com/a and ~/src/app.py now")
        self.assertEqual(got[:3], ["https://example.com/a", "~/src/app.py", "see"])
        self.assertEqual(got[-1], "see https://example.com/a and ~/src/app.py now")

    def test_most_recent_line_comes_first(self):
        got = candidates("older-word\nnewer-word\n")
        self.assertLess(got.index("newer-word"), got.index("older-word"))

    def test_strips_surrounding_quotes_and_punctuation(self):
        self.assertIn("main.go", candidates('error in "main.go", line 3'))

    def test_drops_short_tokens_and_duplicates(self):
        got = candidates("ok ok deploy deploy")
        self.assertNotIn("ok", got)
        self.assertEqual(got.count("deploy"), 1)

    def test_url_not_listed_again_as_path(self):
        got = candidates("open https://example.com/x")
        self.assertEqual(got.count("https://example.com/x"), 1)

    def test_lines_only_keeps_whole_lines_most_recent_first(self):
        got = candidates("first line here\n  second line here  \nfirst line here\n", "lines")
        self.assertEqual(got, ["first line here", "second line here"])

    def test_empty_screen(self):
        self.assertEqual(candidates("\n\n"), [])


if __name__ == "__main__":
    unittest.main(verbosity=1)
