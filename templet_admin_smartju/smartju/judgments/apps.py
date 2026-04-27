from django.apps import AppConfig


class JudgmentsConfig(AppConfig):
    default_auto_field = 'django.db.models.BigAutoField'
    name = 'judgments'

    def ready(self):
        import judgments.signals

