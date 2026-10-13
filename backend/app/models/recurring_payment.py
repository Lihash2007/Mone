from sqlalchemy import Column, Integer, String, Float, DateTime, ForeignKey
from sqlalchemy.orm import relationship
from app.db.base import Base

class RecurringPayment(Base):
    id = Column(Integer, primary_key=True, index=True)
    user_id = Column(Integer, ForeignKey("user.id"), nullable=False, index=True)
    
    merchant = Column(String, nullable=False)
    amount = Column(Float, nullable=False)
    frequency = Column(String, nullable=False) # e.g., MONTHLY, YEARLY
    next_expected_date = Column(DateTime(timezone=True), nullable=True)
    
    owner = relationship("User", backref="recurring_payments")
