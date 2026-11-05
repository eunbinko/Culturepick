from functools import lru_cache

from pymongo import ASCENDING, MongoClient, UpdateOne

from app.core.config import get_settings


@lru_cache
def get_mongo_client():
    return MongoClient(get_settings().mongo_uri, serverSelectionTimeoutMS=3000)


def store_event_batch(events: list[dict], user_id: int) -> None:
    settings = get_settings()
    collection = get_mongo_client()[settings.mongo_database][settings.mongo_collection]
    collection.create_index([('event_id', ASCENDING)], unique=True)
    operations = [UpdateOne({'event_id': event['event_id']}, {'$setOnInsert': {**event, 'user_id': user_id}}, upsert=True)
                  for event in events]
    if operations:
        collection.bulk_write(operations, ordered=False)
