"""Offline checks for JSON examples. MongoDB independently enforces its BSON validator.

This is not a browser ingestion endpoint, outbox dispatcher, or cross-store ETL.
"""
from copy import deepcopy
from datetime import datetime
import json
from pathlib import Path
from jsonschema import Draft7Validator, FormatChecker

SCHEMA = json.loads((Path(__file__).parent / 'mongodb/event_schema.json').read_text(encoding='utf-8'))
BROWSER_TYPES = {'content_viewed', 'search_performed', 'filter_changed', 'recommendation_impression', 'recommendation_clicked'}
CONTENT_OPTIONAL_TYPES = set(SCHEMA['$and'][4]['$or'][0]['event_type']['$in'])


def json_schema(value):
    if isinstance(value, list):
        return [json_schema(x) for x in value]
    if not isinstance(value, dict):
        return value
    result = {k: json_schema(v) for k, v in value.items() if k != 'bsonType'}
    if 'bsonType' in value:
        types = value['bsonType'] if isinstance(value['bsonType'], list) else [value['bsonType']]
        mapping = {'int': 'integer', 'long': 'integer', 'bool': 'boolean', 'date': 'string', 'objectId': 'string'}
        result['type'] = list(dict.fromkeys(mapping.get(t, t) for t in types))
        if types == ['date']:
            result['format'] = 'date-time'
            result['pattern'] = 'Z$'
    return result


VALIDATOR = Draft7Validator(json_schema(SCHEMA['$and'][0]['$jsonSchema']), format_checker=FormatChecker())


def validate_event(event: dict) -> list[str]:
    if not isinstance(event, dict) or list(VALIDATOR.iter_errors(event)):
        return ['INVALID_SCHEMA']
    browser = event['event_source'] == 'browser'
    aggregates = ('operation_id', 'aggregate_type', 'aggregate_id', 'aggregate_version')
    if browser != (event['event_type'] in BROWSER_TYPES):
        return ['INVALID_SCHEMA']
    if (browser and any(event[k] is not None for k in aggregates)) or (not browser and any(event[k] is None for k in aggregates)):
        return ['INVALID_SCHEMA']
    if (event['user_id'] is None) == (event['anonymous_id'] is None):
        return ['INVALID_SCHEMA']
    if not browser and event['user_id'] is None:
        return ['INVALID_SCHEMA']
    if event['event_type'] not in CONTENT_OPTIONAL_TYPES and event['content_id'] is None:
        return ['INVALID_SCHEMA']
    if (event['is_test'] and (not event['test_run_id'] or event['test_run_id'] == 'real')) or (not event['is_test'] and event['test_run_id'] is not None):
        return ['INVALID_SCHEMA']
    if len(json.dumps(event, ensure_ascii=False).encode('utf-8')) > 16384:
        return ['PAYLOAD_TOO_LARGE']
    return []


def immutable_event(event: dict) -> dict:
    return {k: v for k, v in event.items() if k not in ('received_at', '_id')}


def to_bson(event: dict) -> dict:
    """Wire JSON UTC strings -> BSON-capable UTC datetime values."""
    errors = validate_event(event)
    if errors:
        raise ValueError(errors)
    result = deepcopy(event)
    for field in ('occurred_at', 'received_at'):
        result[field] = datetime.fromisoformat(result[field].replace('Z', '+00:00'))
    return result


def classify_fixture(case: dict, seen_ids: dict, seen_ops: dict) -> str:
    """Reproduce fixture expectations using supplied SQL snapshots, without DB mutation."""
    event = case['event']
    errors = validate_event(event)
    if errors:
        return errors[0]
    if case.get('reference_exists') is False:
        return 'ORPHAN_REFERENCE'
    event_id = event['event_id']
    immutable = immutable_event(event)
    if event_id in seen_ids:
        return 'DUPLICATE_EVENT' if seen_ids[event_id] == immutable else 'EVENT_ID_CONFLICT'
    seen_ids[event_id] = immutable
    operation = event['operation_id']
    if operation:
        if operation in seen_ops:
            return 'DUPLICATE_OPERATION'
        seen_ops[operation] = event_id
    if event['event_source'] == 'server':
        snapshot = case.get('sql_snapshot')
        if snapshot is None:
            return 'EXTRA_SERVER_EVENT'
        if any(event.get(key) != value for key, value in snapshot.items()):
            return 'PAYLOAD_MISMATCH'
    return 'VALID'
