from pydantic import BaseModel
from typing import Optional
from datetime import datetime

class RecurringPaymentBase(BaseModel):
    merchant: str
    amount: float
    frequency: str
    next_expected_date: Optional[datetime] = None

class RecurringPaymentCreate(RecurringPaymentBase):
    pass

class RecurringPaymentResponse(RecurringPaymentBase):
    id: int
    user_id: int
    
    class Config:
        from_attributes = True
