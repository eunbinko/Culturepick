from fastapi import APIRouter, Depends, HTTPException

from app.api.deps import current_user, get_store
from app.db.mongo import store_event_batch
from app.schemas import ContentPage, EventBatchInput, EventInput
from app.services.catalog import CatalogService

router = APIRouter(prefix='/history', tags=['history'])
CONTENT_EVENTS = {'content_view', 'recommendation_click', 'recommendation_impression'}


def persist_batch(events, store, user):
    for item in events:
        if item.type not in CONTENT_EVENTS:
            continue
        content_id = item.props.get('content_id')
        if not isinstance(content_id, int) or content_id < 1:
            raise HTTPException(422, 'content_id is required for this event type.')
        CatalogService(store).require(content_id)
        store.event({'event_id': str(item.event_id), 'event_type': item.type, 'user_id': user.id,
                     'content_id': content_id, 'properties': item.props})
    try:
        store_event_batch([item.model_dump(mode='json') for item in events], user.id)
    except Exception as exc:
        from pymongo.errors import PyMongoError
        if isinstance(exc, PyMongoError):
            raise HTTPException(503, 'Event storage is temporarily unavailable.') from exc
        raise


@router.post('/events', status_code=202)
def event(data: EventInput, store=Depends(get_store), user=Depends(current_user)):
    persist_batch([data], store, user)
    return {'accepted': True}


@router.post('/events/batch', status_code=202)
def event_batch(data: EventBatchInput, store=Depends(get_store), user=Depends(current_user)):
    persist_batch(data.events, store, user)
    return {'accepted': len(data.events)}


@router.get('', response_model=ContentPage)
def listing(store=Depends(get_store), user=Depends(current_user)):
    items = CatalogService(store).serialize(store.recent(user.id), user)
    return ContentPage(items=items, total=len(items), size=100)
