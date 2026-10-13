from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.orm import Session
from typing import List
from app.db.session import get_db
from app.models.goal import Goal
from app.schemas.goal import GoalCreate, GoalResponse

router = APIRouter()

@router.post("/", response_model=GoalResponse)
def create_goal(
    user_id: int, 
    goal: GoalCreate, 
    db: Session = Depends(get_db)
):
    goal_data = goal.model_dump()
    goal_data["user_id"] = user_id
    new_goal = Goal(**goal_data)
    
    db.add(new_goal)
    db.commit()
    db.refresh(new_goal)
    return new_goal

@router.get("/", response_model=List[GoalResponse])
def get_goals(user_id: int, db: Session = Depends(get_db)):
    return db.query(Goal).filter(Goal.user_id == user_id).all()
