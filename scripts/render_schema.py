"""Generate the initial reference snapshot, not a second migration history."""
import argparse
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
SOURCE = ROOT / 'alembic/versions/0001_initial.sql'
TARGET = ROOT / 'database/mariadb/schema.sql'


def statements(sql: str) -> list[str]:
    """Split repository DDL (no routines, delimiters, or semicolons in strings)."""
    lines = [line for line in sql.splitlines() if not line.lstrip().startswith('--')]
    return [part.strip() for part in '\n'.join(lines).split(';') if part.strip()]


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--check', action='store_true')
    args = parser.parse_args()
    expected = '-- GENERATED reference snapshot: 0001_initial. Run Alembic for installation.\n' + SOURCE.read_text(encoding='utf-8')
    if args.check:
        if not TARGET.exists() or TARGET.read_text(encoding='utf-8') != expected:
            raise SystemExit('schema.sql differs from migration: run python scripts/render_schema.py')
        print('schema.sql matches 0001_initial')
    else:
        TARGET.parent.mkdir(parents=True, exist_ok=True)
        TARGET.write_text(expected, encoding='utf-8', newline='\n')


if __name__ == '__main__':
    main()
