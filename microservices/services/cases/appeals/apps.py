from django.apps import AppConfig


class AppealsConfig(AppConfig):
    default_auto_field = 'django.db.models.BigAutoField'
    name = 'appeals'

    def ready(self):
        import appeals.signals

