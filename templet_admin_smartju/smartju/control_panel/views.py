"""Control panel views.

Sections:
  * Auth (login / logout)
  * Dashboard
  * Users & Groups (CRUD)
  * Generic model browser (read + delete)
  * Microservices monitor (talks to API gateway)
  * Activity log
  * Profile / theme toggle
"""
from __future__ import annotations

from datetime import timedelta

from django.apps import apps
from django.contrib import messages
from django.contrib.auth import (
    authenticate,
    get_user_model,
    login as auth_login,
    logout as auth_logout,
)
from django.contrib.auth.models import Group, Permission
from django.core.paginator import Paginator
from django.db.models import Count, Q
from django.http import HttpResponse, JsonResponse
from django.shortcuts import get_object_or_404, redirect, render
from django.urls import reverse
from django.utils import timezone
from django.utils.timezone import now
from django.views.decorators.cache import never_cache
from django.views.decorators.http import require_POST

from .decorators import staff_required, superuser_required
from .forms import CPLoginForm, GroupForm, UserCreateForm, UserUpdateForm
from .models import ActivityLog
from .services import (
    GatewayClient,
    field_display,
    get_model_or_404,
    list_app_models,
    visible_fields,
)

User = get_user_model()


# ───────────────────────────── Helpers ─────────────────────────────

def _client_ip(request) -> str | None:
    xff = request.META.get("HTTP_X_FORWARDED_FOR")
    if xff:
        return xff.split(",")[0].strip()
    return request.META.get("REMOTE_ADDR")


def _log(request, action: str, target: str = "", description: str = ""):
    try:
        ActivityLog.objects.create(
            user=request.user if request.user.is_authenticated else None,
            action=action,
            target=target[:255],
            description=description,
            ip_address=_client_ip(request),
            user_agent=request.META.get("HTTP_USER_AGENT", "")[:512],
        )
    except Exception:
        pass


# ────────────────────────────── Auth ───────────────────────────────

@never_cache
def login_view(request):
    if request.user.is_authenticated and (request.user.is_staff or request.user.is_superuser):
        return redirect("control_panel:dashboard")

    form = CPLoginForm(request, data=request.POST or None)
    if request.method == "POST" and form.is_valid():
        user = form.get_user()
        if user.is_staff or user.is_superuser:
            auth_login(request, user)
            _log(request, "login", target=user.get_username())
            return redirect(request.GET.get("next") or "control_panel:dashboard")
        messages.error(request, "هذا الحساب لا يملك صلاحية الدخول إلى لوحة التحكم.")
    return render(request, "control_panel/login.html", {"form": form})


@require_POST
def logout_view(request):
    if request.user.is_authenticated:
        _log(request, "logout", target=request.user.get_username())
    auth_logout(request)
    return redirect("control_panel:login")


@require_POST
def toggle_theme(request):
    current = request.COOKIES.get("cp_theme", "light")
    new_theme = "dark" if current == "light" else "light"
    response = JsonResponse({"theme": new_theme})
    response.set_cookie("cp_theme", new_theme, max_age=60 * 60 * 24 * 365, samesite="Lax")
    return response


# ──────────────────────────── Dashboard ─────────────────────────────

@staff_required
def dashboard(request):
    today = timezone.localdate()
    last_7 = today - timedelta(days=6)
    users_qs = User.objects.all()

    # Build last-7-days new-users series
    series = []
    for i in range(7):
        day = last_7 + timedelta(days=i)
        next_day = day + timedelta(days=1)
        c = users_qs.filter(date_joined__date__gte=day, date_joined__date__lt=next_day).count()
        series.append({"day": day.strftime("%m/%d"), "count": c})

    # Build app/model totals
    app_totals = []
    grand_total = 0
    for app_data in list_app_models():
        total = sum(m["count"] if isinstance(m["count"], int) else 0 for m in app_data["models"])
        grand_total += total
        app_totals.append(
            {
                "label": app_data["label"],
                "verbose": app_data["verbose"],
                "model_count": len(app_data["models"]),
                "row_count": total,
            }
        )
    app_totals.sort(key=lambda x: -x["row_count"])

    stats = {
        "users_total": users_qs.count(),
        "users_active": users_qs.filter(is_active=True).count(),
        "users_staff": users_qs.filter(is_staff=True).count(),
        "users_new_7d": users_qs.filter(date_joined__date__gte=last_7).count(),
        "groups_total": Group.objects.count(),
        "models_total": sum(len(a["models"]) for a in list_app_models()),
        "rows_total": grand_total,
    }

    recent_activity = ActivityLog.objects.select_related("user")[:10]
    recent_users = users_qs.order_by("-date_joined")[:6]

    context = {
        "stats": stats,
        "series": series,
        "app_totals": app_totals[:8],
        "recent_activity": recent_activity,
        "recent_users": recent_users,
        "page_title": "لوحة التحكم",
        "active_section": "dashboard",
    }
    return render(request, "control_panel/dashboard.html", context)


# ──────────────────────── Users management ─────────────────────────

@staff_required
def user_list(request):
    q = request.GET.get("q", "").strip()
    role = request.GET.get("role", "")
    status = request.GET.get("status", "")

    qs = User.objects.all().order_by("-date_joined")
    if q:
        qs = qs.filter(
            Q(username__icontains=q)
            | Q(email__icontains=q)
            | Q(first_name__icontains=q)
            | Q(last_name__icontains=q)
        )
    if role == "staff":
        qs = qs.filter(is_staff=True)
    elif role == "superuser":
        qs = qs.filter(is_superuser=True)
    elif role == "regular":
        qs = qs.filter(is_staff=False, is_superuser=False)
    if status == "active":
        qs = qs.filter(is_active=True)
    elif status == "inactive":
        qs = qs.filter(is_active=False)

    paginator = Paginator(qs, 15)
    page = paginator.get_page(request.GET.get("page"))
    return render(
        request,
        "control_panel/users/list.html",
        {
            "page": page,
            "q": q,
            "role": role,
            "status": status,
            "page_title": "إدارة المستخدمين",
            "active_section": "users",
        },
    )


@staff_required
def user_create(request):
    form = UserCreateForm(request.POST or None)
    if request.method == "POST" and form.is_valid():
        user = form.save()
        _log(request, "create", target=f"User:{user.username}", description="إضافة مستخدم جديد")
        messages.success(request, f"تم إنشاء المستخدم {user.username} بنجاح.")
        return redirect("control_panel:user_detail", pk=user.pk)
    return render(
        request,
        "control_panel/users/form.html",
        {
            "form": form,
            "mode": "create",
            "page_title": "إضافة مستخدم",
            "active_section": "users",
        },
    )


@staff_required
def user_detail(request, pk):
    user = get_object_or_404(User, pk=pk)
    activity = ActivityLog.objects.filter(user=user)[:20]
    return render(
        request,
        "control_panel/users/detail.html",
        {
            "u": user,
            "activity": activity,
            "page_title": f"المستخدم: {user.get_username()}",
            "active_section": "users",
        },
    )


@staff_required
def user_update(request, pk):
    user = get_object_or_404(User, pk=pk)
    form = UserUpdateForm(request.POST or None, instance=user)
    if request.method == "POST" and form.is_valid():
        form.save()
        _log(request, "update", target=f"User:{user.username}")
        messages.success(request, "تم حفظ التعديلات.")
        return redirect("control_panel:user_detail", pk=user.pk)
    return render(
        request,
        "control_panel/users/form.html",
        {
            "form": form,
            "mode": "update",
            "u": user,
            "page_title": f"تعديل: {user.get_username()}",
            "active_section": "users",
        },
    )


@staff_required
@require_POST
def user_delete(request, pk):
    user = get_object_or_404(User, pk=pk)
    if user == request.user:
        messages.error(request, "لا يمكنك حذف حسابك الحالي.")
        return redirect("control_panel:user_detail", pk=pk)
    if user.is_superuser and not request.user.is_superuser:
        messages.error(request, "صلاحياتك لا تكفي لحذف هذا المستخدم.")
        return redirect("control_panel:user_detail", pk=pk)
    username = user.username
    user.delete()
    _log(request, "delete", target=f"User:{username}")
    messages.success(request, f"تم حذف المستخدم {username}.")
    return redirect("control_panel:user_list")


@staff_required
@require_POST
def user_toggle_active(request, pk):
    user = get_object_or_404(User, pk=pk)
    if user == request.user:
        messages.error(request, "لا يمكنك تعطيل حسابك الحالي.")
    else:
        user.is_active = not user.is_active
        user.save(update_fields=["is_active"])
        _log(request, "update", target=f"User:{user.username}", description=f"is_active={user.is_active}")
        messages.success(request, "تم تحديث الحالة.")
    return redirect("control_panel:user_detail", pk=pk)


# ──────────────────────── Roles / Groups ───────────────────────────

@staff_required
def group_list(request):
    groups = Group.objects.annotate(member_count=Count("user"), perm_count=Count("permissions")).order_by("name")
    return render(
        request,
        "control_panel/users/groups.html",
        {
            "groups": groups,
            "page_title": "الأدوار والصلاحيات",
            "active_section": "groups",
        },
    )


@staff_required
def group_create(request):
    form = GroupForm(request.POST or None)
    if request.method == "POST" and form.is_valid():
        g = form.save()
        _log(request, "create", target=f"Group:{g.name}")
        messages.success(request, "تم إنشاء الدور.")
        return redirect("control_panel:group_list")
    return render(
        request,
        "control_panel/users/group_form.html",
        {"form": form, "mode": "create", "page_title": "إضافة دور", "active_section": "groups"},
    )


@staff_required
def group_update(request, pk):
    g = get_object_or_404(Group, pk=pk)
    form = GroupForm(request.POST or None, instance=g)
    if request.method == "POST" and form.is_valid():
        form.save()
        _log(request, "update", target=f"Group:{g.name}")
        messages.success(request, "تم حفظ التعديلات.")
        return redirect("control_panel:group_list")
    return render(
        request,
        "control_panel/users/group_form.html",
        {"form": form, "mode": "update", "g": g, "page_title": f"تعديل دور: {g.name}", "active_section": "groups"},
    )


@staff_required
@require_POST
def group_delete(request, pk):
    g = get_object_or_404(Group, pk=pk)
    name = g.name
    g.delete()
    _log(request, "delete", target=f"Group:{name}")
    messages.success(request, "تم حذف الدور.")
    return redirect("control_panel:group_list")


# ─────────────────────── Generic model browser ──────────────────────

@staff_required
def models_index(request):
    grouped = list_app_models()
    return render(
        request,
        "control_panel/models/index.html",
        {
            "grouped": grouped,
            "page_title": "مستعرض البيانات",
            "active_section": "models",
        },
    )


@staff_required
def model_browse(request, app_label, model_name):
    Model = get_model_or_404(app_label, model_name)
    fields = visible_fields(Model)
    q = request.GET.get("q", "").strip()
    qs = Model._default_manager.all()
    if q:
        text_filters = Q()
        for f in fields:
            if f.get_internal_type() in ("CharField", "TextField", "EmailField", "SlugField"):
                text_filters |= Q(**{f"{f.name}__icontains": q})
        if text_filters:
            qs = qs.filter(text_filters)

    paginator = Paginator(qs, 25)
    page = paginator.get_page(request.GET.get("page"))

    rows = []
    for obj in page.object_list:
        rows.append(
            {
                "pk": obj.pk,
                "values": [field_display(obj, f) for f in fields],
                "str": str(obj),
            }
        )

    return render(
        request,
        "control_panel/models/browse.html",
        {
            "Model": Model,
            "meta": Model._meta,
            "fields": fields,
            "rows": rows,
            "page": page,
            "q": q,
            "page_title": f"{Model._meta.verbose_name_plural}",
            "active_section": "models",
        },
    )


@staff_required
def model_detail(request, app_label, model_name, pk):
    Model = get_model_or_404(app_label, model_name)
    obj = get_object_or_404(Model, pk=pk)
    rows = []
    for f in Model._meta.get_fields():
        if not getattr(f, "concrete", False):
            continue
        rows.append({"name": f.name, "verbose": getattr(f, "verbose_name", f.name), "value": field_display(obj, f)})
    return render(
        request,
        "control_panel/models/detail.html",
        {
            "Model": Model,
            "meta": Model._meta,
            "obj": obj,
            "rows": rows,
            "page_title": f"{Model._meta.verbose_name}: {obj}",
            "active_section": "models",
        },
    )


@staff_required
@require_POST
def model_delete(request, app_label, model_name, pk):
    Model = get_model_or_404(app_label, model_name)
    obj = get_object_or_404(Model, pk=pk)
    label = str(obj)
    obj.delete()
    _log(request, "delete", target=f"{app_label}.{model_name}:{label}")
    messages.success(request, "تم الحذف بنجاح.")
    return redirect("control_panel:model_browse", app_label=app_label, model_name=model_name)


# ─────────────────────── Microservices monitor ──────────────────────

@staff_required
def microservices_index(request):
    return render(
        request,
        "control_panel/microservices/index.html",
        {
            "page_title": "حالة الخدمات (Microservices)",
            "active_section": "microservices",
            "gateway_url": GatewayClient().base_url,
        },
    )


@staff_required
def microservices_status(request):
    """JSON endpoint polled by the page to refresh service health."""
    client = GatewayClient()
    services = [s.__dict__ for s in client.check_services()]
    healthy = sum(1 for s in services if s["healthy"])
    return JsonResponse(
        {
            "checked_at": now().isoformat(),
            "gateway": client.base_url,
            "summary": {"total": len(services), "healthy": healthy, "down": len(services) - healthy},
            "services": services,
        }
    )


# ───────────────────────── Activity log ────────────────────────────

@staff_required
def activity_log(request):
    qs = ActivityLog.objects.select_related("user").all()
    action = request.GET.get("action", "")
    if action:
        qs = qs.filter(action=action)
    paginator = Paginator(qs, 30)
    page = paginator.get_page(request.GET.get("page"))
    return render(
        request,
        "control_panel/activity.html",
        {
            "page": page,
            "action": action,
            "actions": ActivityLog.ACTION_CHOICES,
            "page_title": "سجل النشاط",
            "active_section": "activity",
        },
    )


# ──────────────────────────── Profile ──────────────────────────────

@staff_required
def profile(request):
    user = request.user
    if request.method == "POST":
        user.first_name = request.POST.get("first_name", user.first_name)
        user.last_name = request.POST.get("last_name", user.last_name)
        user.email = request.POST.get("email", user.email)
        new_pw = request.POST.get("new_password", "").strip()
        if new_pw:
            if len(new_pw) < 6:
                messages.error(request, "كلمة المرور قصيرة جدًا (6 على الأقل).")
            else:
                user.set_password(new_pw)
                messages.info(request, "تم تغيير كلمة المرور — قد تحتاج لتسجيل الدخول مجددًا.")
        user.save()
        messages.success(request, "تم حفظ الملف الشخصي.")
        return redirect("control_panel:profile")
    return render(
        request,
        "control_panel/profile.html",
        {
            "page_title": "ملفي الشخصي",
            "active_section": "profile",
        },
    )
