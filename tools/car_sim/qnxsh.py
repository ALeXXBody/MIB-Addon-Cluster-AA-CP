#!/usr/bin/env python3
"""qnxsh — execute payload scripts with QNX Neutrino sh errexit semantics.

Measured unit fact (v0.7.5 car round): the unit's sh exits the whole script
(rc=1, no message) when a command substitution fails, EVEN inside a function
that was called from an `if` condition. dash/bash/mksh/busybox-ash/zsh/posh
all suppress errexit there (verified empirically: every one of them prints
"survived" for the probe in test_qnxsh.py), so the sim stayed green while
the car died silently after jsonlint-OK.

qnxsh closes exactly that divergence: it rewrites bare single-command
substitutions `VAR=`cmd`` / `VAR=$(cmd)` (no pipe, no existing `||` guard,
not itself in a condition/`&&` chain) to `VAR=`cmd` || exit 127` and then
runs the result under plain sh. Guarded lines are byte-identical, so a
qnxsh run differs from a plain-sh run ONLY where the unit would have died.
A qnxsh death (rc=127) is therefore the unit's silent death, made loud.
"""
import pathlib
import re
import sys

EXIT_CODE = 127


def transform_line(line):
    """Insert `|| exit 127` after every bare single-command substitution."""
    out = line.rstrip('\n')
    for pat in (r'[A-Za-z_][A-Za-z0-9_]*=`[^`]*?`',
                r'[A-Za-z_][A-Za-z0-9_]*=\$\([^()]*\)'):
        while True:
            m = re.search(pat, out)
            if not m:
                break
            span = m.group(0)
            inner = span.split('=', 1)[1]
            body = inner[1:-1] if inner.startswith('`') else inner[2:-1]
            if '|' in body:
                break  # piped: pipeline rc is the last stage — safe
            context = (out[:m.start()] + ' ' + out[m.end():]).strip()
            if ('||' in context or '&&' in context
                    or re.match(r'^(if|elif|while|until)\b', context)):
                break  # already guarded or the assignment is a condition
            out = out[:m.end()] + f' || exit {EXIT_CODE}' + out[m.end():]
    if out == line.rstrip('\n'):
        return line
    return out + '\n'


def transform_text(text):
    return ''.join(transform_line(ln + '\n') for ln in text.splitlines())


def transform_file(path):
    p = pathlib.Path(path)
    before = p.read_text()
    after = transform_text(before)
    if after != before:
        p.write_text(after)
        return True
    return False


def transform_tree(root):
    """Rewrite every *.sh under root in place. Returns count changed."""
    n = 0
    for p in sorted(pathlib.Path(root).rglob('*.sh')):
        if transform_file(p):
            n += 1
    return n


if __name__ == '__main__':
    # qnxsh.py <file...> : rewrite files in place, print what changed.
    changed = 0
    for arg in sys.argv[1:]:
        if transform_file(arg):
            print(f"qnxsh: guarded {arg}")
            changed += 1
    print(f"qnxsh: {changed} file(s) rewritten")
