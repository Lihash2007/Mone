from fastapi import APIRouter
from .endpoints import user, account, transaction, budget, goal, recurring_payment

api_router = APIRouter()
api_router.include_router(user.router, prefix="/users", tags=["users"])
api_router.include_router(account.router, prefix="/accounts", tags=["accounts"])
api_router.include_router(transaction.router, prefix="/transactions", tags=["transactions"])
api_router.include_router(budget.router, prefix="/budgets", tags=["budgets"])
api_router.include_router(goal.router, prefix="/goals", tags=["goals"])
api_router.include_router(recurring_payment.router, prefix="/recurring-payments", tags=["recurring_payments"])
