from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.orm import Session
from app.db.session import get_db
from app.models.transaction import Transaction
from app.models.account import FinancialAccount
from app.schemas.transaction import TransactionCreate, TransactionResponse
from typing import List

router = APIRouter()

@router.post("/", response_model=TransactionResponse)
def create_transaction(
    user_id: int, 
    transaction: TransactionCreate, 
    db: Session = Depends(get_db)
):
    # Verify account exists and belongs to user (assuming simplified model for now)
    account = db.query(FinancialAccount).filter(FinancialAccount.id == transaction.account_id).first()
    if not account:
        raise HTTPException(status_code=404, detail="Account not found")
        
    transaction_data = {
        "user_id": user_id,
        "account_id": transaction.account_id,
        "amount": transaction.amount,
        "merchant": transaction.merchant,
        "type": transaction.type,
        "category": transaction.category,
        "confidence": transaction.confidence,
    }
    new_transaction = Transaction(**transaction_data)
    if transaction.timestamp:
        new_transaction.timestamp = transaction.timestamp

    db.add(new_transaction)
    db.commit()
    db.refresh(new_transaction)
    return new_transaction

@router.get("/", response_model=List[TransactionResponse])
def get_user_transactions(user_id: int, skip: int = 0, limit: int = 100, db: Session = Depends(get_db)):
    transactions = db.query(Transaction).filter(Transaction.user_id == user_id).offset(skip).limit(limit).all()
    return transactions
