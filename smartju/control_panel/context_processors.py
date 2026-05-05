from django.conf import settings

from .services import MICROSERVICE_REGISTRY


def cp_globals(request):
    """Inject globals available in every control_panel template."""
    return {
        "CP_BRAND": getattr(settings, "CP_BRAND", "SmartJudi Console"),
        "CP_VERSION": getattr(settings, "CP_VERSION", "1.0.0"),
        "CP_THEME": request.COOKIES.get("cp_theme", "light"),
        "MICROSERVICES": MICROSERVICE_REGISTRY,
    }
