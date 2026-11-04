"""Fail if this branch or uncommitted changes include paths outside AI/."""
from pathlib import Path
import subprocess
import sys


def git(*args, cwd):
    return subprocess.check_output(['git', *args], cwd=cwd)


def main():
    location = Path(__file__).resolve().parent
    root = Path(git('rev-parse', '--show-toplevel', cwd=location).decode().strip())
    base = sys.argv[1] if len(sys.argv) > 1 else 'origin/main'
    paths = set()
    for args in [('diff', '--name-only', '-z', f'{base}...HEAD'),
                 ('diff', '--name-only', '-z', 'HEAD'),
                 ('ls-files', '--others', '--exclude-standard', '-z')]:
        paths.update(p for p in git(*args, cwd=root).decode().split('\0') if p)
    outside = sorted(p for p in paths if not p.startswith('AI/'))
    if outside:
        print('AI-only scope check failed:\n' + '\n'.join(outside))
        return 1
    print(f'AI-only scope check passed: {len(paths)} changed paths, all under AI/.')
    return 0


if __name__ == '__main__':
    raise SystemExit(main())
