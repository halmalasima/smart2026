from django.urls import path

from . import views

app_name = "control_panel"

urlpatterns = [
    # Auth
    path("login/", views.login_view, name="login"),
    path("logout/", views.logout_view, name="logout"),
    path("theme/toggle/", views.toggle_theme, name="toggle_theme"),

    # Dashboard
    path("", views.dashboard, name="dashboard"),

    # Users
    path("users/", views.user_list, name="user_list"),
    path("users/new/", views.user_create, name="user_create"),
    path("users/<int:pk>/", views.user_detail, name="user_detail"),
    path("users/<int:pk>/edit/", views.user_update, name="user_update"),
    path("users/<int:pk>/delete/", views.user_delete, name="user_delete"),
    path("users/<int:pk>/toggle/", views.user_toggle_active, name="user_toggle_active"),
    path("users/bulk-action/", views.user_bulk_action, name="user_bulk_action"),

    # Groups / Roles
    path("groups/", views.group_list, name="group_list"),
    path("groups/new/", views.group_create, name="group_create"),
    path("groups/<int:pk>/edit/", views.group_update, name="group_update"),
    path("groups/<int:pk>/delete/", views.group_delete, name="group_delete"),

    # Subscription Plans
    path("plans/", views.plan_list, name="plan_list"),
    path("plans/new/", views.plan_create, name="plan_create"),
    path("plans/<int:pk>/edit/", views.plan_edit, name="plan_edit"),
    path("plans/<int:pk>/delete/", views.plan_delete, name="plan_delete"),
    path("users/<int:user_id>/assign-plan/", views.assign_plan, name="assign_plan"),

    # Generic models browser
    path("models/", views.models_index, name="models_index"),
    path("models/<str:app_label>/<str:model_name>/", views.model_browse, name="model_browse"),
    path("models/<str:app_label>/<str:model_name>/add/", views.model_edit, name="model_create"),
    path("models/<str:app_label>/<str:model_name>/export/", views.model_export, name="model_export"),
    path("models/<str:app_label>/<str:model_name>/import/", views.model_import, name="model_import"),
    path("models/<str:app_label>/<str:model_name>/<str:pk>/", views.model_detail, name="model_detail"),
    path("models/<str:app_label>/<str:model_name>/<str:pk>/edit/", views.model_edit, name="model_edit"),
    path("models/<str:app_label>/<str:model_name>/<str:pk>/delete/", views.model_delete, name="model_delete"),
    path("models/<str:app_label>/<str:model_name>/bulk-action/", views.model_bulk_action, name="model_bulk_action"),

    # Microservices
    path("microservices/", views.microservices_index, name="microservices_index"),
    path("microservices/status.json", views.microservices_status, name="microservices_status"),

    # API Documentation
    path("api-docs/", views.api_docs, name="api_docs"),

    # System Settings
    path("settings/", views.system_settings, name="system_settings"),

    # Activity / Profile
    path("activity/", views.activity_log, name="activity_log"),
    path("profile/", views.profile, name="profile"),
    
    # SaaS Pro: Services & Roles Management
    path("services/", views.services_management, name="services_management"),
    path("services/toggle/", views.service_toggle, name="service_toggle"),
    path("services/update-limit/", views.service_update_limit, name="service_update_limit"),
    path("services/analytics/", views.services_analytics, name="services_analytics"),
]
