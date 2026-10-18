# Cards

Flashcards for the iPod touch 4, written in Markdown on the Mac. Every file in `~/Cards` is a deck. `cards sync` sends them over USB and brings the answers back. Scheduling is FSRS-5, the algorithm Anki now uses, with Anki's learning steps: a new card comes back after 1 and 10 minutes before it moves to days.

## Writing cards

The formats are the ones Obsidian's Spaced Repetition plugin reads, so the same notes work there too.

```
水[みず]::water                  one card
猫[ねこ]:::cat                   two cards, one each way

What carries over from Markdown?
?
- **bold**, *italics*, `code`
- lists and line breaks
```

A multi-line card is the lines before a lone `?`, then the lines after it, up to the next blank line; `??` makes it go both ways. Furigana is written Anki-style, `日本語[にほんご]`, and shows above the kanji. Folders group decks: `Japanese/N5 Vocab.md` is the deck "N5 Vocab" under "Japanese". Headings, `#tags`, front matter and HTML comments are skipped.

A card is known by its front, minus formatting and furigana. Fixing a typo on the back or adding a reading keeps its history; rewording the front makes it a new card. `cards check` lists the decks and anything it couldn't read, such as two cards with the same front.

## Syncing

- `cards sync` with the iPod plugged in. It starts `iproxy 2222 22` if it isn't running. `--host 192.168.1.x` goes over Wi-Fi instead, as long as the iPod is awake.
- `cards stats` shows what's due, as of the last sync.
- `CARDS_DIR` or `--dir` points somewhere other than `~/Cards`.

## How it works

- The Mac owns the cards. `tools/cards` turns the Markdown into HTML and swaps `cards.json` into the app's Documents over ssh.
- The iPod owns the answers. Each Again, Hard, Good or Easy appends one line to `reviews.jsonl`, and Undo appends a line that cancels the last one. No schedule is stored: the app rebuilds every card's schedule by replaying the log through FSRS, so there is only one record to keep safe.
- Each sync copies that log to `~/Cards/.cards/reviews.jsonl` and appends anything the iPod is missing. After a reinstall, one sync brings all the history back. Nothing on the iPod is ever deleted or rewritten.
- The fuzz that spreads reviews over nearby days is seeded by each answer's id, so the iPod and `cards stats` replay the log to the same dates.
- The day turns over at 4 am. The new-card and review limits are per deck, and set in Settings along with the retention FSRS aims for (90%). Once you answer one side of a reversed card, the other side waits for tomorrow.

## Layout

- `src/CDFSRS.c` is the scheduler in plain C. `tools/cards` has the same code in Python.
- `src/CDStore` reads the two files, replays the log, picks the next card and appends answers.
- `src/CDViewControllers` is the deck list, the study screen (each card is an index card in a UIWebView, so ruby and lists render) and Stats.
- `tools/cards` is the Mac command, Python 3 standard library only. `~/.local/bin/cards` links to it.
- `res/mkicon.swift` draws the icon.

## Tests

`tests/run.sh` runs everything that doesn't need the iPod:

- `parse_test.py` covers the Markdown formats.
- `crosscheck.py` runs 2,000 random review histories through the C scheduler and the Python one. Every number has to match.
- `store_check.py` builds `CDStore` for the Mac and replays a month of answers, with undos, a duplicated line and a torn last line, against `tools/cards`.
- `vs_pyfsrs.py` holds the Python scheduler to the reference py-fsrs 5.1.3 when that package is installed.

## Building

Targets iOS 4.3 on armv7 from a modern Mac with only the Command Line Tools installed, like the other iPod apps. No Xcode.

1. Put an iPhoneOS 4.3 SDK at `/Users/mshukla/ios4sdk/iPhoneOS4.3.sdk`, with its frameworks turned into text stubs once (`tapi stubify`, then retarget `-darwin` to `-ios`).
2. `./build.sh` compiles with `clang -target armv7-apple-ios4.3`, signs with `ldid -S`, and zips `build/Cards.ipa`.
3. Install with `ideviceinstaller install build/Cards.ipa` on a jailbroken device with AppSync.

## License

MIT.
