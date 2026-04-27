"""
Security Tests - Role Permissions and Authorization
"""
from django.test import TestCase
from django.contrib.auth.models import User
from rest_framework.test import APIClient
from rest_framework import status
from rest_framework_simplejwt.tokens import RefreshToken
from datetime import date
from lawsuits.models import Lawsuit
from parties.models import Plaintiff, Defendant
from judgments.models import Judgment
from hearings.models import Hearing
from accounts.models import UserProfile


class RolePermissionsSecurityTest(TestCase):
    """
    Tests for role-based permissions and authorization
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
        
        self.admin_user = User.objects.create_user(
            username='admin1',
            email='admin@example.com',
            password='testpass123',
            is_staff=True,
            is_superuser=True
        )
        self.admin_profile = self.admin_user.profile
        self.admin_profile.role = UserProfile.ROLE_ADMIN
        self.admin_profile.save()
        
        # Create lawsuit
        self.lawsuit = Lawsuit.objects.create(
            case_number='PERM-001/2024',
            gregorian_date=date(2024, 1, 15),
            hijri_date='1445/06/03',
            case_type=Lawsuit.CASE_TYPE_CIVIL,
            court='محكمة الاستئناف',
            subject='دعوى صلاحيات',
            facts='وقائع',
            reasons='أسباب',
            requests='طلبات',
            created_by=self.lawyer_user
        )
        
        # Get tokens
        self.judge_token = str(RefreshToken.for_user(self.judge_user).access_token)
        self.lawyer_token = str(RefreshToken.for_user(self.lawyer_user).access_token)
        self.citizen_token = str(RefreshToken.for_user(self.citizen_user).access_token)
        self.admin_token = str(RefreshToken.for_user(self.admin_user).access_token)
    
    # Judge Permissions Tests
    def test_judge_can_create_judgment(self):
        """Test that judge can create judgment"""
        self.client.credentials(HTTP_AUTHORIZATION=f'Bearer {self.judge_token}')
        data = {
            'lawsuit_id': self.lawsuit.id,
            'judgment_type': Judgment.JUDGMENT_TYPE_PRIMARY,
            'judgment_number': 'J-PERM-001/2024',
            'judgment_date': '2024-04-01',
            'hijri_date': '1445/09/21',
            'judgment_text': 'نص الحكم',
            'judge_name': 'القاضي محمد',
            'court_name': 'محكمة الاستئناف',
            'status': Judgment.STATUS_PENDING
        }
        response = self.client.post('/api/judgments/', data, format='json')
        self.assertEqual(response.status_code, status.HTTP_201_CREATED)
    
    def test_lawyer_cannot_create_judgment(self):
        """Test that lawyer cannot create judgment"""
        self.client.credentials(HTTP_AUTHORIZATION=f'Bearer {self.lawyer_token}')
        data = {
            'lawsuit_id': self.lawsuit.id,
            'judgment_type': Judgment.JUDGMENT_TYPE_PRIMARY,
            'judgment_number': 'J-PERM-002/2024',
            'judgment_date': '2024-04-01',
            'hijri_date': '1445/09/21',
            'judgment_text': 'نص الحكم',
            'judge_name': 'القاضي محمد',
            'court_name': 'محكمة الاستئناف',
            'status': Judgment.STATUS_PENDING
        }
        response = self.client.post('/api/judgments/', data, format='json')
        self.assertEqual(response.status_code, status.HTTP_403_FORBIDDEN)
    
    def test_citizen_cannot_create_judgment(self):
        """Test that citizen cannot create judgment"""
        self.client.credentials(HTTP_AUTHORIZATION=f'Bearer {self.citizen_token}')
        data = {
            'lawsuit_id': self.lawsuit.id,
            'judgment_type': Judgment.JUDGMENT_TYPE_PRIMARY,
            'judgment_number': 'J-PERM-003/2024',
            'judgment_date': '2024-04-01',
            'hijri_date': '1445/09/21',
            'judgment_text': 'نص الحكم',
            'judge_name': 'القاضي محمد',
            'court_name': 'محكمة الاستئناف',
            'status': Judgment.STATUS_PENDING
        }
        response = self.client.post('/api/judgments/', data, format='json')
        self.assertEqual(response.status_code, status.HTTP_403_FORBIDDEN)
    
    # Lawyer Permissions Tests
    def test_lawyer_can_create_lawsuit(self):
        """Test that lawyer can create lawsuit"""
        self.client.credentials(HTTP_AUTHORIZATION=f'Bearer {self.lawyer_token}')
        data = {
            'case_number': 'PERM-002/2024',
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
        self.assertEqual(response.status_code, status.HTTP_201_CREATED)
    
    def test_citizen_cannot_create_lawsuit(self):
        """Test that citizen cannot create lawsuit"""
        self.client.credentials(HTTP_AUTHORIZATION=f'Bearer {self.citizen_token}')
        data = {
            'case_number': 'PERM-003/2024',
            'gregorian_date': '2024-01-17',
            'hijri_date': '1445/06/05',
            'case_type': Lawsuit.CASE_TYPE_CIVIL,
            'court': 'محكمة',
            'subject': 'دعوى',
            'facts': 'وقائع',
            'reasons': 'أسباب',
            'requests': 'طلبات'
        }
        response = self.client.post('/api/lawsuits/', data, format='json')
        self.assertEqual(response.status_code, status.HTTP_403_FORBIDDEN)
    
    def test_lawyer_can_create_party(self):
        """Test that lawyer can create party"""
        self.client.credentials(HTTP_AUTHORIZATION=f'Bearer {self.lawyer_token}')
        data = {
            'lawsuit_id': self.lawsuit.id,
            'name': 'أحمد محمد',
            'gender': Plaintiff.GENDER_MALE,
            'nationality': 'يمني',
            'address': 'صنعاء'
        }
        response = self.client.post('/api/plaintiffs/', data, format='json')
        self.assertEqual(response.status_code, status.HTTP_201_CREATED)
    
    def test_citizen_cannot_create_party(self):
        """Test that citizen cannot create party"""
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
    
    # Citizen Permissions Tests
    def test_citizen_can_only_see_own_lawsuits(self):
        """Test that citizen can only see their own lawsuits"""
        # Create lawsuit for citizen
        citizen_lawsuit = Lawsuit.objects.create(
            case_number='PERM-CIT-001/2024',
            gregorian_date=date(2024, 1, 18),
            hijri_date='1445/06/06',
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
    
    def test_citizen_cannot_access_other_lawsuit_detail(self):
        """Test that citizen cannot access other user's lawsuit detail"""
        self.client.credentials(HTTP_AUTHORIZATION=f'Bearer {self.citizen_token}')
        response = self.client.get(f'/api/lawsuits/{self.lawsuit.id}/')
        self.assertEqual(response.status_code, status.HTTP_404_NOT_FOUND)
    
    # Admin Permissions Tests
    def test_admin_can_access_all_endpoints(self):
        """Test that admin can access all endpoints"""
        self.client.credentials(HTTP_AUTHORIZATION=f'Bearer {self.admin_token}')
        
        # Test access to lawsuits
        response = self.client.get('/api/lawsuits/')
        self.assertEqual(response.status_code, status.HTTP_200_OK)
        
        # Test access to judgments
        response = self.client.get('/api/judgments/')
        self.assertEqual(response.status_code, status.HTTP_200_OK)
        
        # Test access to profiles
        response = self.client.get('/api/profiles/')
        self.assertEqual(response.status_code, status.HTTP_200_OK)
    
    def test_admin_can_create_lawsuit(self):
        """Test that admin can create lawsuit"""
        self.client.credentials(HTTP_AUTHORIZATION=f'Bearer {self.admin_token}')
        data = {
            'case_number': 'PERM-ADMIN-001/2024',
            'gregorian_date': '2024-01-19',
            'hijri_date': '1445/06/07',
            'case_type': Lawsuit.CASE_TYPE_CIVIL,
            'court': 'محكمة',
            'subject': 'دعوى المدير',
            'facts': 'وقائع',
            'reasons': 'أسباب',
            'requests': 'طلبات'
        }
        response = self.client.post('/api/lawsuits/', data, format='json')
        self.assertEqual(response.status_code, status.HTTP_201_CREATED)
    
    def test_admin_can_create_judgment(self):
        """Test that admin can create judgment"""
        self.client.credentials(HTTP_AUTHORIZATION=f'Bearer {self.admin_token}')
        data = {
            'lawsuit_id': self.lawsuit.id,
            'judgment_type': Judgment.JUDGMENT_TYPE_PRIMARY,
            'judgment_number': 'J-ADMIN-001/2024',
            'judgment_date': '2024-04-01',
            'hijri_date': '1445/09/21',
            'judgment_text': 'نص الحكم',
            'judge_name': 'القاضي المدير',
            'court_name': 'محكمة الاستئناف',
            'status': Judgment.STATUS_PENDING
        }
        response = self.client.post('/api/judgments/', data, format='json')
        self.assertEqual(response.status_code, status.HTTP_201_CREATED)

