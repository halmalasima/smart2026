"""
Django signals for auto-linking appeals to CaseFileItem
"""
from django.db.models.signals import post_save
from django.dispatch import receiver
from .models import Appeal


@receiver(post_save, sender=Appeal)
def create_case_file_item_for_appeal(sender, instance, created, **kwargs):
    """
    Create a CaseFileItem when a new Appeal is created
    """
    if created:
        from lawsuits.models_casefile import CaseFileItem
        
        # Check if already linked
        existing = CaseFileItem.objects.filter(
            lawsuit=instance.lawsuit,
            related_object_id=instance.id,
            related_object_type='appeal'
        ).exists()
        
        if not existing:
            CaseFileItem.objects.create(
                lawsuit=instance.lawsuit,
                item_type=CaseFileItem.TYPE_APPEAL,
                title=f'طعن - {instance.appeal_number}',
                description=instance.appeal_reasons[:200] if instance.appeal_reasons else '',
                related_object_id=instance.id,
                related_object_type='appeal',
                created_by=instance.submitted_by_user,
                sort_order=100,
            )
