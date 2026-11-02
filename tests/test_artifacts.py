"""Offline handoff checks; these do not replace live database tests."""
import json
from pathlib import Path
import subprocess
import sys
import os
import pytest

ROOT = Path(__file__).resolve().parents[1]


def test_snapshot_is_generated_from_migration():
    result = subprocess.run(
        [sys.executable, str(ROOT / 'scripts/render_schema.py'), '--check'],
        capture_output=True, text=True,
    )
    assert result.returncode == 0, result.stdout + result.stderr


def test_all_requested_artifacts_exist():
    paths = {
        'database/mariadb': ['schema.sql', 'seed.sql', 'queries.sql', 'indexes.sql', 'permissions.sql'],
        'database/mongodb': ['init.js', 'event_examples.json'],
        'database/analytics': ['daily_activity.sql', 'content_metrics.sql', 'recommendation_data.sql', 'quality_checks.sql'],
        'database/fixtures': ['valid_events.json', 'duplicate_events.json', 'invalid_events.json', 'mismatch_events.json'],
        'database/backup': ['backup_mariadb.sh', 'restore_mariadb.sh', 'backup_mongodb.sh', 'restore_mongodb.sh'],
        'infra/db': ['compose.yaml', 'mariadb.cnf', 'mongod.conf', '.env.example'],
        'docs': ['erd.md', 'db-spec.md', 'data-dictionary.md', 'event-contract.md', 'data-quality.md', 'backup-restore.md'],
        'database': ['README.md'],
    }
    missing = [f'{folder}/{name}' for folder, names in paths.items() for name in names
               if not (ROOT / folder / name).is_file()]
    assert not missing, missing


def test_fixture_expectations_are_reproducible():
    from database.event_validation import validate_event, classify_fixture
    for name in ('valid_events', 'duplicate_events', 'invalid_events', 'mismatch_events'):
        fixture = json.loads((ROOT / f'database/fixtures/{name}.json').read_text(encoding='utf-8'))
        seen_ids, seen_ops = {}, {}
        for case in fixture:
            result = classify_fixture(case, seen_ids, seen_ops)
            assert result == case['expected'], (case['name'], result)
            if name == 'valid_events':
                assert validate_event(case['event']) == []


def test_browser_cannot_forge_success_event():
    from database.event_validation import validate_event
    cases = json.loads((ROOT / 'database/fixtures/valid_events.json').read_text(encoding='utf-8'))
    event = next(c['event'] for c in cases if c['event']['event_type'] == 'reservation_confirmed').copy()
    event['event_source'] = 'browser'
    assert 'INVALID_SCHEMA' in validate_event(event)


def test_offline_migration_preserves_operation_literal():
    env = {**os.environ, 'MARIADB_MIGRATION_USER': 'offline', 'MARIADB_MIGRATION_PASSWORD': ''}
    result = subprocess.run([sys.executable, '-m', 'alembic', 'upgrade', 'head', '--sql'],
                            cwd=ROOT, env=env, capture_output=True, text=True)
    assert result.returncode == 0, result.stderr
    assert "':confirmed'" in result.stdout
    assert "':cancelled'" in result.stdout


@pytest.mark.parametrize('kind', ['content_viewed','recommendation_impression','recommendation_clicked',
    'bookmark_added','bookmark_removed','review_created','review_updated','review_deleted',
    'reservation_confirmed','reservation_cancelled','visit_marked'])
def test_item_event_needs_content_id(kind):
    from database.event_validation import validate_event
    events = json.loads((ROOT / 'database/mongodb/event_examples.json').read_text(encoding='utf-8'))
    event = next(e for e in events if e['event_type'] == kind).copy()
    event['content_id'] = None
    assert validate_event(event) == ['INVALID_SCHEMA']
