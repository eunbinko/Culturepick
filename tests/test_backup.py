"""Failure-path checks for shell backup scripts; live restore is exercised in CI."""
import os
from pathlib import Path
import subprocess
import pytest

ROOT = Path(__file__).resolve().parents[1]
pytestmark = pytest.mark.skipif(os.name == 'nt', reason='Bash mock executable is tested in Linux CI')


def test_failed_dump_never_creates_success_backup(tmp_path):
    tools = tmp_path / 'bin'
    tools.mkdir()
    docker = tools / 'docker'
    docker.write_text('#!/bin/sh\necho simulated-dump-failure >&2\nexit 17\n')
    docker.chmod(0o755)
    dest = tmp_path / 'backups'
    env = {**os.environ, 'PATH': str(tools) + os.pathsep + os.environ['PATH'], 'BACKUP_DIR': str(dest)}
    result = subprocess.run(['bash', 'database/backup/backup_mariadb.sh'], cwd=ROOT, env=env, capture_output=True)
    assert result.returncode != 0
    assert not list(dest.iterdir())


def test_restore_rejects_default_production_project():
    env = {**os.environ, 'RESTORE_PROJECT': 'culturepick', 'RESTORE_CONFIRM': 'culturepick'}
    result = subprocess.run(['bash', 'database/backup/restore_mariadb.sh', '/no-file'], cwd=ROOT, env=env, capture_output=True)
    assert result.returncode != 0
    assert b'isolated restore target' in result.stderr
