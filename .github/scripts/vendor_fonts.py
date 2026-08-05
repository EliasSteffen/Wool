#!/usr/bin/env python3
"""Vendor the site's webfonts at build time so visitors never contact Google.

A Google Fonts <link> makes every visitor's browser fetch the stylesheet from
fonts.googleapis.com and the font files from fonts.gstatic.com, which hands
their IP address to Google before a single pixel renders - on the privacy
policy page as much as anywhere else. This downloads both halves once, during
deploy, and rewrites the stylesheet to point at the local copies.

The pages link /fonts.css; the url() paths inside it stay relative to that
file, so the same stylesheet works from the site root and from subpages.

Usage:
    python3 .github/scripts/vendor_fonts.py public
"""

from __future__ import annotations

import argparse
import pathlib
import re
import sys
import urllib.request

FONT_CSS_URL = (
    "https://fonts.googleapis.com/css2"
    "?family=Inter:wght@400;500;600;700;800&display=swap"
)

# Google serves woff2 only to user agents it believes support it, and falls back
# to far larger ttf otherwise. Asking as a current browser is what keeps the
# vendored files small.
USER_AGENT = (
    "Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 "
    "(KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36"
)

GSTATIC_URL = re.compile(r"url\((https://fonts\.gstatic\.com/[^)]+)\)")
GOOGLE_HOSTS = ("fonts.googleapis.com", "fonts.gstatic.com")


def fetch(url: str) -> bytes:
    request = urllib.request.Request(url, headers={"User-Agent": USER_AGENT})
    with urllib.request.urlopen(request, timeout=30) as response:
        return response.read()


def vendor(output_dir: pathlib.Path) -> int:
    font_dir = output_dir / "fonts"
    font_dir.mkdir(parents=True, exist_ok=True)

    css = fetch(FONT_CSS_URL).decode("utf-8")

    urls = sorted(set(GSTATIC_URL.findall(css)))
    if not urls:
        # Never ship a stylesheet that still calls out to Google because the
        # response shape changed - failing the build is the safe direction.
        raise SystemExit("no fonts.gstatic.com urls in the stylesheet; refusing to continue")

    for url in urls:
        name = url.rsplit("/", 1)[-1].split("?")[0]
        if "." not in name:
            name += ".woff2"
        (font_dir / name).write_bytes(fetch(url))
        css = css.replace(url, f"fonts/{name}")

    leftover = [host for host in GOOGLE_HOSTS if host in css]
    if leftover:
        raise SystemExit(f"stylesheet still references {', '.join(leftover)}")

    (output_dir / "fonts.css").write_text(css, encoding="utf-8")
    return len(urls)


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument(
        "output_dir",
        type=pathlib.Path,
        help="assembled site directory; fonts.css and fonts/ are written here",
    )
    args = parser.parse_args()

    count = vendor(args.output_dir)
    print(f"vendored {count} font files into {args.output_dir}/fonts/", file=sys.stderr)


if __name__ == "__main__":
    main()
