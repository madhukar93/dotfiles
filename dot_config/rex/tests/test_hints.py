"""Unit tests for ../bin/rex-hints' matching and hint assignment. Run: python3 -I ~/.config/rex/tests/test_hints.py"""
import importlib.machinery
import importlib.util
import pathlib
import unittest

script = pathlib.Path(__file__).resolve().parent.parent / "bin" / "rex-hints"
loader = importlib.machinery.SourceFileLoader("rex_hints", str(script))
spec = importlib.util.spec_from_loader("rex_hints", loader)
rex_hints = importlib.util.module_from_spec(spec)
loader.exec_module(rex_hints)
find_matches, assign_hints, render = rex_hints.find_matches, rex_hints.assign_hints, rex_hints.render


def found(line):
    return [(m["kind"], m["text"]) for m in find_matches([line])]


class FindMatchesTest(unittest.TestCase):
    def test_url(self):
        self.assertEqual(found("see https://example.com/a?b=1 now"), [("url", "https://example.com/a?b=1")])

    def test_url_is_not_also_a_path(self):
        self.assertEqual(len(found("https://example.com/some/path")), 1)

    def test_paths(self):
        self.assertEqual(found("edit ~/.config/rex/init.lua and src/main.go:"),
                         [("path", "~/.config/rex/init.lua"), ("path", "src/main.go")])

    def test_git_hash_and_plain_word(self):
        self.assertEqual(found("commit 4eab2ac Move decade"), [("sha", "4eab2ac")])

    def test_ip_with_port(self):
        self.assertEqual(found("listening on 127.0.0.1:8080"), [("ip", "127.0.0.1:8080")])

    def test_uuid_is_one_match(self):
        self.assertEqual(found("block:01a20931-0375-789b-9c11-3698ba9ef5de"),
                         [("uuid", "01a20931-0375-789b-9c11-3698ba9ef5de")])

    def test_long_number_but_not_short(self):
        self.assertEqual(found("pid 27912 exit 1"), [("number", "27912")])

    def test_positions(self):
        m = find_matches(["nothing here", "  see src/a.go"])[0]
        self.assertEqual((m["row"], m["col"]), (1, 6))

    def test_same_text_twice_is_two_matches(self):
        self.assertEqual(len(find_matches(["src/a.go src/a.go"])), 2)


class AssignHintsTest(unittest.TestCase):
    def matches(self, n):
        return [{"row": i, "col": 0, "text": "x" * 8, "kind": "path"} for i in range(n)]

    def test_bottom_match_gets_first_key(self):
        ms = assign_hints(self.matches(3))
        self.assertEqual([m["hint"] for m in ms], ["d", "s", "a"])

    def test_many_matches_get_two_letter_hints_none_a_prefix_of_another(self):
        hints = [m["hint"] for m in assign_hints(self.matches(40))]
        self.assertEqual(len(set(hints)), 40)
        self.assertTrue(all(len(h) == 2 for h in hints))


class RenderTest(unittest.TestCase):
    def test_hint_replaces_start_of_match_and_keeps_columns(self):
        lines = ["go to src/a.go now"]
        ms = assign_hints(find_matches(lines))
        import re
        plain = re.sub(r"\x1b\[[0-9;?]*[A-Za-z]", "", render(lines, ms, "", 80, 24))
        self.assertEqual(plain, "go to arc/a.go now")

    def test_fewer_rows_than_the_pane_shows_the_bottom_lines(self):
        lines = ["top src/a.go", "middle", "bottom src/b.go"]
        ms = assign_hints(find_matches(lines))
        out = render(lines, ms, "", 80, 2)
        self.assertNotIn("top", out)
        self.assertIn("\x1b[2;1H", out)  # the last line is drawn on the picker's row 2
        self.assertIn("bottom", out)

    def test_status_line_is_drawn_on_the_bottom_row(self):
        out = render(["src/a.go"], assign_hints(find_matches(["src/a.go"])), "", 80, 24, " 1 hints ")
        self.assertIn("\x1b[24;1H\x1b[0;7m 1 hints ", out)

    def test_matches_ruled_out_by_typed_letters_lose_their_hint(self):
        lines = ["src/a.go src/b.go"]
        ms = assign_hints(find_matches(lines))
        import re
        plain = re.sub(r"\x1b\[[0-9;?]*[A-Za-z]", "", render(lines, ms, "a", 80, 24))
        self.assertEqual(plain, "src/a.go arc/b.go")


if __name__ == "__main__":
    unittest.main(verbosity=1)
