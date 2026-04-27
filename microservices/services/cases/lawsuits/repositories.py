from django.db.models import Q
from .models import Lawsuit

class LawsuitRepository:
    """
    Repository Layer for Lawsuit data access.
    Encapsulates QuerySet logic and complex filters.
    """

    @staticmethod
    def get_base_queryset():
        """Returns the base queryset with necessary select_related and prefetch_related"""
        return Lawsuit.objects.select_related(
            'parent_lawsuit', 'archived_by'
        ).prefetch_related(
            'financial_claims', 'plaintiffs', 'defendants'
        )

    @staticmethod
    def get_for_user(user, user_role):
        """
        Returns lawsuits visible to a specific user based on their role and permissions.
        """
        uid = user.id
        queryset = LawsuitRepository.get_base_queryset()
        
        # 1. Basic role-based isolation
        if user_role == 'admin':
            return queryset
            
        if user_role == 'citizen':
            return queryset.filter(Q(created_by=uid) | Q(client=uid))
            
        if user_role == 'assistant':
            supervisor_id = None
            try:
                sup = user.profile.supervisor
                supervisor_id = sup.id if sup else None
            except Exception:
                pass
            if supervisor_id:
                return queryset.filter(
                    Q(created_by=supervisor_id) | Q(client=supervisor_id) | Q(created_by=uid)
                )
            return queryset.filter(created_by=uid)
            
        if user_role in ('lawyer', 'notary'):
            return queryset.filter(Q(created_by=uid) | Q(client=uid))
            
        return queryset.none()

    @staticmethod
    def filter_active(queryset):
        """Filter out soft-deleted items"""
        return queryset.filter(is_deleted=False)

    @staticmethod
    def filter_parents_only(queryset):
        """Filter out child lawsuits"""
        return queryset.filter(parent_lawsuit__isnull=True)

    @staticmethod
    def filter_main_archive(queryset):
        """Exclude specific case types from main archive"""
        return queryset.exclude(case_type__in=['طعن', 'استئناف', 'امر_اداء'])
