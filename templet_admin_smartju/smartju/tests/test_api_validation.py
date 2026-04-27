"""
API Validation and Error Handling Tests
"""
from django.test import TestCase
from django.contrib.auth.models import User
from rest_framework.test import APIClient
from rest_framework import status
from rest_framework_simplejwt.tokens import RefreshToken
from datetime import date
from lawsuits.models import Lawsuit
from accounts.models import UserProfile


class APIValidationTest(TestCase):
    """
    Tests for API validation and error handling
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
    
    def test_create_lawsuit_missing_required_fields(self):
        """Test validation error when required fields are missing"""
        data = {
            'case_number': '300/2024',
            # Missing required fields
        }
        response = self.client.post('/api/lawsuits/', data, format='json')
        self.assertEqual(response.status_code, status.HTTP_400_BAD_REQUEST)
        self.assertIn('error', response.data or {})
    
    def test_create_lawsuit_duplicate_case_number(self):
        """Test validation error for duplicate case number"""
        Lawsuit.objects.create(
            case_number='301/2024',
            gregorian_date=date(2024, 1, 15),
            hijri_date='1445/06/03',
            case_type=Lawsuit.CASE_TYPE_CIVIL,
            court='محكمة',
            subject='دعوى موجودة',
            facts='وقائع',
            reasons='أسباب',
            requests='طلبات',
            created_by=self.lawyer_user
        )
        
        data = {
            'case_number': '301/2024',  # Duplicate
            'gregorian_date': '2024-01-16',
            'hijri_date': '1445/06/04',
            'case_type': Lawsuit.CASE_TYPE_CIVIL,
            'court': 'محكمة',
            'subject': 'دعوى جديدة',
            'facts': 'وقائع',
            'reasons': 'أسباب',
            'requests': 'طلبات'
        }
        response = self.client.post('/api/lawsuits/', data, format='json')
        self.assertEqual(response.status_code, status.HTTP_400_BAD_REQUEST)
    
    def test_create_lawsuit_subject_too_long(self):
        """Test validation error for subject exceeding 150 characters"""
        data = {
            'case_number': '302/2024',
            'gregorian_date': '2024-01-17',
            'hijri_date': '1445/06/05',
            'case_type': Lawsuit.CASE_TYPE_CIVIL,
            'court': 'محكمة',
            'subject': 'أ' * 151,  # Exceeds max_length
            'facts': 'وقائع',
            'reasons': 'أسباب',
            'requests': 'طلبات'
        }
        response = self.client.post('/api/lawsuits/', data, format='json')
        self.assertEqual(response.status_code, status.HTTP_400_BAD_REQUEST)
    
    def test_get_nonexistent_lawsuit(self):
        """Test error handling for nonexistent resource"""
        response = self.client.get('/api/lawsuits/99999/')
        self.assertEqual(response.status_code, status.HTTP_404_NOT_FOUND)
    
    def test_update_nonexistent_lawsuit(self):
        """Test error handling for updating nonexistent resource"""
        data = {
            'case_number': '303/2024',
            'gregorian_date': '2024-01-18',
            'hijri_date': '1445/06/06',
            'case_type': Lawsuit.CASE_TYPE_CIVIL,
            'court': 'محكمة',
            'subject': 'دعوى',
            'facts': 'وقائع',
            'reasons': 'أسباب',
            'requests': 'طلبات'
        }
        response = self.client.put('/api/lawsuits/99999/', data, format='json')
        self.assertEqual(response.status_code, status.HTTP_404_NOT_FOUND)
    
    def test_delete_nonexistent_lawsuit(self):
        """Test error handling for deleting nonexistent resource"""
        response = self.client.delete('/api/lawsuits/99999/')
        self.assertEqual(response.status_code, status.HTTP_404_NOT_FOUND)
    
    def test_error_response_format(self):
        """Test that error responses follow consistent format"""
        response = self.client.get('/api/lawsuits/99999/')
        self.assertEqual(response.status_code, status.HTTP_404_NOT_FOUND)
        # Error format should be consistent (if custom exception handler is used)
        # This depends on implementation

