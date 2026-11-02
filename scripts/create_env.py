"""Create a private local Compose environment. Existing files are never overwritten."""
from pathlib import Path
import secrets

ROOT = Path(__file__).resolve().parents[1]


def main():
    template = (ROOT / 'infra/db/.env.example').read_text(encoding='utf-8')
    lines = []
    for line in template.splitlines():
        if '=' in line and line.split('=', 1)[1].startswith('replace-'):
            line = line.split('=', 1)[0] + '=' + secrets.token_urlsafe(32)
        lines.append(line)
    target = ROOT / 'infra/db/.env'
    with target.open('x', encoding='utf-8', newline='\n') as output:
        output.write('\n'.join(lines) + '\n')
    target.chmod(0o600)
    print('Created infra/db/.env with private generated passwords')


if __name__ == '__main__':
    main()
