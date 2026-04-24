"""
Django signals for auto-linking payment orders to CaseFileItem
"""
from django.db.models.signals import post_save
from django.dispatch import receiver
from .models import PaymentOrder


@receiver(post_save, sender=PaymentOrder)
def create_case_file_item_for_payment_order(sender, instance, created, **kwargs):
    """
    Create a CaseFileItem when a new PaymentOrder is created
    """
    if created:
        from lawsuits.models_casefile import CaseFileItem
        
        # Check if already linked
        existing = CaseFileItem.objects.filter(
            lawsuit=instance.lawsuit,
            related_object_id=instance.id,
            related_object_type='payment_order'
        ).exists()
        
        if not existing:
            CaseFileItem.objects.create(
                lawsuit=instance.lawsuit,
                item_type=CaseFileItem.TYPE_PAYMENT_ORDER,
                title=f'أمر أداء - {instance.order_number or instance.id}',
                description=instance.description or f'مبلغ: {instance.amount}',
                related_object_id=instance.id,
                related_object_type='payment_order',
                sort_order=100,
            )
