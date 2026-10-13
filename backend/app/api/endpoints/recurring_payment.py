from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.orm import Session
from typing import List
from app.db.session import get_db
from app.models.recurring_payment import RecurringPayment
from app.schemas.recurring_payment import RecurringPaymentCreate, RecurringPaymentResponse

router = APIRouter()

@router.post("/", response_model=RecurringPaymentResponse)
def create_recurring_payment(
    user_id: int, 
    payment: RecurringPaymentCreate, 
    db: Session = Depends(get_db)
):
    payment_data = payment.model_dump()
    payment_data["user_id"] = user_id
    new_payment = RecurringPayment(**payment_data)
    
    db.add(new_payment)
    db.commit()
    db.refresh(new_payment)
    return new_payment

@router.get("/", response_model=List[RecurringPaymentResponse])
def get_recurring_payments(user_id: int, db: Session = Depends(get_db)):
    return db.query(RecurringPayment).filter(RecurringPayment.user_id == user_id).all()
