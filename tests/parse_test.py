#!/usr/bin/env python3
"""The Markdown formats tools/cards understands, one assertion each."""
import os, sys, tempfile
from importlib.machinery import SourceFileLoader

here = os.path.dirname(os.path.abspath(__file__))
cards = SourceFileLoader("cards", os.path.join(here, "..", "tools", "cards")).load_module()


def parse(text, name="Deck.md"):
    d = tempfile.mkdtemp()
    os.makedirs(os.path.dirname(os.path.join(d, name)), exist_ok=True)
    with open(os.path.join(d, name), "w", encoding="utf-8") as f:
        f.write(text)
    return cards.load_cards(d)


checks = 0
def eq(a, b):
    global checks
    checks += 1
    assert a == b, "\n  got:  %r\n  want: %r" % (a, b)


decks, cs, probs = parse("q1::a1\nq2:::a2\n\nlong\nfront\n?\nback\nmore\n\nboth\n??\nways\n")
eq([(c["front"], c["back"]) for c in cs], [
    ('<div class="big"><p>q1</p></div>', '<div class="big"><p>a1</p></div>'),
    ('<div class="big"><p>q2</p></div>', '<div class="big"><p>a2</p></div>'),
    ('<div class="big"><p>a2</p></div>', '<div class="big"><p>q2</p></div>'),
    ("<p>long<br>front</p>", "<p>back<br>more</p>"),
    ('<div class="big"><p>both</p></div>', '<div class="big"><p>ways</p></div>'),
    ('<div class="big"><p>ways</p></div>', '<div class="big"><p>both</p></div>')])
eq(cs[2]["note"], cs[1]["id"])                                                    # reverse cards are siblings of the forward one
eq(decks, ["Deck"])
eq(parse("x::y", "Lang/Japanese/N5.md")[0], ["Lang/Japanese/N5"])               # subfolders name the deck
eq(cards.inline("日本語[にほんご]を勉強[べんきょう]する"), "<ruby>日本語<rt>にほんご</rt></ruby>を<ruby>勉強<rt>べんきょう</rt></ruby>する")
eq(cards.inline("食[た]べる"), "<ruby>食<rt>た</rt></ruby>べる")
eq(cards.inline("私の 名前[なまえ]"), "私の<ruby>名前<rt>なまえ</rt></ruby>")       # Anki's space delimiter
eq(cards.inline("I like 寿司[すし]"), "I like <ruby>寿司<rt>すし</rt></ruby>")      # but a real space stays
eq(cards.inline("a[i] and [link](http://x)"), "a[i] and <u>link</u>")           # brackets that aren't furigana
eq(cards.inline("**b** *i* _i_ `a::b` ~~s~~ ==m== snake_case_name"), "<b>b</b> <i>i</i> <i>i</i> <code>a::b</code> <s>s</s> <mark>m</mark> snake_case_name")
eq(cards.inline("<script>&"), "&lt;script&gt;&amp;")
eq(cards.inline("one<br>two"), "one<br>two")
eq(cards.render(["- a", "- b", "1. c"]), "<ul><li>a</li><li>b</li></ul><ol><li>c</li></ol>")
eq(cards.render(["```", "x = 1", "", "y", "```"]), "<pre>x = 1\n\ny</pre>")
eq(parse("`std::vector`::a growable array")[1][0]["front"], '<div class="big"><p><code>std::vector</code></p></div>')   # :: inside code isn't the split
eq(len(parse("---\ntags: x::y\n---\n# Title\n#flashcards\nq::a\n<!-- old::comment -->\n")[1]), 1)   # front matter, headings, tags, comments skipped
eq(parse("## Heading\nthe front\nof a card\n?\nback")[1][0]["front"], "<p>the front<br>of a card</p>")             # heading above a card is context
_, cs, probs = parse("same::one\nsame::two\n::nothing\n\nq\n?\n")
eq(sorted(p[1].split(",")[0] for p in probs), sorted(["same front as Deck.md:1", ":: with nothing on one side", "a lone ? with nothing after it"]))
eq(len(set(c["id"] for c in cs)), 2)                                               # duplicates still get distinct ids
a = parse("water::水[みず]")[1][0]["id"]; b = parse("water::水[みず]です")[1][0]["id"]; c = parse("**water**::水")[1][0]["id"]
eq(a == b == c, True)                                                              # editing the back or formatting keeps the id
eq(parse("猫::cat")[1][0]["id"] == parse("猫[ねこ]::cat")[1][0]["id"], True)        # so does adding furigana
eq(parse("water::x")[1][0]["id"] != parse("waters::x")[1][0]["id"], True)
print("parse_test: %d checks passed" % checks)
