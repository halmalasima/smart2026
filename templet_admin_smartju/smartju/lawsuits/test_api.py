"""
API Tests for Lawsuits app
"""
from django.test import TestCase
from django.contrib.auth.models import User
from rest_framework.test import APIClient
from rest_framework import status
from rest_framework_simplejwt.tokens import RefreshToken
from datetime import date
from .models import Lawsuit
from accounts.models import UserProfile


class LawsuitsAPITest(TestCase):
    """
    API Tests for Lawsuits endpoints
    """
    
    def setUp(self):
        """Set up test data"""
        self.client = APIClient()
        
        # Create users
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
        
        # Create lawsuit
        self.lawsuit = Lawsuit.objects.create(
            case_number='100/2024',
            gregorian_date=date(2024, 1, 15),
            hijri_date='1445/06/03',
            case_type=Lawsuit.CASE_TYPE_CIVIL,
            court='محكمة الاستئناف',
            subject='دعوى تجريبية',
            facts='وقائع الدعوى',
            reasons='الأسباب',
            requests='الطلبات',
            created_by=self.lawyer_user
        )
        
        # Get tokens
        self.judge_token = str(RefreshToken.for_user(self.judge_user).access_token)
        self.lawyer_token = str(RefreshToken.for_user(self.lawyer_user).access_token)
        self.citizen_token = str(RefreshToken.for_user(self.citizen_user).access_token)
    
    def test_create_lawsuit_unauthorized(self):
        """Test that unauthenticated users cannot create lawsuits"""
        data = {
            'case_number': '101/2024',
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
        self.assertEqual(response.status_code, status.HTTP_401_UNAUTHORIZED)
    
    def test_create_lawsuit_lawyer_allowed(self):
        """Test that lawyer can create lawsuit"""
        self.client.credentials(HTTP_AUTHORIZATION=f'Bearer {self.lawyer_token}')
        data = {
            'case_number': '102/2024',
            'gregorian_date': '2024-01-17',
            'hijri_date': '1445/06/05',
            'case_type': Lawsuit.CASE_TYPE_CIVIL,
            'court': 'محكمة الاستئناف',
            'subject': 'دعوى جديدة',
            'facts': 'وقائع الدعوى',
            'reasons': 'الأسباب والأسانيد',
            'requests': 'الطلبات'
        }
        response = self.client.post('/api/lawsuits/', data, format='json')
        self.assertEqual(response.status_code, status.HTTP_201_CREATED)
        self.assertEqual(response.data.get('case_number'), '102/2024')
    
    def test_create_lawsuit_citizen_not_allowed(self):
        """Test that citizen cannot create lawsuit"""
        self.client.credentials(HTTP_AUTHORIZATION=f'Bearer {self.citizen_token}')
        data = {
            'case_number': '103/2024',
            'gregorian_date': '2024-01-18',
            'hijri_date': '1445/06/06',
            'case_type': Lawsuit.CASE_TYPE_CIVIL,
            'court': 'محكمة',
            'subject': 'دعوى',
            'facts': 'وقائع',
            'reasons': 'أسباب',
            'requests': 'طلبات'
        }
        response = self.client.post('/api/lawsuits/', data, format='json')
        self.assertEqual(response.status_code, status.HTTP_403_FORBIDDEN)
    
    def test_get_lawsuit_list(self):
        """Test getting lawsuits list"""
        self.client.credentials(HTTP_AUTHORIZATION=f'Bearer {self.lawyer_token}')
        response = self.client.get('/api/lawsuits/')
        self.assertEqual(response.status_code, status.HTTP_200_OK)
    
    def test_get_lawsuit_detail(self):
        """Test getting lawsuit detail"""
        self.client.credentials(HTTP_AUTHORIZATION=f'Bearer {self.lawyer_token}')
        response = self.client.get(f'/api/lawsuits/{self.lawsuit.id}/')
        self.assertEqual(response.status_code, status.HTTP_200_OK)
        self.assertEqual(response.data.get('case_number'), self.lawsuit.case_number)
    
    def test_citizen_sees_only_own_lawsuits(self):
        """Test that citizen sees only their own lawsuits"""
        # Create lawsuit for citizen
        citizen_lawsuit = Lawsuit.objects.create(
            case_number='104/2024',
            gregorian_date=date(2024, 1, 19),
            hijri_date='1445/06/07',
            case_type=Lawsuit.CASE_TYPE_CIVIL,
            court='محكمة',
            subject='دعوى المواطن',
            facts='وقائع',
            reasons='أسباب',
            requests='طلبات',
            created_by=self.citizen_user
        )
        
        self.client.credentials(HTTP_AUTHORIZATION=f'Bearer {self.citizen_token}')
        response = self.client.get('/api/lawsuits/')
        self.assertEqual(response.status_code, status.HTTP_200_OK)
        # Citizen should only see their own lawsuit
        if 'data' in response.data:
            case_numbers = [ls.get('case_number') for ls in response.data['data']]
            self.assertIn(citizen_lawsuit.case_number, case_numbers)
            self.assertNotIn(self.lawsuit.case_number, case_numbers)
    
    def test_filter_lawsuits_by_status(self):
        """Test filtering lawsuits by status"""
        self.client.credentials(HTTP_AUTHORIZATION=f'Bearer {self.lawyer_token}')
        response = self.client.get(f'/api/lawsuits/?status={Lawsuit.STATUS_PENDING}')
        self.assertEqual(response.status_code, status.HTTP_200_OK)
    
    def test_search_lawsuits(self):
        """Test searching lawsuits"""
        self.client.credentials(HTTP_AUTHORIZATION=f'Bearer {self.lawyer_token}')
        response = self.client.get(f'/api/lawsuits/?search={self.lawsuit.case_number}')
        self.assertEqual(response.status_code, status.HTTP_200_OK)
    
    def test_update_lawsuit_lawyer_allowed(self):
        """Test that lawyer can update lawsuit"""
        self.client.credentials(HTTP_AUTHORIZATION=f'Bearer {self.lawyer_token}')
        data = {
            'case_number': self.lawsuit.case_number,
            'gregorian_date': str(self.lawsuit.gregorian_date),
            'hijri_date': self.lawsuit.hijri_date,
            'case_type': self.lawsuit.case_type,
            'court': 'محكمة محدثة',
            'subject': self.lawsuit.subject,
            'facts': self.lawsuit.facts,
            'reasons': self.lawsuit.reasons,
            'requests': self.lawsuit.requests,
            'status': Lawsuit.STATUS_IN_PROGRESS
        }
        response = self.client.put(f'/api/lawsuits/{self.lawsuit.id}/', data, format='json')
        self.assertEqual(response.status_code, status.HTTP_200_OK)
        self.assertEqual(response.data.get('status'), Lawsuit.STATUS_IN_PROGRESS)
    
    def test_delete_lawsuit_lawyer_allowed(self):
        """Test that lawyer can delete lawsuit"""
        lawsuit = Lawsuit.objects.create(
            case_number='105/2024',
            gregorian_date=date(2024, 1, 20),
            hijri_date='1445/06/08',
            case_type=Lawsuit.CASE_TYPE_CIVIL,
            court='محكمة',
            subject='دعوى للحذف',
            facts='وقائع',
            reasons='أسباب',
            requests='طلبات',
            created_by=self.lawyer_user
        )
        
        self.client.credentials(HTTP_AUTHORIZATION=f'Bearer {self.lawyer_token}')
        response = self.client.delete(f'/api/lawsuits/{lawsuit.id}/')
        self.assertEqual(response.status_code, status.HTTP_204_NO_CONTENT)
        self.assertFalse(Lawsuit.objects.filter(id=lawsuit.id).exists())

