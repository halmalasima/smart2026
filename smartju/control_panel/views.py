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

    # Real-time service stats from the monolith models
    service_stats = {}
    try:
        from lawsuits.models import Lawsuit
        service_stats["lawsuits"] = Lawsuit.objects.count()
    except Exception:
        service_stats["lawsuits"] = 0
    try:
        from hearings.models import Hearing
        service_stats["hearings"] = Hearing.objects.count()
    except Exception:
        service_stats["hearings"] = 0
    try:
        from laws.models import Law, LegalArticleFlat
        service_stats["laws"] = Law.objects.count() + LegalArticleFlat.objects.count()
    except Exception:
        service_stats["laws"] = 0
    try:
        from courts.models import Court
        service_stats["courts"] = Court.objects.count()
    except Exception:
        service_stats["courts"] = 0
    try:
        from appeals.models import Appeal
        service_stats["appeals"] = Appeal.objects.count()
    except Exception:
        service_stats["appeals"] = 0
    try:
        from lawyers.models import Lawyer
        service_stats["lawyers"] = Lawyer.objects.count()
    except Exception:
        service_stats["lawyers"] = 0

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
        "service_stats": service_stats,
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
    from accounts.models import UserProfile
    from dashboard.models import SubscriptionPlan

    q = request.GET.get("q", "").strip()
    role = request.GET.get("role", "")
    status = request.GET.get("status", "")
    plan_filter = request.GET.get("plan", "")

    qs = User.objects.select_related("profile").prefetch_related("subscription", "subscription__plan").all().order_by("-date_joined")
    if q:
        qs = qs.filter(
            Q(username__icontains=q)
            | Q(email__icontains=q)
            | Q(first_name__icontains=q)
            | Q(last_name__icontains=q)
            | Q(profile__phone_number__icontains=q)
            | Q(profile__national_id__icontains=q)
        )
    # Role filter (from UserProfile)
    if role and role not in ("staff", "superuser", "regular"):
        qs = qs.filter(profile__role=role)
    elif role == "staff":
        qs = qs.filter(is_staff=True)
    elif role == "superuser":
        qs = qs.filter(is_superuser=True)
    elif role == "regular":
        qs = qs.filter(is_staff=False, is_superuser=False)

    if status == "active":
        qs = qs.filter(is_active=True)
    elif status == "inactive":
        qs = qs.filter(is_active=False)

    if plan_filter:
        qs = qs.filter(subscription__plan_id=plan_filter)

    # Stats
    total_users = User.objects.count()
    active_users = User.objects.filter(is_active=True).count()
    staff_users = User.objects.filter(is_staff=True).count()

    # Role choices for filter
    role_choices = UserProfile.ROLE_CHOICES

    # Available plans for filter
    plans = SubscriptionPlan.objects.filter(is_active=True)

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
            "plan_filter": plan_filter,
            "role_choices": role_choices,
            "plans": plans,
            "total_users": total_users,
            "active_users": active_users,
            "staff_users": staff_users,
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
    user = get_object_or_404(User.objects.select_related("profile"), pk=pk)
    activity = ActivityLog.objects.filter(user=user)[:20]

    # Get subscription
    subscription = None
    try:
        subscription = user.subscription
    except Exception:
        pass

    # Get sessions (from search_db or default)
    sessions = []
    try:
        from logs.models import UserSession
        # Use list() to force query execution here so we catch any DB errors!
        sessions = list(UserSession.objects.filter(user=user).order_by("-login_time")[:10])
    except Exception as e:
        print("Session error:", e)
        pass

    return render(
        request,
        "control_panel/users/detail.html",
        {
            "u": user,
            "activity": activity,
            "subscription": subscription,
            "sessions": sessions,
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
    from django.utils import timezone
    from datetime import timedelta

    Model = get_model_or_404(app_label, model_name)
    fields = visible_fields(Model)
    q = request.GET.get("q", "").strip()
    
    qs = Model._default_manager.all()
    
    # Advanced Dynamic Search
    if q:
        search_query = Q()
        for f in Model._meta.get_fields():
            if not f.concrete or f.many_to_many: continue
            if f.get_internal_type() in ("CharField", "TextField", "EmailField", "SlugField", "IntegerField"):
                search_query |= Q(**{f"{f.name}__icontains": q})
        if search_query:
            qs = qs.filter(search_query)

    # Automatic Filtering for choices or foreign keys if provided in GET
    for param, value in request.GET.items():
        if param in ("q", "page", "sort"): continue
        if value:
            try:
                # Check if param is a valid field
                f = Model._meta.get_field(param)
                if f.get_internal_type() == 'BooleanField':
                    qs = qs.filter(**{param: value == 'true'})
                else:
                    qs = qs.filter(**{param: value})
            except Exception:
                pass

    # Sorting
    sort = request.GET.get("sort")
    if sort:
        qs = qs.order_by(sort)
    else:
        # Default ordering
        if hasattr(Model._meta, 'ordering') and Model._meta.ordering:
            qs = qs.order_by(*Model._meta.ordering)
        else:
            qs = qs.order_by('-pk')

    # Generate Dynamic Filters metadata
    filterable_fields = []
    for f in Model._meta.get_fields():
        if not f.concrete or f.many_to_many: continue
        if f.is_relation and f.many_to_one:
            # Foreign Key
            try:
                related_qs = f.related_model.objects.all()[:50] # Limit to 50 for performance
                choices = [(str(obj.pk), str(obj)) for obj in related_qs]
                filterable_fields.append({"name": f.name, "verbose_name": getattr(f, 'verbose_name', f.name), "choices": choices, "type": "fk", "current": request.GET.get(f.name, "")})
            except Exception:
                pass
        elif getattr(f, 'choices', None):
            # Choice field
            filterable_fields.append({"name": f.name, "verbose_name": getattr(f, 'verbose_name', f.name), "choices": [(str(k), str(v)) for k, v in f.choices], "type": "choice", "current": request.GET.get(f.name, "")})
        elif f.get_internal_type() == 'BooleanField':
            # Boolean
            filterable_fields.append({"name": f.name, "verbose_name": getattr(f, 'verbose_name', f.name), "choices": [("true", "نعم (True)"), ("false", "لا (False)")], "type": "bool", "current": request.GET.get(f.name, "")})

    # Generate Stats
    total_count = Model._default_manager.count()
    today_count = 0
    date_field = None
    for f in Model._meta.get_fields():
        if f.get_internal_type() in ('DateTimeField', 'DateField') and getattr(f, 'auto_now_add', False):
            date_field = f.name
            break
    if not date_field:
        for f in Model._meta.get_fields():
            if f.name in ('created_at', 'date_joined'):
                date_field = f.name
                break
    
    if date_field:
        from django.utils import timezone
        today_count = Model._default_manager.filter(**{f"{date_field}__date": timezone.localdate()}).count()

    paginator = Paginator(qs, 15)
    page = paginator.get_page(request.GET.get("page"))

    rows = []
    for obj in page.object_list:
        values = []
        for f in fields:
            val = field_display(obj, f)
            values.append({"value": val, "type": f.get_internal_type()})
        rows.append({"pk": obj.pk, "values": values})

    return render(
        request,
        "control_panel/models/browse.html",
        {
            "Model": Model,
            "app_label": app_label,
            "model_name": model_name,
            "verbose_name": Model._meta.verbose_name,
            "verbose_name_plural": Model._meta.verbose_name_plural,
            "fields": fields,
            "filterable_fields": filterable_fields,
            "total_count": total_count,
            "today_count": today_count,
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
    
    if request.GET.get("popup") == "1":
        # Special response for popups: just call a JS function in parent and close
        from django.http import HttpResponse
        html = f"""
        <script>
            if (window.parent && window.parent.onQuickAddComplete) {{
                window.parent.onQuickAddComplete("{pk}", "{str(obj)}");
            }} else {{
                window.close();
            }}
        </script>
        <p>جاري التحديث...</p>
        """
        return HttpResponse(html)

    fields = []
    for f in Model._meta.get_fields():
        if f.concrete and not f.many_to_many:
            fields.append({"verbose": f.verbose_name, "value": field_display(obj, f)})
    
    return render(
        request,
        "control_panel/models/detail.html",
        {
            "Model": Model,
            "app_label": app_label,
            "model_name": model_name,
            "verbose_name": Model._meta.verbose_name,
            "obj": obj,
            "fields": fields,
            "page_title": str(obj),
            "active_section": "models",
        },
    )


@staff_required
def model_edit(request, app_label, model_name, pk=None):
    from django.forms import modelform_factory
    Model = get_model_or_404(app_label, model_name)
    instance = get_object_or_404(Model, pk=pk) if pk else None
    
    # Exclude non-editable fields
    exclude = []
    for f in Model._meta.fields:
        if not f.editable:
            exclude.append(f.name)
            
    FormClass = modelform_factory(Model, exclude=exclude)
    form = FormClass(request.POST or None, request.FILES or None, instance=instance)
    is_popup = request.GET.get("popup") == "1"
    
    # Identify related models for Quick Add (+) buttons
    related_fields = {}
    for name, field in form.fields.items():
        if hasattr(field, 'queryset'):
            rel_model = field.queryset.model
            related_fields[name] = {
                'app': rel_model._meta.app_label,
                'model': rel_model._meta.model_name,
                'verbose': rel_model._meta.verbose_name,
            }

    if request.method == "POST" and form.is_valid():
        obj = form.save()
        action = "update" if pk else "create"
        _log(request, action, target=f"{model_name}:{obj.pk}", description=f"Modified {model_name}")
        
        if is_popup:
            # If it's a popup, redirect to a special success page that closes itself
            return redirect(reverse("control_panel:model_detail", kwargs={
                "app_label": app_label, "model_name": model_name, "pk": obj.pk
            }) + "?popup=1")
            
        messages.success(request, f"تم حفظ البيانات بنجاح.")
        return redirect("control_panel:model_detail", app_label=app_label, model_name=model_name, pk=obj.pk)

        
    return render(
        request,
        "control_panel/models/form.html",
        {
            "Model": Model,
            "app_label": app_label,
            "model_name": model_name,
            "verbose_name": Model._meta.verbose_name,
            "form": form,
            "related_fields": related_fields,
            "instance": instance,
            "is_popup": is_popup,
            "page_title": f"{'تعديل' if pk else 'إضافة'} {Model._meta.verbose_name}",
            "active_section": "models",
        },
    )


@staff_required
def model_delete(request, app_label, model_name, pk):
    Model = get_model_or_404(app_label, model_name)
    obj = get_object_or_404(Model, pk=pk)
    if request.method == "POST":
        name = str(obj)
        obj.delete()
        _log(request, "delete", target=f"{model_name}:{pk}", description=f"Deleted {name}")
        messages.success(request, f"تم حذف {name} بنجاح.")
        return redirect("control_panel:model_browse", app_label=app_label, model_name=model_name)
        
    return render(
        request,
        "control_panel/models/confirm_delete.html",
        {
            "Model": Model,
            "app_label": app_label,
            "model_name": model_name,
            "verbose_name": Model._meta.verbose_name,
            "obj": obj,
            "page_title": f"تأكيد الحذف",
        },
    )


@staff_required
def model_export(request, app_label, model_name):
    import csv
    from django.http import HttpResponse
    Model = get_model_or_404(app_label, model_name)
    qs = Model._default_manager.all()
    
    # Simple CSV export
    response = HttpResponse(content_type='text/csv; charset=utf-8-sig')
    response['Content-Disposition'] = f'attachment; filename="{model_name}_export.csv"'
    
    writer = csv.writer(response)
    fields = [f for f in Model._meta.fields]
    writer.writerow([f.verbose_name for f in fields])
    
    for obj in qs:
        writer.writerow([getattr(obj, f.name) for f in fields])
        
    return response


@staff_required
def model_import(request, app_label, model_name):
    import csv, io
    Model = get_model_or_404(app_label, model_name)
    if request.method == "POST" and request.FILES.get("file"):
        file = request.FILES["file"]
        if not file.name.endswith(".csv"):
            messages.error(request, "يرجى رفع ملف CSV فقط.")
        else:
            try:
                data = file.read().decode("utf-8-sig")
                reader = csv.DictReader(io.StringIO(data))
                count = 0
                for row in reader:
                    # Map verbose names back to field names if necessary, 
                    # but here we assume the CSV header matches field names for simplicity.
                    # Or we try to match by verbose name.
                    clean_data = {}
                    for k, v in row.items():
                        # Find field by name or verbose name
                        field = None
                        for f in Model._meta.fields:
                            if f.name == k or f.verbose_name == k:
                                field = f
                                break
                        if field:
                            clean_data[field.name] = v
                    
                    Model.objects.create(**clean_data)
                    count += 1
                
                _log(request, "import", target=f"{model_name}", description=f"Imported {count} records")
                messages.success(request, f"تم استيراد {count} سجل بنجاح.")
                return redirect("control_panel:model_browse", app_label=app_label, model_name=model_name)
            except Exception as e:
                messages.error(request, f"خطأ أثناء الاستيراد: {str(e)}")
                
    return render(
        request,
        "control_panel/models/import.html",
        {
            "Model": Model,
            "page_title": f"استيراد بيانات {Model._meta.verbose_name_plural}",
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


# ──────────────────── Subscription Plans ───────────────────────────

@staff_required
def plan_list(request):
    from dashboard.models import SubscriptionPlan, UserSubscription
    plans = SubscriptionPlan.objects.all()
    plan_data = []
    for p in plans:
        sub_count = UserSubscription.objects.filter(plan=p, is_active=True).count()
        plan_data.append({"plan": p, "subscribers": sub_count})
    total_subs = UserSubscription.objects.filter(is_active=True).count()
    return render(request, "control_panel/plans/list.html", {
        "plan_data": plan_data,
        "total_subs": total_subs,
        "page_title": "خطط الاشتراك",
        "active_section": "plans",
    })


@staff_required
def plan_create(request):
    from dashboard.models import SubscriptionPlan
    if request.method == "POST":
        name = request.POST.get("name", "")
        price = request.POST.get("price", 0)
        duration = request.POST.get("duration_days", 30)
        features = {}
        for key in ["max_cases", "max_attachments"]:
            val = request.POST.get(key, "0")
            features[key] = int(val) if val else 0
        for key in ["ai_assistant", "priority_support", "legal_library", "api_access", "white_label", "custom_domain"]:
            features[key] = request.POST.get(key) == "on"
        plan = SubscriptionPlan.objects.create(
            name=name, price=price, duration_days=duration, features=features
        )
        _log(request, "create", target=f"Plan:{plan.name}")
        messages.success(request, f"تم إنشاء الخطة '{plan.name}' بنجاح.")
        return redirect("control_panel:plan_list")
    return render(request, "control_panel/plans/form.html", {
        "mode": "create",
        "page_title": "إنشاء خطة جديدة",
        "active_section": "plans",
    })


@staff_required
def plan_edit(request, pk):
    from dashboard.models import SubscriptionPlan
    plan = get_object_or_404(SubscriptionPlan, pk=pk)
    if request.method == "POST":
        plan.name = request.POST.get("name", plan.name)
        plan.price = request.POST.get("price", plan.price)
        plan.duration_days = request.POST.get("duration_days", plan.duration_days)
        plan.is_active = request.POST.get("is_active") == "on"
        features = {}
        for key in ["max_cases", "max_attachments"]:
            val = request.POST.get(key, "0")
            features[key] = int(val) if val else 0
        for key in ["ai_assistant", "priority_support", "legal_library", "api_access", "white_label", "custom_domain"]:
            features[key] = request.POST.get(key) == "on"
        plan.features = features
        plan.save()
        _log(request, "update", target=f"Plan:{plan.name}")
        messages.success(request, f"تم تحديث الخطة '{plan.name}'.")
        return redirect("control_panel:plan_list")
    return render(request, "control_panel/plans/form.html", {
        "plan": plan,
        "mode": "edit",
        "page_title": f"تعديل: {plan.name}",
        "active_section": "plans",
    })


@staff_required
@require_POST
def plan_delete(request, pk):
    from dashboard.models import SubscriptionPlan
    plan = get_object_or_404(SubscriptionPlan, pk=pk)
    name = plan.name
    plan.delete()
    _log(request, "delete", target=f"Plan:{name}")
    messages.success(request, f"تم حذف الخطة '{name}'.")
    return redirect("control_panel:plan_list")


@staff_required
def assign_plan(request, user_id):
    from dashboard.models import SubscriptionPlan, UserSubscription
    from django.utils import timezone
    from datetime import timedelta

    user = get_object_or_404(User, pk=user_id)
    plans = SubscriptionPlan.objects.filter(is_active=True)

    if request.method == "POST":
        plan_id = request.POST.get("plan_id")
        plan = get_object_or_404(SubscriptionPlan, pk=plan_id)
        sub, created = UserSubscription.objects.update_or_create(
            user=user,
            defaults={
                "plan": plan,
                "start_date": timezone.now(),
                "end_date": timezone.now() + timedelta(days=plan.duration_days),
                "is_active": True,
            }
        )
        _log(request, "update", target=f"User:{user.username}", description=f"Assigned plan: {plan.name}")
        messages.success(request, f"تم تعيين خطة '{plan.name}' للمستخدم {user.username}.")
        return redirect("control_panel:user_detail", pk=user_id)

    return render(request, "control_panel/plans/assign.html", {
        "target_user": user,
        "plans": plans,
        "page_title": f"تعيين خطة لـ {user.username}",
        "active_section": "users",
    })


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


# ──────────────────── API Documentation ────────────────────────────

@staff_required
def api_docs(request):
    """Show full API documentation extracted from the Django URL router."""
    from django.urls import get_resolver
    from rest_framework.routers import DefaultRouter
    from django.conf import settings
    import importlib

    # Build endpoint list from router
    endpoints = []
    try:
        urls_module = importlib.import_module(settings.ROOT_URLCONF)
        router = None
        for attr_name in dir(urls_module):
            attr = getattr(urls_module, attr_name)
            if isinstance(attr, DefaultRouter):
                router = attr
                break

        if router:
            for prefix, viewset, basename in router.registry:
                # Get viewset class info
                vs = viewset
                doc = (vs.__doc__ or "").strip()
                model_name = getattr(vs, 'queryset', None)
                model_label = ""
                if model_name is not None:
                    try:
                        model_label = model_name.model._meta.verbose_name
                    except Exception:
                        pass

                # Determine allowed methods
                actions = []
                if hasattr(vs, 'list'):
                    actions.append({"method": "GET", "suffix": "/", "desc": "عرض القائمة"})
                if hasattr(vs, 'create'):
                    actions.append({"method": "POST", "suffix": "/", "desc": "إنشاء جديد"})
                if hasattr(vs, 'retrieve'):
                    actions.append({"method": "GET", "suffix": "/{id}/", "desc": "عرض التفاصيل"})
                if hasattr(vs, 'update'):
                    actions.append({"method": "PUT", "suffix": "/{id}/", "desc": "تعديل كامل"})
                if hasattr(vs, 'partial_update'):
                    actions.append({"method": "PATCH", "suffix": "/{id}/", "desc": "تعديل جزئي"})
                if hasattr(vs, 'destroy'):
                    actions.append({"method": "DELETE", "suffix": "/{id}/", "desc": "حذف"})

                # Get serializer fields
                fields_info = []
                serializer_class = getattr(vs, 'serializer_class', None)
                if serializer_class:
                    try:
                        ser = serializer_class()
                        for fname, fobj in ser.fields.items():
                            fields_info.append({
                                "name": fname,
                                "type": type(fobj).__name__.replace("Field", ""),
                                "required": fobj.required,
                                "read_only": fobj.read_only,
                                "label": str(getattr(fobj, 'label', fname) or fname),
                            })
                    except Exception:
                        pass

                # Get filter/search/ordering
                filter_fields = getattr(vs, 'filterset_fields', getattr(vs, 'filter_fields', []))
                search_fields = getattr(vs, 'search_fields', [])
                ordering_fields = getattr(vs, 'ordering_fields', [])

                endpoints.append({
                    "prefix": f"/api/{prefix}/",
                    "basename": basename,
                    "viewset": vs.__name__,
                    "doc": doc,
                    "model_label": model_label,
                    "actions": actions,
                    "fields": fields_info,
                    "filter_fields": list(filter_fields) if filter_fields else [],
                    "search_fields": list(search_fields) if search_fields else [],
                    "ordering_fields": list(ordering_fields) if ordering_fields else [],
                })
    except Exception as e:
        messages.warning(request, f"خطأ في تحليل الـ API: {e}")

    # Non-router endpoints
    extra_endpoints = [
        {"prefix": "/api/token/", "method": "POST", "desc": "الحصول على JWT Token (تسجيل الدخول)", "group": "المصادقة"},
        {"prefix": "/api/token/refresh/", "method": "POST", "desc": "تجديد JWT Token", "group": "المصادقة"},
        {"prefix": "/api/register/", "method": "POST", "desc": "تسجيل مستخدم جديد", "group": "المصادقة"},
        {"prefix": "/api/notifications/", "method": "GET", "desc": "قائمة الإشعارات", "group": "الإشعارات"},
        {"prefix": "/api/notifications/mark-all-read/", "method": "POST", "desc": "قراءة جميع الإشعارات", "group": "الإشعارات"},
        {"prefix": "/api/ai/chat/", "method": "POST", "desc": "محادثة مع المساعد الذكي", "group": "الذكاء الاصطناعي"},
        {"prefix": "/api/ai/documents/add/", "method": "POST", "desc": "إضافة مستندات للمساعد", "group": "الذكاء الاصطناعي"},
        {"prefix": "/api/messaging/messages/", "method": "GET/POST", "desc": "الرسائل المباشرة", "group": "الرسائل"},
        {"prefix": "/health/", "method": "GET", "desc": "فحص صحة الخادم", "group": "النظام"},
        {"prefix": "/swagger/", "method": "GET", "desc": "توثيق API التفاعلي", "group": "التوثيق"},
        {"prefix": "/redoc/", "method": "GET", "desc": "توثيق API (ReDoc)", "group": "التوثيق"},
    ]

    # Group the endpoints by service
    groups = {}
    for ep in endpoints:
        prefix = ep["prefix"].replace("/api/", "").rstrip("/").split("/")[0]
        service = _classify_endpoint(prefix)
        groups.setdefault(service, []).append(ep)

    return render(
        request,
        "control_panel/api_docs.html",
        {
            "page_title": "توثيق API والـ Endpoints",
            "active_section": "api_docs",
            "endpoints": endpoints,
            "extra_endpoints": extra_endpoints,
            "groups": groups,
            "total_endpoints": len(endpoints),
        },
    )


def _classify_endpoint(prefix):
    """Classify endpoint prefix into service group."""
    mapping = {
        "profiles": "المستخدمون والحسابات",
        "user-sessions": "المستخدمون والحسابات",
        "cases": "القضايا والدعاوى",
        "lawsuits": "القضايا والدعاوى",
        "case-parties": "القضايا والدعاوى",
        "legal-templates": "القضايا والدعاوى",
        "financial-claims": "القضايا والدعاوى",
        "case-file-items": "القضايا والدعاوى",
        "plaintiffs": "الأطراف",
        "defendants": "الأطراف",
        "responses": "الردود والطعون",
        "appeals": "الردود والطعون",
        "hearings": "الجلسات",
        "judgments": "الأحكام",
        "attachments": "المرفقات",
        "audit-logs": "سجل المراجعة",
        "governorates": "المحاكم والمواقع",
        "districts": "المحاكم والمواقع",
        "court-types": "المحاكم والمواقع",
        "court-specializations": "المحاكم والمواقع",
        "courts": "المحاكم والمواقع",
        "payment-orders": "المدفوعات",
        "legal-categories": "القوانين والتشريعات",
        "laws": "القوانين والتشريعات",
        "law-chapters": "القوانين والتشريعات",
        "law-sections": "القوانين والتشريعات",
        "law-articles": "القوانين والتشريعات",
        "case-legal-references": "القوانين والتشريعات",
        "legal-library": "المكتبة القانونية",
        "legal-procedures": "المكتبة القانونية",
        "lawyers": "المحامون",
        "lawyer-filter-options": "المحامون",
        "search-logs": "البحث والسجلات",
        "ai-chat-logs": "البحث والسجلات",
    }
    return mapping.get(prefix, "أخرى")


# ──────────────────── System Settings ──────────────────────────────

@staff_required
def system_settings(request):
    """Show all Django settings and database configuration."""
    from django.conf import settings as django_settings
    import sys

    # Database info
    db_info = []
    for alias, conf in django_settings.DATABASES.items():
        db_info.append({
            "alias": alias,
            "engine": conf.get("ENGINE", "").split(".")[-1],
            "name": conf.get("NAME", ""),
            "host": conf.get("HOST", "localhost"),
            "port": conf.get("PORT", ""),
            "user": conf.get("USER", ""),
        })

    # Installed apps
    installed_apps = list(django_settings.INSTALLED_APPS)

    # Middleware
    middleware = list(django_settings.MIDDLEWARE)

    # REST Framework config
    rest_config = {}
    if hasattr(django_settings, 'REST_FRAMEWORK'):
        for k, v in django_settings.REST_FRAMEWORK.items():
            rest_config[k] = str(v)

    # JWT config
    jwt_config = {}
    if hasattr(django_settings, 'SIMPLE_JWT'):
        for k, v in django_settings.SIMPLE_JWT.items():
            jwt_config[k] = str(v)

    # General settings
    general = {
        "DEBUG": django_settings.DEBUG,
        "ALLOWED_HOSTS": django_settings.ALLOWED_HOSTS,
        "LANGUAGE_CODE": django_settings.LANGUAGE_CODE,
        "TIME_ZONE": django_settings.TIME_ZONE,
        "STATIC_URL": django_settings.STATIC_URL,
        "MEDIA_URL": django_settings.MEDIA_URL,
        "DEFAULT_AUTO_FIELD": django_settings.DEFAULT_AUTO_FIELD,
        "ROOT_URLCONF": django_settings.ROOT_URLCONF,
        "WSGI_APPLICATION": django_settings.WSGI_APPLICATION,
        "CORS_ALLOW_ALL_ORIGINS": getattr(django_settings, 'CORS_ALLOW_ALL_ORIGINS', False),
        "X_FRAME_OPTIONS": getattr(django_settings, 'X_FRAME_OPTIONS', 'DENY'),
        "Python Version": sys.version.split()[0],
        "Django Version": __import__('django').get_version(),
    }

    # Database routers
    db_routers = getattr(django_settings, 'DATABASE_ROUTERS', [])

    return render(
        request,
        "control_panel/system_settings.html",
        {
            "page_title": "إعدادات النظام",
            "active_section": "settings",
            "db_info": db_info,
            "installed_apps": installed_apps,
            "middleware": middleware,
            "rest_config": rest_config,
            "jwt_config": jwt_config,
            "general": general,
            "db_routers": db_routers,
        },
    )

