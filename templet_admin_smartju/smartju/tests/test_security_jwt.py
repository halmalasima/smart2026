"""
Security Tests - JWT Token Expiration and Security
"""
from django.test import TestCase
from django.contrib.auth.models import User
from rest_framework.test import APIClient
from rest_framework import status
from rest_framework_simplejwt.tokens import RefreshToken, AccessToken
from datetime import timedelta
from django.utils import timezone
from accounts.models import UserProfile
from lawsuits.models import Lawsuit
from datetime import date


class JWTSecurityTest(TestCase):
    """
    Tests for JWT token expiration and security
    """
    
    def setUp(self):
        """Set up test data"""
        self.client = APIClient()
        
        self.user = User.objects.create_user(
            username='testuser',
            email='test@example.com',
            password='testpass123'
        )
        self.user.profile.role = UserProfile.ROLE_LAWYER
        self.user.profile.save()
        
        # Create lawsuit for testing
        self.lawsuit = Lawsuit.objects.create(
            case_number='SEC-001/2024',
            gregorian_date=date(2024, 1, 15),
            hijri_date='1445/06/03',
            case_type=Lawsuit.CASE_TYPE_CIVIL,
            court='محكمة',
            subject='دعوى أمنية',
            facts='وقائع',
            reasons='أسباب',
            requests='طلبات',
            created_by=self.user
        )
    
    def test_valid_jwt_token_access(self):
        """Test that valid JWT token allows access"""
        token = str(RefreshToken.for_user(self.user).access_token)
        self.client.credentials(HTTP_AUTHORIZATION=f'Bearer {token}')
        response = self.client.get('/api/lawsuits/')
        self.assertEqual(response.status_code, status.HTTP_200_OK)
    
    def test_expired_token_rejected(self):
        """Test that expired token is rejected"""
        # Create an expired token manually
        from rest_framework_simplejwt.settings import api_settings
        from datetime import timedelta
        
        token = AccessToken.for_user(self.user)
        # Set token lifetime to negative to make it expired
        token.set_exp(lifetime=timedelta(seconds=-1))
        
        self.client.credentials(HTTP_AUTHORIZATION=f'Bearer {str(token)}')
        response = self.client.get('/api/lawsuits/')
        self.assertEqual(response.status_code, status.HTTP_401_UNAUTHORIZED)
    
    def test_invalid_token_rejected(self):
        """Test that invalid token format is rejected"""
        self.client.credentials(HTTP_AUTHORIZATION='Bearer invalid_token_string')
        response = self.client.get('/api/lawsuits/')
        self.assertEqual(response.status_code, status.HTTP_401_UNAUTHORIZED)
    
    def test_missing_token_rejected(self):
        """Test that missing token is rejected"""
        # No credentials set
        response = self.client.get('/api/lawsuits/')
        self.assertEqual(response.status_code, status.HTTP_401_UNAUTHORIZED)
    
    def test_wrong_token_format_rejected(self):
        """Test that wrong token format (not Bearer) is rejected"""
        token = str(RefreshToken.for_user(self.user).access_token)
        self.client.credentials(HTTP_AUTHORIZATION=f'Token {token}')  # Wrong prefix
        response = self.client.get('/api/lawsuits/')
        self.assertEqual(response.status_code, status.HTTP_401_UNAUTHORIZED)
    
    def test_token_refresh_works(self):
        """Test that token refresh works correctly"""
        refresh_token = RefreshToken.for_user(self.user)
        
        # Use refresh token to get new access token
        response = self.client.post('/api/token/refresh/', {
            'refresh': str(refresh_token)
        }, format='json')
        self.assertEqual(response.status_code, status.HTTP_200_OK)
        self.assertIn('access', response.data)
        
        # Use new access token
        new_access_token = response.data['access']
        self.client.credentials(HTTP_AUTHORIZATION=f'Bearer {new_access_token}')
        response = self.client.get('/api/lawsuits/')
        self.assertEqual(response.status_code, status.HTTP_200_OK)
    
    def test_token_obtain_pair_works(self):
        """Test that token obtain pair endpoint works"""
        response = self.client.post('/api/token/', {
            'username': 'testuser',
            'password': 'testpass123'
        }, format='json')
        self.assertEqual(response.status_code, status.HTTP_200_OK)
        self.assertIn('access', response.data)
        self.assertIn('refresh', response.data)
    
    def test_token_obtain_pair_wrong_credentials(self):
        """Test that wrong credentials are rejected"""
        response = self.client.post('/api/token/', {
            'username': 'testuser',
            'password': 'wrongpassword'
        }, format='json')
        self.assertEqual(response.status_code, status.HTTP_401_UNAUTHORIZED)

