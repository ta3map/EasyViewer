# -*- coding: utf-8 -*-
"""One-shot: convert docs/**/*.md to standalone HTML via pandoc, then remove .md."""

from __future__ import annotations

import re
import subprocess
import sys
from pathlib import Path

DOCS_ROOT = Path(__file__).resolve().parents[1]
CSS = """
body { font-family: Arial, sans-serif; padding: 20px; line-height: 1.6; max-width: 960px; margin: 0 auto; }
h1 { color: #2c3e50; border-bottom: 2px solid #3498db; padding-bottom: 10px; }
h2 { color: #34495e; margin-top: 30px; }
h3 { color: #7f8c8d; }
code { background-color: #f4f4f4; padding: 2px 6px; border-radius: 3px; font-family: "Courier New", monospace; }
pre { background-color: #f4f4f4; padding: 15px; border-radius: 5px; overflow-x: auto; }
pre code { background-color: transparent; padding: 0; }
a { color: #3498db; text-decoration: none; }
a:hover { text-decoration: underline; }
ul, ol { margin-left: 20px; }
blockquote { border-left: 4px solid #3498db; padding-left: 15px; margin-left: 0; color: #7f8c8d; }
table { border-collapse: collapse; width: 100%; margin: 20px 0; }
table th, table td { border: 1px solid #ddd; padding: 8px; text-align: left; }
table th { background-color: #3498db; color: white; }
img { max-width: 100%; height: auto; }
"""


def first_heading(md_text: str) -> str:
    for line in md_text.splitlines():
        s = line.strip()
        if s.startswith("#"):
            return re.sub(r"^#+\s*", "", s)
    return ""


def rewrite_md_links(html: str) -> str:
    return re.sub(
        r'href="([^"]+)\.md(#[^"]*)?"',
        r'href="\1.html\2"',
        html,
    )


def convert(md_path: Path) -> Path:
    text = md_path.read_text(encoding="utf-8")
    title = first_heading(text) or md_path.stem
    html_path = md_path.with_suffix(".html")
    css_file = md_path.parent / "_docstyle.css"
    css_file.write_text(CSS, encoding="utf-8")

    subprocess.run(
        [
            "pandoc",
            str(md_path),
            "-f",
            "markdown",
            "-t",
            "html5",
            "-s",
            "--metadata",
            f"title={title}",
            f"--css={css_file.name}",
            "-o",
            str(html_path),
        ],
        check=True,
    )

    html = html_path.read_text(encoding="utf-8")
    html_path.write_text(rewrite_md_links(html), encoding="utf-8")
    return html_path


def main() -> int:
    md_files = sorted(DOCS_ROOT.rglob("*.md"))
    if not md_files:
        print("No markdown files found.")
        return 0

    for md in md_files:
        out = convert(md)
        print(f"OK  {md.relative_to(DOCS_ROOT)} -> {out.name}")
        md.unlink()
        print(f"DEL {md.relative_to(DOCS_ROOT)}")

    return 0


if __name__ == "__main__":
    sys.exit(main())
