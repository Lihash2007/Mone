from sqlalchemy import Column, Integer, String, Float, Boolean, ForeignKey
from sqlalchemy.orm import relationship
from app.db.base import Base

class Budget(Base):
    id = Column(Integer, primary_key=True, index=True)
    user_id = Column(Integer, ForeignKey("user.id"), nullable=False, index=True)
    
    category = Column(String, nullable=False, index=True)
    period = Column(String, default="MONTHLY") # e.g., MONTHLY, WEEKLY
    limit = Column(Float, nullable=False)
    rollover = Column(Boolean, default=False)
    
    owner = relationship("User", backref="budgets")
