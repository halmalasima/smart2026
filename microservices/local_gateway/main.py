import os
from fastapi import FastAPI, Request
from fastapi.responses import Response, JSONResponse
import httpx

# ──────────────────────────────────────────────
# Local microservice ports (Django runserver)
# ──────────────────────────────────────────────
AUTH_LOCAL_BASE     = os.environ.get('AUTH_LOCAL_BASE',     'http://127.0.0.1:8001').rstrip('/')
CASES_LOCAL_BASE    = os.environ.get('CASES_LOCAL_BASE',    'http://127.0.0.1:8002').rstrip('/')
LEGAL_LOCAL_BASE    = os.environ.get('LEGAL_LOCAL_BASE',    'http://127.0.0.1:8003').rstrip('/')
HEARINGS_LOCAL_BASE = os.environ.get('HEARINGS_LOCAL_BASE', 'http://127.0.0.1:8004').rstrip('/')
SEARCH_LOCAL_BASE   = os.environ.get('SEARCH_LOCAL_BASE',   'http://127.0.0.1:8005').rstrip('/')
INHERIT_LOCAL_BASE  = os.environ.get('INHERITANCE_LOCAL_BASE', 'http://127.0.0.1:8006').rstrip('/')
# FastAPI خدمة AI (متوافق مع Docker: ai:8000). عند استخدام Django الأحادي فقط: AI_LOCAL_BASE=http://127.0.0.1:8000
AI_LOCAL_BASE       = os.environ.get('AI_LOCAL_BASE', 'http://127.0.0.1:8010').rstrip('/')

# Cloud backends (optional — leave empty for fully local)
LEGAL_CLOUD_BASE = os.environ.get('LEGAL_CLOUD_BASE', '').rstrip('/')
AI_CLOUD_BASE    = os.environ.get('AI_CLOUD_BASE', '').rstrip('/')

CLOUD_SSL_VERIFY = os.environ.get('CLOUD_SSL_VERIFY', '1') != '0'

# ──────────────────────────────────────────────
# Route prefix → upstream mapping
# ──────────────────────────────────────────────
AUTH_PREFIXES = (
    '/api/token/',
    '/api/register/',
    '/api/create-sub-account/',
    '/api/profiles/',
    '/api/user-sessions/',
    '/api/verify-email/',
    '/api/resend-otp/',
    '/api/password-reset/',
)

CASES_PREFIXES = (
    '/api/cases/',
    '/api/case-parties/',
    '/api/lawsuits/',
    '/api/legal-templates/',
    '/api/financial-claims/',
    '/api/plaintiffs/',
    '/api/defendants/',
    '/api/responses/',
    '/api/appeals/',
    '/api/judgments/',
    '/api/payment-orders/',
    '/api/audit-logs/',
    '/api/case-file-items/',
    '/admin/',
    '/static/',
    '/swagger/',
    '/redoc/',
)

LEGAL_PREFIXES = (
    '/api/governorates/',
    '/api/districts/',
    '/api/court-types/',
    '/api/court-specializations/',
    '/api/courts/',
    '/api/legal-categories/',
    '/api/laws/',
    '/api/law-chapters/',
    '/api/law-sections/',
    '/api/law-articles/',
    '/api/case-legal-references/',
    '/api/legal-library/',
    '/api/legal-procedures/',
    '/api/law-library-books/',
    '/api/lawyers/',
    '/api/lawyer-filter-options/',
)

HEARINGS_PREFIXES = (
    '/api/hearings/',
)

SEARCH_PREFIXES = (
    '/api/search-logs/',
    '/api/ai-chat-logs/',
    '/api/ai-conversations/',
)

INHERIT_PREFIXES = (
    '/api/inheritance/',
)

AI_PREFIXES = (
    '/api/ai/',
)

DOCUMENTS_PREFIXES = (
    '/api/attachments/',
    '/media/',
)

# ──────────────────────────────────────────────

app = FastAPI(title='SmartJudi Local Gateway')


@app.get('/health/')
@app.get('/health')
def health():
    return {'status': 'ok', 'service': 'local-gateway'}


def _choose_upstream(path: str) -> str:
    for p in AUTH_PREFIXES:
        if path.startswith(p):
            return AUTH_LOCAL_BASE

    for p in CASES_PREFIXES:
        if path.startswith(p):
            return CASES_LOCAL_BASE

    for p in LEGAL_PREFIXES:
        if path.startswith(p):
            if LEGAL_CLOUD_BASE:
                return LEGAL_CLOUD_BASE
            return LEGAL_LOCAL_BASE

    for p in HEARINGS_PREFIXES:
        if path.startswith(p):
            return HEARINGS_LOCAL_BASE

    for p in SEARCH_PREFIXES:
        if path.startswith(p):
            return SEARCH_LOCAL_BASE

    for p in INHERIT_PREFIXES:
        if path.startswith(p):
            return INHERIT_LOCAL_BASE

    for p in AI_PREFIXES:
        if path.startswith(p):
            return AI_CLOUD_BASE if AI_CLOUD_BASE else AI_LOCAL_BASE

    for p in DOCUMENTS_PREFIXES:
        if path.startswith(p):
            return CASES_LOCAL_BASE

    # Default fallback to auth
    return AUTH_LOCAL_BASE


@app.api_route('/{full_path:path}', methods=['GET', 'POST', 'PUT', 'PATCH', 'DELETE', 'OPTIONS', 'HEAD'])
async def proxy(full_path: str, request: Request):
    path = '/' + full_path
    upstream = _choose_upstream(path)
    url = upstream + path

    # Preserve query string
    if request.url.query:
        url += '?' + request.url.query

    headers = dict(request.headers)
    headers.pop('host', None)

    body = await request.body()

    upstream_kwargs = {}
    if upstream in (LEGAL_CLOUD_BASE, AI_CLOUD_BASE):
        upstream_kwargs['verify'] = CLOUD_SSL_VERIFY

    try:
        async with httpx.AsyncClient(follow_redirects=False, timeout=60.0, **upstream_kwargs) as client:
            upstream_resp = await client.request(
                request.method,
                url,
                content=body,
                headers=headers,
            )

        # Pass-through response
        excluded = {'content-encoding', 'transfer-encoding', 'connection'}
        resp_headers = {k: v for k, v in upstream_resp.headers.items() if k.lower() not in excluded}

        return Response(
            content=upstream_resp.content,
            status_code=upstream_resp.status_code,
            headers=resp_headers,
            media_type=upstream_resp.headers.get('content-type'),
        )
    except httpx.ConnectError:
        return JSONResponse(
            status_code=502,
            content={'error': f'Backend service unavailable for {path}', 'upstream': upstream},
        )
    except httpx.ReadTimeout:
        return JSONResponse(
            status_code=504,
            content={'error': f'Backend service timeout for {path}'},
        )
