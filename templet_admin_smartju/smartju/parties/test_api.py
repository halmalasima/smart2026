"""
API Tests for Parties app
"""
from django.test import TestCase
from django.contrib.auth.models import User
from rest_framework.test import APIClient
from rest_framework import status
from rest_framework_simplejwt.tokens import RefreshToken
from datetime import date
from lawsuits.models import Lawsuit
from accounts.models import UserProfile
from .models import Plaintiff, Defendant


class PartiesAPITest(TestCase):
    """
    API Tests for Parties endpoints
    """
    
    def setUp(self):
        """Set up test data"""
        self.client = APIClient()
        
        # Create users
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
        
        # Create lawsuit
        self.lawsuit = Lawsuit.objects.create(
            case_number='200/2024',
            gregorian_date=date(2024, 1, 15),
            hijri_date='1445/06/03',
            case_type=Lawsuit.CASE_TYPE_CIVIL,
            court='محكمة',
            subject='دعوى',
            facts='وقائع',
            reasons='أسباب',
            requests='طلبات',
            created_by=self.lawyer_user
        )
        
        # Get tokens
        self.lawyer_token = str(RefreshToken.for_user(self.lawyer_user).access_token)
        self.citizen_token = str(RefreshToken.for_user(self.citizen_user).access_token)
    
    def test_create_plaintiff_lawyer_allowed(self):
        """Test that lawyer can create plaintiff"""
        self.client.credentials(HTTP_AUTHORIZATION=f'Bearer {self.lawyer_token}')
        data = {
            'lawsuit_id': self.lawsuit.id,
            'name': 'أحمد محمد علي',
            'gender': Plaintiff.GENDER_MALE,
            'nationality': 'يمني',
            'occupation': 'مهندس',
            'address': 'صنعاء',
            'phone': '777123456'
        }
        response = self.client.post('/api/plaintiffs/', data, format='json')
        self.assertEqual(response.status_code, status.HTTP_201_CREATED)
        self.assertEqual(response.data.get('name'), 'أحمد محمد علي')
    
    def test_create_plaintiff_citizen_not_allowed(self):
        """Test that citizen cannot create plaintiff"""
        self.client.credentials(HTTP_AUTHORIZATION=f'Bearer {self.citizen_token}')
        data = {
            'lawsuit_id': self.lawsuit.id,
            'name': 'أحمد محمد',
            'gender': Plaintiff.GENDER_MALE,
            'nationality': 'يمني',
            'address': 'صنعاء'
        }
        response = self.client.post('/api/plaintiffs/', data, format='json')
        self.assertEqual(response.status_code, status.HTTP_403_FORBIDDEN)
    
    def test_create_defendant_lawyer_allowed(self):
        """Test that lawyer can create defendant"""
        self.client.credentials(HTTP_AUTHORIZATION=f'Bearer {self.lawyer_token}')
        data = {
            'lawsuit_id': self.lawsuit.id,
            'name': 'خالد سعيد حسن',
            'gender': Defendant.GENDER_MALE,
            'nationality': 'يمني',
            'occupation': 'تاجر',
            'address': 'عدن',
            'phone': '777987654'
        }
        response = self.client.post('/api/defendants/', data, format='json')
        self.assertEqual(response.status_code, status.HTTP_201_CREATED)
        self.assertEqual(response.data.get('name'), 'خالد سعيد حسن')
    
    def test_get_plaintiffs_list(self):
        """Test getting plaintiffs list"""
        Plaintiff.objects.create(
            lawsuit=self.lawsuit,
            name='أحمد محمد',
            gender=Plaintiff.GENDER_MALE,
            nationality='يمني',
            address='صنعاء'
        )
        
        self.client.credentials(HTTP_AUTHORIZATION=f'Bearer {self.lawyer_token}')
        response = self.client.get('/api/plaintiffs/')
        self.assertEqual(response.status_code, status.HTTP_200_OK)
    
    def test_filter_plaintiffs_by_lawsuit(self):
        """Test filtering plaintiffs by lawsuit"""
        plaintiff = Plaintiff.objects.create(
            lawsuit=self.lawsuit,
            name='أحمد محمد',
            gender=Plaintiff.GENDER_MALE,
            nationality='يمني',
            address='صنعاء'
        )
        
        self.client.credentials(HTTP_AUTHORIZATION=f'Bearer {self.lawyer_token}')
        response = self.client.get(f'/api/plaintiffs/?lawsuit={self.lawsuit.id}')
        self.assertEqual(response.status_code, status.HTTP_200_OK)

