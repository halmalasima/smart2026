"""
Django signals for hearings-service.
Publishes Redis events so other services (cases, notifications) can react.
"""
from django.db.models.signals import post_save
from django.dispatch import receiver
from .models import Hearing


@receiver(post_save, sender=Hearing)
def publish_hearing_event(sender, instance, created, **kwargs):
    """Publish a Redis event when a hearing is created or updated."""
    if not created:
        return
    try:
        from smartjudi_common.events import EventPublisher
        publisher = EventPublisher()
        publisher.publish(
            channel='hearings',
            event_type='hearing.scheduled',
            payload={
                'hearing_id': instance.id,
                'lawsuit_id': instance.lawsuit_id,
                'lawsuit_case_number': instance.lawsuit_case_number,
                'hearing_date': str(instance.hearing_date),
                'hearing_type': instance.hearing_type,
                'created_by_id': instance.created_by_id,
            },
        )
    except Exception:
        pass
