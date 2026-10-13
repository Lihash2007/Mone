from pydantic import BaseModel
from typing import Optional
from datetime import datetime

class TransactionBase(BaseModel):
    amount: float
    timestamp: Optional[datetime] = None
    merchant: Optional[str] = None
    type: str
    category: Optional[str] = None
    confidence: float = 1.0

class TransactionCreate(TransactionBase):
    account_id: int

class TransactionResponse(TransactionBase):
    id: int
    user_id: int
    account_id: int
    
    class Config:
        from_attributes = True
