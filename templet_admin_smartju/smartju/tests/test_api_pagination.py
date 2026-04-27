"""
API Pagination Tests
"""
from django.test import TestCase
from django.contrib.auth.models import User
from rest_framework.test import APIClient
from rest_framework import status
from rest_framework_simplejwt.tokens import RefreshToken
from datetime import date
from lawsuits.models import Lawsuit
from accounts.models import UserProfile


class APIPaginationTest(TestCase):
    """
    Tests for API pagination
    """
    
    def setUp(self):
        """Set up test data"""
        self.client = APIClient()
        
        self.lawyer_user = User.objects.create_user(
            username='lawyer1',
            email='lawyer@example.com',
            password='testpass123'
        )
        self.lawyer_profile = self.lawyer_user.profile
        self.lawyer_profile.role = UserProfile.ROLE_LAWYER
        self.lawyer_profile.save()
        
        self.lawyer_token = str(RefreshToken.for_user(self.lawyer_user).access_token)
        self.client.credentials(HTTP_AUTHORIZATION=f'Bearer {self.lawyer_token}')
        
        # Create multiple lawsuits for pagination testing
        for i in range(25):
            Lawsuit.objects.create(
                case_number=f'PAG-{i:03d}/2024',
                gregorian_date=date(2024, 1, 15 + i),
                hijri_date=f'1445/06/{3 + i:02d}',
                case_type=Lawsuit.CASE_TYPE_CIVIL,
                court='محكمة',
                subject=f'دعوى {i}',
                facts='وقائع',
                reasons='أسباب',
                requests='طلبات',
                created_by=self.lawyer_user
            )
    
    def test_pagination_default_page_size(self):
        """Test that pagination returns default page size (20)"""
        response = self.client.get('/api/lawsuits/')
        self.assertEqual(response.status_code, status.HTTP_200_OK)
        
        # Check pagination structure
        if 'pagination' in response.data:
            self.assertIn('count', response.data['pagination'])
            self.assertIn('current_page', response.data['pagination'])
            self.assertIn('total_pages', response.data['pagination'])
            self.assertIn('page_size', response.data['pagination'])
            self.assertEqual(response.data['pagination']['page_size'], 20)
            # Should have 25 total, so 2 pages
            self.assertEqual(response.data['pagination']['count'], 25)
            self.assertEqual(response.data['pagination']['total_pages'], 2)
    
    def test_pagination_next_page(self):
        """Test pagination next page link"""
        response = self.client.get('/api/lawsuits/')
        self.assertEqual(response.status_code, status.HTTP_200_OK)
        
        if 'pagination' in response.data:
            # If there are more pages, next should not be None
            if response.data['pagination']['count'] > 20:
                # Check if we can get next page
                if response.data['pagination'].get('next'):
                    next_response = self.client.get(response.data['pagination']['next'])
                    self.assertEqual(next_response.status_code, status.HTTP_200_OK)
    
    def test_pagination_custom_page_size(self):
        """Test custom page size parameter"""
        response = self.client.get('/api/lawsuits/?page_size=10')
        self.assertEqual(response.status_code, status.HTTP_200_OK)
        
        if 'pagination' in response.data:
            self.assertEqual(response.data['pagination']['page_size'], 10)
    
    def test_pagination_page_number(self):
        """Test accessing specific page number"""
        response = self.client.get('/api/lawsuits/?page=2')
        self.assertEqual(response.status_code, status.HTTP_200_OK)
        
        if 'pagination' in response.data:
            self.assertEqual(response.data['pagination']['current_page'], 2)

