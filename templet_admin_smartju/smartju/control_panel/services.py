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
        "auth": "/api/profiles/",
        "cases": "/api/cases/",
        "hearings": "/api/hearings/",
        "documents": "/api/attachments/",
        "legal": "/api/laws/",
        "notifications": "/api/notifications/",
        "search": "/api/search/health/",
        "ai": "/api/ai-assistant/health/",
        "inheritance": "/api/inheritance/health/",
    }

    def check_services(self) -> list[ServiceStatus]:
        results: list[ServiceStatus] = []
        for name, path in self.SERVICE_PATHS.items():
            url = f"{self.base_url}{path}"
            import time

            t0 = time.perf_counter()
            try:
                resp = requests.get(
                    url, timeout=self.DEFAULT_TIMEOUT, headers=self._headers()
                )
                latency = int((time.perf_counter() - t0) * 1000)
                # auth-protected endpoints return 401 → service is up
                healthy = resp.status_code in (200, 201, 204, 401, 403)
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


def field_display(obj, field) -> str:
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
    text = str(value)
    if len(text) > 80:
        return text[:77] + "…"
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
