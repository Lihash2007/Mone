from pydantic import BaseModel
from typing import Optional

class AccountBase(BaseModel):
    type: str
    institution: Optional[str] = None
    masked_identifier: Optional[str] = None
    currency: str = "INR"
    status: str = "active"
    balance: float = 0.0
    initial_balance: float = 0.0
    include_in_total: bool = True
    bank_name: Optional[str] = None

class AccountCreate(AccountBase):
    pass

class AccountResponse(AccountBase):
    id: int
    user_id: int
    
    class Config:
        from_attributes = True
