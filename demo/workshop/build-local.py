#!/usr/bin/env python3
"""Wrap deck.html into a standalone, fully offline deck-local.html.

deck.html is authored for the Artifact host, which supplies <!doctype>/<head> and permits
Google Fonts. This script produces a self-contained document instead: a real HTML shell, an
emoji favicon, and the three typefaces embedded as base64 @font-face rules, so the deck
renders identically with the network unplugged.

Needs network once, at build time, to fetch the font subsets.
"""
import base64
import collections
import pathlib
import re
import urllib.parse
import urllib.request

HERE = pathlib.Path(__file__).resolve().parent
SRC = HERE / "deck.html"
DST = HERE / "deck-local.html"
UA = {"User-Agent": "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) "
                    "AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120 Safari/537.36"}
FAVICON = "\U0001F9EC"


def fetch(url, headers=UA):
    return urllib.request.urlopen(urllib.request.Request(url, headers=headers)).read()


def inline_fonts(css_url):
    """Return @font-face rules with the latin subsets embedded as data URIs."""
    css = fetch(css_url).decode()
    blocks = [b for b in re.findall(r"@font-face\s*\{[^}]*\}", css) if "U+0000-00FF" in b]
    if not blocks:
        raise SystemExit("no latin @font-face blocks found — did the Google CSS format change?")

    # Google emits one block per weight, but variable fonts share a single file. Group by
    # (family, style, url) so each file is downloaded and embedded exactly once, and collapse
    # the weights it covers into a range.
    groups = collections.OrderedDict()
    for b in blocks:
        key = (re.search(r"font-family: '([^']+)'", b).group(1),
               re.search(r"font-style: ([^;]+);", b).group(1).strip(),
               re.search(r"url\((https://[^)]+\.woff2)\)", b).group(1))
        groups.setdefault(key, []).append(int(re.search(r"font-weight: (\d+)", b).group(1)))

    rules = []
    for (family, style, url), weights in groups.items():
        data = fetch(url)
        weight = str(weights[0]) if len(weights) == 1 else f"{min(weights)} {max(weights)}"
        rules.append(
            f"@font-face{{font-family:'{family}';font-style:{style};font-weight:{weight};"
            f"font-display:swap;src:url(data:font/woff2;base64,"
            f"{base64.b64encode(data).decode()}) format('woff2')}}")
        print(f"  {family:16s} {style:7s} weight {weight:9s} {len(data)/1024:6.1f} KB")
    return "\n".join(rules)


def main():
    body = SRC.read_text()

    link = re.search(r'<link rel="stylesheet" href="(https://fonts\.googleapis\.com[^"]+)"', body)
    if not link:
        raise SystemExit("no Google Fonts <link> in deck.html — nothing to inline")
    print("embedding typefaces:")
    fonts = inline_fonts(link.group(1))

    body = re.sub(r'<link rel="preconnect"[^>]*>\n', "", body)
    body = re.sub(r'<link rel="stylesheet" href="https://fonts\.googleapis\.com[^>]*>\n', "", body)
    title = re.search(r"<title>(.*?)</title>", body).group(1)
    body = re.sub(r"<title>.*?</title>\n", "", body)

    svg = ('<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 100 100">'
           f'<text y=".9em" font-size="90">{FAVICON}</text></svg>')
    icon = "data:image/svg+xml," + urllib.parse.quote(svg)

    DST.write_text(f'''<!doctype html>
<html lang="en">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>{title}</title>
<link rel="icon" href="{icon}">
<style>
{fonts}
</style>
{body}</body>
</html>
''')

    # requires a host character after the scheme, so a bare "https://" in prose does not trip it.
    # <a href> targets are exempt: a link the presenter may click is not a request the page makes.
    out = re.sub(r'<a\s[^>]*?href="https?://[^"]*"', '<a', DST.read_text())
    leftover = [u for u in re.findall(r'https?://[\w.-]+[^"\' )]*', out)
                if "www.w3.org/2000/svg" not in u]
    if leftover:
        raise SystemExit(f"still references the network: {sorted(set(leftover))}")
    print(f"wrote {DST.name} — {DST.stat().st_size/1024:.0f} KB, no external requests")


if __name__ == "__main__":
    main()
