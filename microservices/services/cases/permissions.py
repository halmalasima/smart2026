"""
Role-based permissions for cases-service.
Checks user.profile.role when available (requires accounts app in same DB),
otherwise falls back to IsAuthenticated.
"""
from rest_framework import permissions


class IsJudgeOrLawyerOrAdmin(permissions.IsAuthenticated):
    def has_permission(self, request, view):
        if not super().has_permission(request, view):
            return False
        profile = getattr(request.user, 'profile', None)
        if profile is None:
            return True  # Allow if profile not found (auth-only DB)
        return profile.role in ['judge', 'lawyer', 'admin'] or request.user.is_staff


class IsJudgeOrAdmin(permissions.IsAuthenticated):
    def has_permission(self, request, view):
        if not super().has_permission(request, view):
            return False
        profile = getattr(request.user, 'profile', None)
        if profile is None:
            return True
        return profile.role in ['judge', 'admin'] or request.user.is_staff


class IsAdminRole(permissions.IsAuthenticated):
    def has_permission(self, request, view):
        if not super().has_permission(request, view):
            return False
        profile = getattr(request.user, 'profile', None)
        if profile is None:
            return request.user.is_staff
        return profile.role == 'admin' or request.user.is_staff
