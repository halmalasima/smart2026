import logging
import secrets
import string
from django.contrib.auth.models import User
from django.db import transaction
from .models import CaseParty

logger = logging.getLogger(__name__)

class CasePartyService:
    """
    Service Layer for CaseParty business logic.
    Handles party creation and associated user account management.
    """

    @staticmethod
    @transaction.atomic
    def create_party(data, request_user):
        """
        Creates a CaseParty and optionally auto-creates a user account if the role is 'client'.
        """
        # 1. Create the party using standard Django logic (or repository if available)
        # For now, we'll use the model directly to keep it simple as a first step
        party = CaseParty.objects.create(**data)
        
        generated_password = None
        account_created = False

        # 2. Business Logic: Auto-create user account for client (الموكل) if phone is provided
        if party.role == CaseParty.ROLE_CLIENT and party.phone:
            if not party.user_account:
                username = party.phone.strip()
                # Check if user already exists
                user = User.objects.filter(username=username).first()
                created = False
                
                if not user:
                    password = ''.join(secrets.choice(string.ascii_letters + string.digits) for _ in range(8))
                    user = User.objects.create(
                        username=username,
                        first_name=party.name or '',
                        is_active=True
                    )
                    user.set_password(password)
                    user.save()
                    created = True
                    generated_password = password
                    account_created = True

                # Link profile
                if hasattr(user, 'profile'):
                    user.profile.role = 'citizen'
                    user.profile.phone_number = username
                    user.profile.supervisor = request_user
                    user.profile.save()

                party.user_account = user
                party.save(update_fields=['user_account'])

        return party, generated_password, account_created


class LawsuitService:
    """
    Service Layer for Lawsuit business logic.
    Handles soft deletion, complex updates, and validation.
    """

    @staticmethod
    def soft_delete(instance):
        """
        Performs a soft delete on a Lawsuit instance.
        """
        from django.utils import timezone
        from django.core.cache import cache
        
        instance.is_deleted = True
        instance.deleted_at = timezone.now()
        instance.save(update_fields=['is_deleted', 'deleted_at'])
        
        # Invalidate cache
        cache.clear() # Simple approach for now, can be targeted later
        return instance

    @staticmethod
    def update_lawsuit(instance, validated_data):
        """
        Updates a lawsuit and clears cache.
        """
        from django.core.cache import cache
        for attr, value in validated_data.items():
            setattr(instance, attr, value)
        instance.save()
        cache.clear()
        return instance

    @staticmethod
    def can_modify(instance, user):
        """
        Check if user has permission to modify the lawsuit.
        """
        from smartjudi_common.user_utils import get_user_role
        if get_user_role(user) == 'citizen' and instance.created_by_id != user.id:
            return False
        return True
