"""Helpers used by the control panel.

Includes:
* GatewayClient — a thin wrapper around the microservices API gateway.
* schema helpers — discover Django models and serialize objects safely.
"""
from __future__ import annotations

import os
from dataclasses import dataclass
from typing import Any, Iterable

import requests
from django.apps import apps
from django.conf import settings
from django.db import models as dj_models


# ─────────────────────────── Gateway client ───────────────────────────

@dataclass
class ServiceStatus:
    name: str
    url: str
    healthy: bool
    status_code: int | None
    latency_ms: int | None
    detail: str = ""


class GatewayClient:
    """Talks to the API gateway / microservices.

    The gateway base URL is read from ``CP_GATEWAY_URL`` (env or settings),
    falling back to ``http://localhost:8000`` (matches the docker-compose
    nginx gateway port).
    """

    DEFAULT_TIMEOUT = 4

    def __init__(self, base_url: str | None = None, token: str | None = None):
        self.base_url = (
            base_url
            or os.environ.get("CP_GATEWAY_URL")
            or getattr(settings, "CP_GATEWAY_URL", "http://localhost:8000")
        ).rstrip("/")
        self.token = token

    # ---- low level
    def _headers(self) -> dict[str, str]:
        h = {"Accept": "application/json"}
        if self.token:
            h["Authorization"] = f"Bearer {self.token}"
        return h

    def get(self, path: str, **kwargs) -> requests.Response:
        kwargs.setdefault("timeout", self.DEFAULT_TIMEOUT)
        kwargs.setdefault("headers", self._headers())
        return requests.get(f"{self.base_url}{path}", **kwargs)

    # ---- health ----
    SERVICE_PATHS: dict[str, str] = {
        "gateway": "/health/",
        "auth": "/api/auth/health/",
        "cases": "/api/cases/health/",
        "hearings": "/api/hearings/health/",
        "documents": "/api/documents/health/",
        "legal": "/api/legal/health/",
        "notifications": "/api/notifications/health/",
        "search": "/api/search/health/",
        "ai": "/api/ai/health/",
        "inheritance": "/api/inheritance/health/",
        "portal": "/portal/",
    }

    def check_services(self) -> list[ServiceStatus]:
        results: list[ServiceStatus] = []
        for name, path in self.SERVICE_PATHS.items():
            url = f"{self.base_url}{path}"
            import time

            t0 = time.perf_counter()
            try:
                # Do not follow redirects to avoid port-stripping issues from NGINX to FastAPI
                resp = requests.get(
                    url, timeout=self.DEFAULT_TIMEOUT, headers=self._headers(), allow_redirects=False
                )
                latency = int((time.perf_counter() - t0) * 1000)
                # 200 OK or 3xx Redirect means the service is alive and responding (401/403 means auth is working)
                healthy = resp.status_code in (200, 301, 307, 308, 401, 403)
                results.append(
                    ServiceStatus(
                        name=name,
                        url=url,
                        healthy=healthy,
                        status_code=resp.status_code,
                        latency_ms=latency,
                        detail=("up" if healthy else "down"),
                    )
                )
            except requests.RequestException as exc:
                results.append(
                    ServiceStatus(
                        name=name,
                        url=url,
                        healthy=False,
                        status_code=None,
                        latency_ms=None,
                        detail=str(exc.__class__.__name__),
                    )
                )
        return results


# ─────────────────── Microservice Registry ────────────────────────────

MICROSERVICE_REGISTRY = {
    # service_key: { label, icon, db, apps[], color }
    'auth': {
        'label': 'المصادقة والمستخدمين',
        'icon': 'shield-lock',
        'db': 'auth_db',
        'port': 5439,
        'apps': ['accounts', 'dashboard'],
        'color': '#6366f1',
    },
    'cases': {
        'label': 'القضايا والدعاوى',
        'icon': 'briefcase',
        'db': 'cases_db',
        'port': 5433,
        'apps': ['lawsuits', 'parties', 'appeals', 'judgments', 'payments', 'responses', 'courts'],
        'color': '#0ea5e9',
    },
    'hearings': {
        'label': 'الجلسات',
        'icon': 'calendar-event',
        # NOTE: hearings has FK relations to lawsuits (cases service).
        # Django ORM/admin cannot JOIN across different databases, so the control panel
        # must keep related apps in the same DB alias.
        'db': 'cases_db',
        'port': 5433,
        'apps': ['hearings'],
        'color': '#f59e0b',
    },
    'legal': {
        'label': 'المكتبة القانونية',
        'icon': 'book',
        'db': 'legal_db',
        'port': 5435,
        'apps': ['laws', 'lawyers'],
        'color': '#10b981',
    },
    'documents': {
        'label': 'المستندات والمرفقات',
        'icon': 'file-text',
        'db': 'documents_db',
        'port': 5436,
        'apps': ['attachments'],
        'color': '#8b5cf6',
    },
    'notifications': {
        'label': 'الإشعارات والرسائل',
        'icon': 'bell',
        'db': 'notifications_db',
        'port': 5437,
        'apps': ['notifications', 'messaging'],
        'color': '#ef4444',
    },
    'search': {
        'label': 'البحث والسجلات',
        'icon': 'search',
        'db': 'search_db',
        'port': 5438,
        'apps': ['logs', 'audit'],
        'color': '#14b8a6',
    },
    'ai': {
        'label': 'المساعد الذكي',
        'icon': 'robot',
        'db': 'default',
        'port': None,
        'apps': ['ai_assistant'],
        'color': '#a855f7',
    },
}

def get_service_for_app(app_label: str) -> str | None:
    """Return the microservice key for a given app_label."""
    for key, svc in MICROSERVICE_REGISTRY.items():
        if app_label in svc['apps']:
            return key
    return None

def list_app_models_by_service() -> list[dict[str, Any]]:
    """Return models grouped by microservice instead of Django app."""
    services = {}
    for model in apps.get_models():
        meta = model._meta
        if meta.app_label in EXCLUDED_APPS:
            continue
        svc_key = get_service_for_app(meta.app_label) or 'other'
        if svc_key not in services:
            svc_info = MICROSERVICE_REGISTRY.get(svc_key, {
                'label': 'أخرى',
                'icon': 'box',
                'db': 'default',
                'color': '#64748b',
            })
            services[svc_key] = {
                'key': svc_key,
                'label': svc_info['label'],
                'icon': svc_info.get('icon', 'box'),
                'color': svc_info.get('color', '#64748b'),
                'db': svc_info.get('db', 'default'),
                'models': [],
                'total_rows': 0,
            }
        try:
            count = model._default_manager.count()
        except Exception:
            count = 0
        services[svc_key]['models'].append({
            'app_label': meta.app_label,
            'name': meta.model_name,
            'verbose': str(meta.verbose_name_plural).title(),
            'count': count,
        })
        services[svc_key]['total_rows'] += count if isinstance(count, int) else 0

    for svc in services.values():
        svc['models'].sort(key=lambda m: m['verbose'])

    return sorted(services.values(), key=lambda s: s.get('label', ''))

# ─────────────────────────── Schema helpers ───────────────────────────

EXCLUDED_APPS = {
    "admin",
    "auth",
    "contenttypes",
    "sessions",
    "messages",
    "staticfiles",
    "token_blacklist",
    "django_filters",
    "drf_yasg",
    "jazzmin",
    "rest_framework",
    "rest_framework_simplejwt",
    "corsheaders",
    "control_panel",
}


def list_app_models() -> list[dict[str, Any]]:
    """Return a structured list of project apps and their models.

    Used by the model browser to render the navigation tree.
    """
    grouped: dict[str, dict[str, Any]] = {}
    for model in apps.get_models():
        meta = model._meta
        if meta.app_label in EXCLUDED_APPS:
            continue
        bucket = grouped.setdefault(
            meta.app_label,
            {
                "label": meta.app_label,
                "verbose": apps.get_app_config(meta.app_label).verbose_name,
                "models": [],
            },
        )
        try:
            count = model._default_manager.count()
        except Exception:
            count = "—"
        bucket["models"].append(
            {
                "name": meta.model_name,
                "verbose": str(meta.verbose_name_plural).title(),
                "count": count,
            }
        )

    out = list(grouped.values())
    for app in out:
        app["models"].sort(key=lambda m: m["name"])
    out.sort(key=lambda a: a["label"])
    return out


def get_model_or_404(app_label: str, model_name: str):
    from django.http import Http404

    try:
        return apps.get_model(app_label, model_name)
    except LookupError as exc:
        raise Http404(str(exc))


def field_display(obj, field, full=False) -> str:
    """Render a single field value in a human friendly way."""
    try:
        value = getattr(obj, field.name, None)
    except Exception:
        return "—"
    if value is None:
        return "—"
    if isinstance(field, dj_models.ForeignKey):
        return str(value)
    if isinstance(field, dj_models.ManyToManyField):
        try:
            return ", ".join(str(v) for v in value.all()[:5])
        except Exception:
            return "—"
    if isinstance(field, (dj_models.DateField, dj_models.DateTimeField)):
        return value.strftime("%Y-%m-%d %H:%M") if hasattr(value, "strftime") else str(value)
    if isinstance(field, dj_models.BooleanField):
        return "✓" if value else "✗"
    if isinstance(field, (dj_models.FileField, dj_models.ImageField)):
        try:
            return value.url
        except Exception:
            return str(value)
    text = str(value)
    if not full and len(text) > 100:
        return text[:97] + "…"
    return text


def visible_fields(model, max_fields: int = 7) -> list:
    """Pick a reasonable subset of fields for list display."""
    out = []
    for f in model._meta.get_fields():
        if not getattr(f, "concrete", False):
            continue
        if isinstance(f, dj_models.ManyToManyField):
            continue
        out.append(f)
        if len(out) >= max_fields:
            break
    return out
