from django.db import models
from .user_utils import get_user_role

class UserIsolationAdminMixin:
    """
    Mixin for ModelAdmin to enforce user isolation.
    - Superusers see everything.
    - Others see only their own data (based on created_by or owner field).
    """
    user_field = 'created_by'

    def get_queryset(self, request):
        qs = super().get_queryset(request)
        if request.user.is_superuser:
            return qs
        
        # Check if the model has the user_field
        if hasattr(self.model, self.user_field):
            return qs.filter(**{self.user_field: request.user.id})
        
        return qs

    def save_model(self, request, obj, form, change):
        if not change and hasattr(obj, self.user_field):
            setattr(obj, self.user_field, request.user.id)
        super().save_model(request, obj, form, change)
