from fastapi import APIRouter, Depends
from app.api.deps import current_user
from app.schemas import ProfileInput, UserOut

router = APIRouter(prefix='/users', tags=['users'])


@router.get('/me', response_model=UserOut)
def me(user=Depends(current_user)):
    return user


@router.patch('/me', response_model=UserOut)
def update(data: ProfileInput, user=Depends(current_user)):
    user.name = data.name
    return user
