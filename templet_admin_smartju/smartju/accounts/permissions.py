"""
Custom permissions for accounts app
"""
from rest_framework import permissions


class IsJudge(permissions.BasePermission):
    """
    Permission to check if user is a judge
    """
    def has_permission(self, request, view):
        return (
            request.user and
            request.user.is_authenticated and
            hasattr(request.user, 'profile') and
            request.user.profile.role == 'judge'
        )


class IsLawyer(permissions.BasePermission):
    """
    Permission to check if user is a lawyer
    """
    def has_permission(self, request, view):
        return (
            request.user and
            request.user.is_authenticated and
            hasattr(request.user, 'profile') and
            request.user.profile.role == 'lawyer'
        )


class IsJudgeOrAdmin(permissions.BasePermission):
    """
    Permission to check if user is a judge or admin
    """
    def has_permission(self, request, view):
        if not (request.user and request.user.is_authenticated):
            return False
        if not hasattr(request.user, 'profile'):
            return False
        return request.user.profile.role in ['judge', 'admin'] or request.user.is_staff


class IsJudgeOrLawyerOrAdmin(permissions.BasePermission):
    """
    Permission to check if user is a judge, lawyer, or admin
    """
    def has_permission(self, request, view):
        if not (request.user and request.user.is_authenticated):
            return False
        if not hasattr(request.user, 'profile'):
            return False
        return request.user.profile.role in ['judge', 'lawyer', 'admin'] or request.user.is_staff

