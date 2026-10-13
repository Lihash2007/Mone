from sqlalchemy import Column, Integer, String, JSON, Boolean
from app.db.base import Base

class User(Base):
    id = Column(Integer, primary_key=True, index=True)
    email = Column(String, unique=True, index=True, nullable=False)
    hashed_password = Column(String, nullable=False)
    is_active = Column(Boolean, default=True)
    profile = Column(JSON, default={})
    preferences = Column(JSON, default={})
    security_settings = Column(JSON, default={})
