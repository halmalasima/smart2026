"""
Django signals for auto-linking attachments to CaseFileItem
"""
from django.db.models.signals import post_save
from django.dispatch import receiver
from .models import Attachment


@receiver(post_save, sender=Attachment)
def create_case_file_item_for_attachment(sender, instance, created, **kwargs):
    """
    Create a CaseFileItem when a new Attachment is created
    """
    if created:
        from lawsuits.models_casefile import CaseFileItem
        
        # Check if already linked
        existing = CaseFileItem.objects.filter(
            lawsuit=instance.lawsuit,
            related_object_id=instance.id,
            related_object_type='attachment'
        ).exists()
        
        if not existing:
            CaseFileItem.objects.create(
                lawsuit=instance.lawsuit,
                item_type=CaseFileItem.TYPE_DOCUMENT,
                title=instance.content or instance.original_filename or f'مرفق #{instance.id}',
                description=instance.evidence_basis or '',
                file=instance.file,
                original_filename=instance.original_filename or '',
                file_size=instance.file_size,
                related_object_id=instance.id,
                related_object_type='attachment',
                created_by=instance.uploaded_by if hasattr(instance, 'uploaded_by') else None,
                sort_order=50,  # Documents show earlier
            )
