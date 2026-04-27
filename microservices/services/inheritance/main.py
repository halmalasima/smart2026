from fastapi import Depends, FastAPI

from api.schemas import InheritanceRequest, InheritanceResponse, ShareItem
from api.security import require_auth
from domain.engine import calculate_inheritance
from domain.models import Heir


app = FastAPI()


@app.get('/api/inheritance/health/')
def health():
    return {'status': 'ok', 'service': 'inheritance-service'}


@app.post('/api/inheritance/calculate/', response_model=InheritanceResponse)
def calculate(req: InheritanceRequest, _auth: None = Depends(require_auth)):
    estate_value = req.estate_value
    if req.estate_items:
        estate_value = sum((i.value for i in req.estate_items), start=req.estate_value * 0)

    debts = req.debts
    if req.debt_items:
        debts = sum((i.amount for i in req.debt_items), start=req.debts * 0)

    bequests = req.bequests
    if req.bequest_items:
        bequests = sum((i.amount for i in req.bequest_items), start=req.bequests * 0)

    totals, shares, notes = calculate_inheritance(
        estate_value=estate_value,
        debts=debts,
        bequests=bequests,
        heirs=[Heir(type=h.type, count=h.count) for h in req.heirs],
    )

    return InheritanceResponse(
        totals={k: str(v) for k, v in totals.items()},
        shares=[
            ShareItem(
                heir_type=s.heir_type,
                count=s.count,
                fraction_numerator=s.numerator,
                fraction_denominator=s.denominator,
                total_amount=str(s.total_amount),
                amount_per_heir=str(s.amount_per_heir),
                basis=s.basis,
                reason_code=s.reason_code,
            )
            for s in shares
        ],
        notes=notes,
    )
