"""Custom authentication backend: allow login by phone number OR username."""
from django.contrib.auth import get_user_model
from django.contrib.auth.backends import ModelBackend
from .models import UserProfile


class PhoneOrUsernameBackend(ModelBackend):
    """
    Accepts either Django username OR UserProfile.phone_number as the identifier.
    Phone numbers are normalized by stripping spaces, dashes, parentheses, and a
    leading '+' so that '+967 770 123 456' and '967770123456' match the same user.
    """

    @staticmethod
    def _norm(s):
        if not s:
            return ''
        return ''.join(ch for ch in str(s) if ch.isdigit())

    def authenticate(self, request, username=None, password=None, **kwargs):
        if not username or not password:
            return None
        User = get_user_model()
        user = None
        # 1) try by username (case-insensitive)
        user = User.objects.filter(username__iexact=username).first()
        # 2) try by email
        if user is None:
            user = User.objects.filter(email__iexact=username).first()
        # 3) try by phone (normalized digit-only match)
        if user is None:
            digits = self._norm(username)
            if digits:
                profile = UserProfile.objects.exclude(phone_number__isnull=True).exclude(phone_number='').first()
                # iterate carefully — small users base assumed; otherwise build a digits index field
                for p in UserProfile.objects.exclude(phone_number__isnull=True).exclude(phone_number=''):
                    if self._norm(p.phone_number) == digits:
                        user = p.user
                        break
        if user and user.check_password(password) and self.user_can_authenticate(user):
            return user
        return None
