# Workshop materials

26 slides: a title slide, a card for the opening live demo, a static copy of the Research, Plan,
Execute, Reflect loop, then 23 that need no live demo of their own. Two copies of the same deck:

| File | Use |
|---|---|
| **`deck-local.html`** | **Present from this one.** Double-click to open in any browser. Fully offline — typefaces are embedded, nothing is fetched from the network. |
| `deck.html` | Source for the hosted version. Has no `<head>` of its own (that is supplied when published), and loads its typefaces from Google Fonts. |

Edit `deck.html`, then regenerate `deck-local.html` from it — see the bottom of this file.

| Key | |
|---|---|
| `→` `␣` | next slide — or the next reveal, on a slide that has one |
| `←` | previous |
| `F` | fill the screen — hides the rail, slide edge to edge |
| `T` | light / dark |
| `?` | shortcuts |

Deep-link to any slide with `#12`. Slides whose parts are revealed one click at a time mark each
part with `data-step="1"`, `data-step="2"`, and so on; arriving from the previous slide starts
them hidden, arriving backwards from the next slide starts them all shown. Adding `data-exact`
makes a part a moving highlight instead — lit on its own step only, so the one before it dims
again. That is how slide 8 walks the four phases. Slide 3 is the same loop with no reveals — all
four phases lit from the start, shown up front before the study is introduced.

## Presenting

Drag the deck window to the projector and press **`F`**. The rail and the surrounding margin go,
the letterbox takes the slide's own background colour, and the slide grows by about 25%.

A PDF of the slides, with every reveal shown, is in `slides/Reproducing-a-published-paper-slides.pdf`
at the root of this repository.

## Running order

Written for a mixed scientific audience: no genetics background assumed, and every term the figures
need is defined on the slide that first uses it. Slides carry bullets only.

**Part A — the destination (4–7).** The study design in one slide — the trial nobody will fund
beside the one nature is already running, drawn as the same four rows so the only difference is
what does the randomising. It builds in three clicks: the Mendelian randomisation half, then
one-sample MR, then two-sample MR — the split that decides what can be reproduced from public
data. Then the paper's headline result, then ours beside the paper's own two-sample arm.

**Part B — how it was built (8–23).** Slide 8 is the framework itself: all four phases are on
screen from the start, greyed, and one click each lights Research, Plan, Execute and then Reflect,
which brings the loop-back arrow with it. The rest tells those phases as the exchanges
themselves: each slide carries the prompt (or its absence, where Claude was checking its own
output) and what came back. Slides in the Execute and Reflect phases are tagged with the phase of
`plan.md` the work belongs to.

The beats: the dataset audit, the rest of what `research.md` fixed in advance, the plan and its
four "done" bars, what three phases of building produced, the known-answer check, overlapping
participants, where more cases come from, two kinds of null result, skills and reading the
rendered page, and the word "divergence".

Slide 9 is the only one showing the Claude Code interface; every later exchange uses the compact
prompt / response form. Every exchange slide builds a turn per click, so a prompt can be read out
before its answer appears.

Slide 21 is a case where the fact base itself was wrong — Claude recorded unspecified dementia as
unavailable in FinnGen R12, and it was not. The point of it is that no amount of reading the
*output* would have found it.

Three forest plots are drawn inside the deck — the paper's one-sample result, our reproduction
beside the paper's two-sample arm, and the heart-disease check — so no tab switching is needed.
The reproduction plot appears twice: once in Part A as the destination, and again on slide 15
right after the positive control (its own mount id, `fig-2smr-b`, since ids must be unique).
Slide 22 carries its lower five rows a third time, as a cropped screenshot, so the CETP row is on
screen while the wording about it is being corrected.

## The record underneath

The deck pulls its exchanges from the project history, but shows only a dozen of them. The full
record — every prompt, and what Claude did in response — is in `conversation.md` at the root of
this folder.

## Regenerating the local copy

`deck-local.html` is `deck.html` wrapped in a real HTML document with the three typefaces
(Newsreader, IBM Plex Sans, IBM Plex Mono) embedded as base64 `@font-face` rules, so it renders
identically with no network. That is why it is ~420 KB rather than ~73 KB.

After editing `deck.html`, rebuild it with `workshop/build-local.py`:

```bash
python3 workshop/build-local.py
```

The script re-downloads the latin subsets from Google Fonts (needs network *once*, at build
time), deduplicates the variable-font files, and writes `deck-local.html`.
