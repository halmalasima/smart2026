"""
Django signals for auto-linking hearings to CaseFileItem
"""
from django.db.models.signals import post_save
from django.dispatch import receiver
from .models import Hearing


@receiver(post_save, sender=Hearing)
def create_case_file_item_for_hearing(sender, instance, created, **kwargs):
    """
    Create a CaseFileItem when a new Hearing is created
    """
    if created:
        from lawsuits.models_casefile import CaseFileItem
        
        # Check if already linked
        existing = CaseFileItem.objects.filter(
            lawsuit=instance.lawsuit,
            related_object_id=instance.id,
            related_object_type='hearing'
        ).exists()
        
        if not existing:
            CaseFileItem.objects.create(
                lawsuit=instance.lawsuit,
                item_type=CaseFileItem.TYPE_HEARING_RECORD,
                title=f'جلسة - {instance.hearing_date}',
                description=instance.notes[:200] if instance.notes else '',
                related_object_id=instance.id,
                related_object_type='hearing',
                created_by=instance.created_by,
                sort_order=100,
            )
