from django.db.models.signals import post_migrate
from django.dispatch import receiver


@receiver(post_migrate)
def _sync_services_post_migrate(sender, **kwargs):
    if sender.label != "control_panel":
        return

    try:
        from django.core.management import call_command

        call_command("sync_services")
    except Exception:
        # Avoid breaking migrations if sync fails.
        return
