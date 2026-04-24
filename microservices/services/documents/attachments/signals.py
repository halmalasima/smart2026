"""
Django signals for documents-service.
Publishes Redis events so the cases-service can create a CaseFileItem.
"""
from django.db.models.signals import post_save
from django.dispatch import receiver
from .models import Attachment


@receiver(post_save, sender=Attachment)
def publish_attachment_event(sender, instance, created, **kwargs):
    """Publish a Redis event when a new attachment is uploaded."""
    if not created:
        return
    try:
        from smartjudi_common.events import EventPublisher
        publisher = EventPublisher()
        publisher.publish(
            channel='documents',
            event_type='attachment.created',
            payload={
                'attachment_id': instance.id,
                'lawsuit_id': instance.lawsuit_id,
                'lawsuit_case_number': instance.lawsuit_case_number,
                'document_type': instance.document_type,
                'original_filename': instance.original_filename or '',
                'file_size': instance.file_size,
            },
        )
    except Exception:
        pass
