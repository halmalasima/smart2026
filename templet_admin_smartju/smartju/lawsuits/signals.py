"""
Django signals for auto-linking lawsuit items to CaseFileItem
"""
from django.db.models.signals import post_save
from django.dispatch import receiver
from .models import Lawsuit
from .models_casefile import CaseFileItem


@receiver(post_save, sender=Lawsuit)
def create_case_file_item_for_lawsuit(sender, instance, created, **kwargs):
    """
    Create a CaseFileItem when a new Lawsuit is created
    """
    if created:
        CaseFileItem.objects.create(
            lawsuit=instance,
            item_type=CaseFileItem.TYPE_LAWSUIT,
            title=f'دعوى - {instance.case_number or "بدون رقم"}',
            description=instance.subject or '',
            related_object_id=instance.id,
            related_object_type='lawsuit',
            created_by=instance.created_by,
            sort_order=0,
        )


def auto_link_to_case_file(lawsuit, item_type, title, description, related_object_id, 
                          related_object_type, created_by=None):
    """
    Helper function to create CaseFileItem for any related object
    """
    # Check if already linked
    existing = CaseFileItem.objects.filter(
        lawsuit=lawsuit,
        related_object_id=related_object_id,
        related_object_type=related_object_type
    ).exists()
    
    if not existing:
        CaseFileItem.objects.create(
            lawsuit=lawsuit,
            item_type=item_type,
            title=title,
            description=description or '',
            related_object_id=related_object_id,
            related_object_type=related_object_type,
            created_by=created_by,
            sort_order=100,  # Default sort order for auto-linked items
        )


# Signal handlers will be connected in apps.py
