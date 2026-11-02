from copy import deepcopy
import json
from pathlib import Path
from uuid import uuid4
import pytest
from pymongo.errors import DuplicateKeyError, WriteError

ROOT = Path(__file__).resolve().parents[1]


def test_mongo_bson_schema_and_unique_id(mongo):
    from database.event_validation import to_bson
    event = json.loads((ROOT / 'database/mongodb/event_examples.json').read_text(encoding='utf-8'))[4]
    event['event_id'] = str(uuid4())
    raw = mongo.raw_events
    document = to_bson(event)
    try:
        raw.insert_one(document)
        with pytest.raises(DuplicateKeyError):
            raw.insert_one(deepcopy(document))
        invalid = deepcopy(document)
        invalid.pop('_id', None)
        invalid['event_id'] = str(uuid4())
        invalid['user_id'] = 1
        with pytest.raises(WriteError, match='validation'):
            raw.insert_one(invalid)
        invalid['user_id'] = '1'
        invalid['occurred_at'] = event['occurred_at']
        with pytest.raises(WriteError, match='validation'):
            raw.insert_one(invalid)
    finally:
        raw.delete_many({'event_id': {'$in': [event['event_id'], invalid['event_id']]}})


def test_mongo_rejects_browser_business_event(mongo):
    from database.event_validation import to_bson
    event = json.loads((ROOT / 'database/mongodb/event_examples.json').read_text(encoding='utf-8'))[14]
    document = to_bson(event)
    document['event_id'] = str(uuid4())
    document['event_source'] = 'browser'
    with pytest.raises(WriteError, match='validation'):
        mongo.raw_events.insert_one(document)


def test_mongo_all_synthetic_types_pass(mongo):
    from database.event_validation import to_bson
    events = json.loads((ROOT / 'database/mongodb/event_examples.json').read_text(encoding='utf-8'))
    documents = []
    for event in events:
        doc = to_bson(event)
        doc['event_id'] = str(uuid4())
        documents.append(doc)
    try:
        mongo.raw_events.insert_many(documents)
        assert mongo.raw_events.count_documents({'event_id': {'$in': [d['event_id'] for d in documents]}}) == 17
    finally:
        mongo.raw_events.delete_many({'event_id': {'$in': [d['event_id'] for d in documents]}})


def test_mongo_app_role_is_append_only(mongo):
    import os
    from pymongo import MongoClient
    from pymongo.errors import OperationFailure
    if not os.getenv('TEST_MONGO_APP_PASSWORD'):
        pytest.skip('TEST_MONGO_APP_PASSWORD not configured')
    client = MongoClient(os.environ['TEST_MONGODB_URI'], username='event_app',
                         password=os.environ['TEST_MONGO_APP_PASSWORD'], authSource='culturepick_events')
    try:
        with pytest.raises(OperationFailure) as error:
            client.culturepick_events.raw_events.delete_many({'event_id': 'nonexistent'})
        assert error.value.code == 13
    finally:
        client.close()


def test_mongo_item_event_needs_content_id(mongo):
    from database.event_validation import to_bson
    event = json.loads((ROOT / 'database/mongodb/event_examples.json').read_text(encoding='utf-8'))[4]
    document = to_bson(event)
    document['event_id'] = str(uuid4())
    document['content_id'] = None
    with pytest.raises(WriteError, match='validation'):
        mongo.raw_events.insert_one(document)
