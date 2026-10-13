from sqlalchemy import Column, Integer, String, Float, DateTime, ForeignKey, Float
from sqlalchemy.orm import relationship
from datetime import datetime, timezone
from app.db.base import Base

class Transaction(Base):
    id = Column(Integer, primary_key=True, index=True)
    user_id = Column(Integer, ForeignKey("user.id"), nullable=False, index=True)
    account_id = Column(Integer, ForeignKey("financial_account.id"), nullable=False, index=True)
    
    amount = Column(Float, nullable=False)
    timestamp = Column(DateTime(timezone=True), default=lambda: datetime.now(timezone.utc), index=True)
    
    merchant = Column(String)
    type = Column(String, nullable=False, index=True) # e.g. EXPENSE, INCOME, INTERNAL_TRANSFER
    category = Column(String, index=True)
    confidence = Column(Float, default=1.0)
    
    account = relationship("FinancialAccount", backref="transactions")
    owner = relationship("User", backref="transactions")
