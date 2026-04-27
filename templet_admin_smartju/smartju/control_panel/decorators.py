from functools import wraps

from django.contrib.auth.decorators import user_passes_test
from django.shortcuts import redirect


def staff_required(view_func):
    @wraps(view_func)
    def _check(request, *args, **kwargs):
        if not request.user.is_authenticated:
            return redirect("control_panel:login")
        if not (request.user.is_staff or request.user.is_superuser):
            return redirect("control_panel:login")
        return view_func(request, *args, **kwargs)

    return _check


def superuser_required(view_func):
    decorator = user_passes_test(lambda u: u.is_superuser, login_url="control_panel:login")
    return decorator(view_func)
