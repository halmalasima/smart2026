"""
Signals for automatic audit logging
"""
from django.db.models.signals import post_save
from django.dispatch import receiver
from django.contrib.auth.models import User
from audit.models import AuditLog
from lawsuits.models import Lawsuit
from parties.models import Plaintiff, Defendant
from responses.models import Response
from appeals.models import Appeal
from judgments.models import Judgment
# hearings and attachments are in separate services — audit via Redis events instead


def get_current_user():
    """
    Helper function to get the current user from thread-local storage
    This should be set in middleware or views
    """
    # This is a placeholder - in production, you'd get this from request middleware
    # For now, we'll use the created_by field if available
    return None


@receiver(post_save, sender=Lawsuit)
def log_lawsuit_created(sender, instance, created, **kwargs):
    """
    Log when a lawsuit is created
    """
    if created:
        AuditLog.objects.create(
            action_type=AuditLog.ACTION_LAWSUIT_CREATED,
            user=instance.created_by,
            lawsuit=instance,
            description=f'تم إنشاء دعوى رقم {instance.case_number} - {instance.subject}',
            metadata={
                'case_number': instance.case_number,
                'case_type': instance.case_type,
                'court': instance.court,
            }
        )


@receiver(post_save, sender=Plaintiff)
def log_plaintiff_added(sender, instance, created, **kwargs):
    """
    Log when a plaintiff is added
    """
    if created:
        AuditLog.objects.create(
            action_type=AuditLog.ACTION_PARTY_ADDED,
            user=None,  # Can be set from request context if needed
            lawsuit=instance.lawsuit,
            description=f'تم إضافة مدعي: {instance.name} للدعوى {instance.lawsuit.case_number}',
            metadata={
                'party_type': 'plaintiff',
                'party_name': instance.name,
                'party_id': instance.id,
            }
        )


@receiver(post_save, sender=Defendant)
def log_defendant_added(sender, instance, created, **kwargs):
    """
    Log when a defendant is added
    """
    if created:
        AuditLog.objects.create(
            action_type=AuditLog.ACTION_PARTY_ADDED,
            user=None,
            lawsuit=instance.lawsuit,
            description=f'تم إضافة مدعى عليه: {instance.name} للدعوى {instance.lawsuit.case_number}',
            metadata={
                'party_type': 'defendant',
                'party_name': instance.name,
                'party_id': instance.id,
            }
        )



# Attachment audit is handled via Redis event from documents-service


@receiver(post_save, sender=Response)
def log_response_submitted(sender, instance, created, **kwargs):
    """
    Log when a response is submitted
    """
    if created:
        AuditLog.objects.create(
            action_type=AuditLog.ACTION_RESPONSE_SUBMITTED,
            user=instance.submitted_by_user,
            lawsuit=instance.lawsuit,
            description=f'تم تقديم {instance.get_response_type_display()} للدعوى {instance.lawsuit.case_number}',
            metadata={
                'response_type': instance.response_type,
                'submitted_by': instance.submitted_by,
                'submission_date': instance.submission_date.isoformat() if instance.submission_date else None,
                'response_id': instance.id,
            }
        )


@receiver(post_save, sender=Appeal)
def log_appeal_filed(sender, instance, created, **kwargs):
    """
    Log when an appeal is filed
    """
    if created:
        AuditLog.objects.create(
            action_type=AuditLog.ACTION_APPEAL_FILED,
            user=instance.submitted_by_user,
            lawsuit=instance.lawsuit,
            description=f'تم تقديم طعن {instance.get_appeal_type_display()} رقم {instance.appeal_number} للدعوى {instance.lawsuit.case_number}',
            metadata={
                'appeal_type': instance.appeal_type,
                'appeal_number': instance.appeal_number,
                'higher_court': instance.higher_court,
                'appeal_id': instance.id,
            }
        )


@receiver(post_save, sender=Judgment)
def log_judgment_issued(sender, instance, created, **kwargs):
    """
    Log when a judgment is issued
    """
    if created:
        AuditLog.objects.create(
            action_type=AuditLog.ACTION_JUDGMENT_ISSUED,
            user=instance.judge or instance.created_by,
            lawsuit=instance.lawsuit,
            description=f'تم إصدار حكم {instance.get_judgment_type_display()} رقم {instance.judgment_number} للدعوى {instance.lawsuit.case_number}',
            metadata={
                'judgment_type': instance.judgment_type,
                'judgment_number': instance.judgment_number,
                'judge_name': instance.judge_name,
                'court_name': instance.court_name,
                'judgment_id': instance.id,
            }
        )



# Hearing audit is handled via Redis event from hearings-service

