from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.orm import Session
from typing import List
from app.db.session import get_db
from app.models.budget import Budget
from app.schemas.budget import BudgetCreate, BudgetResponse

router = APIRouter()

@router.post("/", response_model=BudgetResponse)
def create_budget(
    user_id: int, 
    budget: BudgetCreate, 
    db: Session = Depends(get_db)
):
    budget_data = budget.model_dump()
    budget_data["user_id"] = user_id
    new_budget = Budget(**budget_data)
    
    db.add(new_budget)
    db.commit()
    db.refresh(new_budget)
    return new_budget

@router.get("/", response_model=List[BudgetResponse])
def get_budgets(user_id: int, db: Session = Depends(get_db)):
    return db.query(Budget).filter(Budget.user_id == user_id).all()
