"""Regenerate small, fixed synthetic event cases. No service API is contacted."""
from copy import deepcopy
import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
TYPES = ['user_registered', 'profile_updated', 'survey_submitted', 'survey_updated', 'content_viewed',
         'search_performed', 'filter_changed', 'bookmark_added', 'bookmark_removed', 'review_created',
         'review_updated', 'review_deleted', 'recommendation_impression', 'recommendation_clicked',
         'reservation_confirmed', 'reservation_cancelled', 'visit_marked']
BROWSER = {'content_viewed', 'search_performed', 'filter_changed', 'recommendation_impression', 'recommendation_clicked'}


def example(kind, number):
    browser = kind in BROWSER
    aggregate = ('reservation' if kind.startswith('reservation_') else 'review' if kind.startswith('review_')
                 else 'bookmark' if kind.startswith('bookmark_') else 'survey' if kind.startswith('survey_')
                 else 'visit' if kind == 'visit_marked' else 'user')
    props = {}
    if kind.startswith('reservation_'):
        props = {'reservation_id': '501', 'content_session_id': '301', 'quantity': 2, 'unit_credit': 10000, 'total_credit': 20000}
    elif kind == 'user_registered':
        props = {'granted_credit': 100000}
    elif kind.endswith('_updated'):
        props = {'changed_fields': ['nickname'] if kind == 'profile_updated' else ['rating'] if kind == 'review_updated' else ['genre_ids']}
    elif kind.startswith('recommendation_'):
        props = {'recommendation_id': 'synthetic-opportunity-1', 'position': 0}
    elif kind == 'search_performed':
        props = {'search_term': '가상 전시'}
    elif kind == 'filter_changed':
        props = {'filters': {'region_code': 'SEOUL', 'is_free': False}}
    event = {
        'event_id': f'20000000-0000-4000-8000-{number:012d}', 'schema_version': 1, 'event_type': kind,
        'event_source': 'browser' if browser else 'server', 'occurred_at': '2026-11-02T00:05:00.000Z',
        'received_at': '2026-11-02T00:05:01.000Z', 'request_id': f'synthetic-request-{number}',
        'operation_id': None if browser else f'synthetic:{kind}:{number}', 'user_id': '1', 'anonymous_id': None,
        'session_id': 'synthetic-browser-session', 'content_id': '101' if aggregate not in ('user', 'survey') or browser else None,
        'aggregate_type': None if browser else aggregate, 'aggregate_id': None if browser else '501' if aggregate == 'reservation' else '1',
        'aggregate_version': None if browser else 2 if kind.endswith(('_updated', '_cancelled', '_removed', '_deleted')) else 1,
        'is_test': True, 'test_run_id': 'demo-20261102-01', 'properties': props,
    }
    if kind.startswith('reservation_'):
        event['operation_id'] = 'reservation:501:' + ('confirmed' if kind.endswith('confirmed') else 'cancelled')
    return event


def case(name, event, expected='VALID', **extra):
    result = {'name': name, 'event': event, 'expected': expected}
    if event.get('event_source') == 'server':
        result['sql_snapshot'] = {k: deepcopy(event[k]) for k in ('event_type', 'operation_id', 'properties', 'aggregate_version')}
    result.update(extra)
    return result


def write(path, value):
    target = ROOT / path
    target.parent.mkdir(parents=True, exist_ok=True)
    target.write_text(json.dumps(value, ensure_ascii=False, indent=2) + '\n', encoding='utf-8', newline='\n')


def main():
    valid = [case(kind, example(kind, n)) for n, kind in enumerate(TYPES, 1)]
    write('database/fixtures/valid_events.json', valid)
    write('database/mongodb/event_examples.json', [c['event'] for c in valid])
    viewed = example('content_viewed', 100)
    retransmission = deepcopy(viewed)
    retransmission['received_at'] = '2026-11-02T00:06:00.000Z'
    conflict = deepcopy(viewed)
    conflict['content_id'] = '102'
    purchase = example('reservation_confirmed', 101)
    semantic = deepcopy(purchase)
    semantic['event_id'] = '20000000-0000-4000-8000-000000000102'
    write('database/fixtures/duplicate_events.json', [case('first view', viewed),
        case('same ID retry keeps first received_at', retransmission, 'DUPLICATE_EVENT'),
        case('same ID changed immutable content', conflict, 'EVENT_ID_CONFLICT'),
        case('first business operation', purchase), case('different ID same operation', semantic, 'DUPLICATE_OPERATION'),
        case('independent view must survive deduplication', example('content_viewed', 103))])
    invalid = []
    for n, (name, key, value) in enumerate([
        ('numeric user ID', 'user_id', 1), ('wrong version', 'schema_version', 2),
        ('forged browser success', 'event_source', 'browser'), ('non UTC timestamp', 'occurred_at', '2026-11-02T09:00:00+09:00'),
        ('test without namespace', 'test_run_id', None), ('unknown PII field', 'email', 'synthetic@example.invalid'),
        ('credit as string', 'properties', {'reservation_id': '501', 'content_session_id': '301', 'quantity': 2, 'unit_credit': '10000', 'total_credit': 20000}),
    ], 200):
        event = example('reservation_confirmed', n)
        event[key] = value
        invalid.append(case(name, event, 'INVALID_SCHEMA'))
    missing = example('content_viewed', 250)
    del missing['event_id']
    invalid.append(case('missing event ID', missing, 'INVALID_SCHEMA'))
    write('database/fixtures/invalid_events.json', invalid)
    bad_price = case('valid shape but wrong committed total', example('reservation_confirmed', 300), 'PAYLOAD_MISMATCH')
    bad_price['event']['properties']['quantity'] = 1
    bad_price['event']['properties']['total_credit'] = 10000
    extra = case('server success without SQL outbox', example('profile_updated', 301), 'EXTRA_SERVER_EVENT', sql_snapshot=None)
    orphan = case('missing referenced content', example('content_viewed', 302), 'ORPHAN_REFERENCE', reference_exists=False)
    write('database/fixtures/mismatch_events.json', [bad_price, extra, orphan])


if __name__ == '__main__':
    main()
