from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.orm import Session
from typing import List
from app.db.session import get_db
from app.models.account import FinancialAccount
from app.schemas.account import AccountCreate, AccountResponse

router = APIRouter()

# In a real app, you would extract user_id from the authenticated token
@router.post("/", response_model=AccountResponse)
def create_account(account: AccountCreate, user_id: int, db: Session = Depends(get_db)):
    new_account = FinancialAccount(**account.model_dump(), user_id=user_id)  # type: ignore
    db.add(new_account)
    db.commit()
    db.refresh(new_account)
    return new_account

@router.get("/", response_model=List[AccountResponse])
def get_user_accounts(user_id: int, db: Session = Depends(get_db)):
    return db.query(FinancialAccount).filter(FinancialAccount.user_id == user_id).all()
