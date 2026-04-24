"""
Django signals for auto-linking judgments to CaseFileItem
"""
from django.db.models.signals import post_save
from django.dispatch import receiver
from .models import Judgment


@receiver(post_save, sender=Judgment)
def create_case_file_item_for_judgment(sender, instance, created, **kwargs):
    """
    Create a CaseFileItem when a new Judgment is created
    """
    if created:
        from lawsuits.models_casefile import CaseFileItem
        
        # Check if already linked
        existing = CaseFileItem.objects.filter(
            lawsuit=instance.lawsuit,
            related_object_id=instance.id,
            related_object_type='judgment'
        ).exists()
        
        if not existing:
            CaseFileItem.objects.create(
                lawsuit=instance.lawsuit,
                item_type=CaseFileItem.TYPE_JUDGMENT,
                title=f'حكم - {instance.judgment_number}',
                description=instance.judgment_text[:200] if instance.judgment_text else '',
                related_object_id=instance.id,
                related_object_type='judgment',
                created_by=instance.judge,
                sort_order=100,
            )
