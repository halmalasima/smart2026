"""Tests for automatic services sync (manifest -> ServiceDefinition)."""

from django.core.management import call_command
from django.test import TestCase

from control_panel.models import ServiceDefinition


class SyncServicesCommandTest(TestCase):
    databases = {"default", "auth_db"}

    def test_sync_services_creates_rows(self):
        ServiceDefinition.objects.all().delete()
        call_command("sync_services")
        self.assertGreater(ServiceDefinition.objects.count(), 0)

    def test_sync_services_idempotent(self):
        call_command("sync_services")
        count1 = ServiceDefinition.objects.count()
        call_command("sync_services")
        count2 = ServiceDefinition.objects.count()
        self.assertEqual(count1, count2)
