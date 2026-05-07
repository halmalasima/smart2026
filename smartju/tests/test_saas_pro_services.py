"""SaaS Pro Tests - Role-based services & usage logging."""

from django.contrib.auth.models import User
from django.test import TestCase
from rest_framework import status
from rest_framework.test import APIClient
from rest_framework_simplejwt.tokens import RefreshToken

from accounts.models import UserProfile
from control_panel.models import RoleServicePermission, ServiceDefinition, ServiceUsageLog


class SaaSProServicesTest(TestCase):
    databases = {"default", "auth_db"}

    def setUp(self):
        self.client = APIClient()

        self.user = User.objects.create_user(
            username="u1",
            email="u1@example.com",
            password="pass12345",
        )
        self.user.profile.role = UserProfile.ROLE_LAWYER
        self.user.profile.save()

        self.svc_chat = ServiceDefinition.objects.create(
            key="/test/chat",
            name_ar="المساعد الذكي",
            name_en="Chat",
            icon="message",
            category="ai",
            is_active=True,
            is_premium=False,
            sort_order=1,
        )
        self.svc_lawsuits = ServiceDefinition.objects.create(
            key="/test/lawsuits",
            name_ar="أرشيف القضايا",
            name_en="Lawsuits",
            icon="folder",
            category="legal",
            is_active=True,
            is_premium=False,
            sort_order=2,
        )

        RoleServicePermission.objects.create(
            role=UserProfile.ROLE_LAWYER,
            service=self.svc_chat,
            is_enabled=True,
            max_daily_uses=0,
            max_monthly_uses=0,
        )
        RoleServicePermission.objects.create(
            role=UserProfile.ROLE_LAWYER,
            service=self.svc_lawsuits,
            is_enabled=False,
            max_daily_uses=0,
            max_monthly_uses=0,
        )

    def _auth(self):
        token = str(RefreshToken.for_user(self.user).access_token)
        self.client.credentials(HTTP_AUTHORIZATION=f"Bearer {token}")

    def test_my_services_requires_auth(self):
        resp = self.client.get("/api/services/my-services/")
        self.assertEqual(resp.status_code, status.HTTP_401_UNAUTHORIZED)

    def test_my_services_returns_enabled_services_for_role(self):
        self._auth()
        resp = self.client.get("/api/services/my-services/")
        self.assertEqual(resp.status_code, status.HTTP_200_OK)
        self.assertIn("services", resp.data)

        keys = [s["key"] for s in resp.data["services"]]
        self.assertIn("/test/chat", keys)
        self.assertNotIn("/test/lawsuits", keys)

    def test_log_usage_creates_service_usage_log(self):
        self._auth()
        self.assertEqual(ServiceUsageLog.objects.count(), 0)

        resp = self.client.post(
            "/api/services/log-usage/",
            {"service_key": "/test/chat", "duration_seconds": 12},
            format="json",
            HTTP_USER_AGENT="dart",
        )
        self.assertEqual(resp.status_code, status.HTTP_200_OK)
        self.assertEqual(resp.data["status"], "logged")

        self.assertEqual(ServiceUsageLog.objects.count(), 1)
        log = ServiceUsageLog.objects.first()
        self.assertEqual(log.user_id, self.user.id)
        self.assertEqual(log.service_id, self.svc_chat.id)
        self.assertEqual(log.duration_seconds, 12)
