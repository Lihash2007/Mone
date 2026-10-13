from pydantic import BaseModel
from typing import Optional

class BudgetBase(BaseModel):
    category: str
    period: str = "MONTHLY"
    limit: float
    rollover: bool = False

class BudgetCreate(BudgetBase):
    pass

class BudgetResponse(BudgetBase):
    id: int
    user_id: int
    
    class Config:
        from_attributes = True
