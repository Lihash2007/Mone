from sqlalchemy import Column, Integer, String, ForeignKey, Float, Boolean
from sqlalchemy.orm import relationship
from app.db.base import Base

class FinancialAccount(Base):
    __tablename__ = "financial_account"
    
    id = Column(Integer, primary_key=True, index=True)
    user_id = Column(Integer, ForeignKey("user.id"), nullable=False)
    type = Column(String, nullable=False, index=True) # e.g. bank, credit_card, cash
    institution = Column(String)
    masked_identifier = Column(String)
    currency = Column(String, default="INR")
    status = Column(String, default="active")
    balance = Column(Float, default=0.0)
    initial_balance = Column(Float, default=0.0)
    include_in_total = Column(Boolean, default=True)
    bank_name = Column(String, nullable=True)
    
    owner = relationship("User", backref="accounts")
