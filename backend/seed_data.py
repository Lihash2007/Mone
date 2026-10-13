import sys
import os
sys.path.append(os.path.dirname(os.path.abspath(__file__)))

from app.db.session import SessionLocal
from app.models.user import User
from app.models.account import FinancialAccount
from app.models.transaction import Transaction

def seed_db():
    db = SessionLocal()
    try:
        # Create user if not exists
        user = db.query(User).filter(User.id == 1).first()
        if not user:
            user = User(
                email="lihas@example.com",
                hashed_password="hashed_password_here",
                full_name="Lihas",
                is_active=True
            )
            db.add(user)
            db.commit()
            db.refresh(user)
            
        # Create an account
        account = db.query(FinancialAccount).filter(FinancialAccount.user_id == user.id).first()
        if not account:
            account = FinancialAccount(
                user_id=user.id,
                institution_name="HDFC Bank",
                account_type="CHECKING",
                balance=124500.00,
                currency="INR"
            )
            db.add(account)
            db.commit()
            db.refresh(account)
            
        # Add transactions
        txs = db.query(Transaction).filter(Transaction.user_id == user.id).all()
        if not txs:
            t1 = Transaction(
                user_id=user.id,
                account_id=account.id,
                amount=50000.00,
                type="CREDIT",
                category="Income",
                description="TechCorp Salary",
                status="COMPLETED"
            )
            t2 = Transaction(
                user_id=user.id,
                account_id=account.id,
                amount=649.00,
                type="DEBIT",
                category="Entertainment",
                description="Netflix Subscription",
                status="COMPLETED"
            )
            t3 = Transaction(
                user_id=user.id,
                account_id=account.id,
                amount=550.00,
                type="DEBIT",
                category="Food & Dining",
                description="Swiggy Order",
                status="COMPLETED"
            )
            db.add_all([t1, t2, t3])
            db.commit()
            print("Successfully seeded database with dummy transactions!")
        else:
            print("Database already has transactions.")
            
    finally:
        db.close()

if __name__ == "__main__":
    seed_db()
