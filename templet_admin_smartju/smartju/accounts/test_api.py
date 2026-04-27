"""
API Tests for Accounts app
"""
from django.test import TestCase
from django.contrib.auth.models import User
from rest_framework.test import APIClient
from rest_framework import status
from rest_framework_simplejwt.tokens import RefreshToken
from .models import UserProfile


class AccountsAPITest(TestCase):
    """
    API Tests for Accounts endpoints
    """
    
    def setUp(self):
        """Set up test data"""
        self.client = APIClient()
        
        # Create users with different roles
        self.judge_user = User.objects.create_user(
            username='judge1',
            email='judge@example.com',
            password='testpass123'
        )
        self.judge_profile = self.judge_user.profile
        self.judge_profile.role = UserProfile.ROLE_JUDGE
        self.judge_profile.save()
        
        self.lawyer_user = User.objects.create_user(
            username='lawyer1',
            email='lawyer@example.com',
            password='testpass123'
        )
        self.lawyer_profile = self.lawyer_user.profile
        self.lawyer_profile.role = UserProfile.ROLE_LAWYER
        self.lawyer_profile.save()
        
        self.citizen_user = User.objects.create_user(
            username='citizen1',
            email='citizen@example.com',
            password='testpass123'
        )
        self.citizen_profile = self.citizen_user.profile
        self.citizen_profile.role = UserProfile.ROLE_CITIZEN
        self.citizen_profile.save()
        
        # Get JWT tokens
        self.judge_token = str(RefreshToken.for_user(self.judge_user).access_token)
        self.lawyer_token = str(RefreshToken.for_user(self.lawyer_user).access_token)
        self.citizen_token = str(RefreshToken.for_user(self.citizen_user).access_token)
    
    def test_get_profile_list_unauthorized(self):
        """Test that unauthenticated users cannot access profiles"""
        response = self.client.get('/api/profiles/')
        self.assertEqual(response.status_code, status.HTTP_401_UNAUTHORIZED)
    
    def test_get_profile_list_authorized(self):
        """Test that authenticated users can access profiles"""
        self.client.credentials(HTTP_AUTHORIZATION=f'Bearer {self.judge_token}')
        response = self.client.get('/api/profiles/')
        self.assertEqual(response.status_code, status.HTTP_200_OK)
        self.assertIn('data', response.data or {})
    
    def test_get_my_profile(self):
        """Test getting current user's profile"""
        self.client.credentials(HTTP_AUTHORIZATION=f'Bearer {self.judge_token}')
        response = self.client.get('/api/profiles/me/')
        self.assertEqual(response.status_code, status.HTTP_200_OK)
        self.assertEqual(response.data.get('role'), UserProfile.ROLE_JUDGE)
    
    def test_create_profile_judge_allowed(self):
        """Test that judge can create profile"""
        new_user = User.objects.create_user(
            username='newuser',
            email='new@example.com',
            password='testpass123'
        )
        
        self.client.credentials(HTTP_AUTHORIZATION=f'Bearer {self.judge_token}')
        data = {
            'role': UserProfile.ROLE_LAWYER,
            'phone_number': '777123456',
            'national_id': '123456789',
            'is_active': True
        }
        # Note: Profile is created via signal, so we update it
        response = self.client.patch(
            f'/api/profiles/{new_user.profile.id}/',
            data=data,
            format='json'
        )
        self.assertEqual(response.status_code, status.HTTP_200_OK)
    
    def test_create_profile_citizen_not_allowed(self):
        """Test that citizen cannot create profile"""
        new_user = User.objects.create_user(
            username='newuser2',
            email='new2@example.com',
            password='testpass123'
        )
        
        self.client.credentials(HTTP_AUTHORIZATION=f'Bearer {self.citizen_token}')
        data = {
            'role': UserProfile.ROLE_LAWYER,
        }
        response = self.client.patch(
            f'/api/profiles/{new_user.profile.id}/',
            data=data,
            format='json'
        )
        self.assertEqual(response.status_code, status.HTTP_403_FORBIDDEN)
    
    def test_profile_filter_by_role(self):
        """Test filtering profiles by role"""
        self.client.credentials(HTTP_AUTHORIZATION=f'Bearer {self.judge_token}')
        response = self.client.get('/api/profiles/?role=judge')
        self.assertEqual(response.status_code, status.HTTP_200_OK)
        # All results should be judges
        if 'data' in response.data:
            for profile in response.data['data']:
                self.assertEqual(profile['role'], UserProfile.ROLE_JUDGE)

