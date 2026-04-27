"""
Security Tests - Data Isolation (Citizens/Judges/Admins)
"""
from django.test import TestCase
from django.contrib.auth.models import User
from rest_framework.test import APIClient
from rest_framework import status
from rest_framework_simplejwt.tokens import RefreshToken
from datetime import date
from lawsuits.models import Lawsuit
from judgments.models import Judgment
from accounts.models import UserProfile


class DataIsolationSecurityTest(TestCase):
    """
    Tests for data isolation between different user roles
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
        
        self.citizen_user1 = User.objects.create_user(
            username='citizen1',
            email='citizen1@example.com',
            password='testpass123'
        )
        self.citizen_profile1 = self.citizen_user1.profile
        self.citizen_profile1.role = UserProfile.ROLE_CITIZEN
        self.citizen_profile1.save()
        
        self.citizen_user2 = User.objects.create_user(
            username='citizen2',
            email='citizen2@example.com',
            password='testpass123'
        )
        self.citizen_profile2 = self.citizen_user2.profile
        self.citizen_profile2.role = UserProfile.ROLE_CITIZEN
        self.citizen_profile2.save()
        
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
        
        # Create lawsuits for different users
        self.lawsuit_lawyer = Lawsuit.objects.create(
            case_number='ISO-LAW-001/2024',
            gregorian_date=date(2024, 1, 15),
            hijri_date='1445/06/03',
            case_type=Lawsuit.CASE_TYPE_CIVIL,
            court='محكمة الاستئناف',
            subject='دعوى المحامي',
            facts='وقائع',
            reasons='أسباب',
            requests='طلبات',
            created_by=self.lawyer_user
        )
        
        self.lawsuit_citizen1 = Lawsuit.objects.create(
            case_number='ISO-CIT1-001/2024',
            gregorian_date=date(2024, 1, 16),
            hijri_date='1445/06/04',
            case_type=Lawsuit.CASE_TYPE_CIVIL,
            court='محكمة',
            subject='دعوى المواطن 1',
            facts='وقائع',
            reasons='أسباب',
            requests='طلبات',
            created_by=self.citizen_user1
        )
        
        self.lawsuit_citizen2 = Lawsuit.objects.create(
            case_number='ISO-CIT2-001/2024',
            gregorian_date=date(2024, 1, 17),
            hijri_date='1445/06/05',
            case_type=Lawsuit.CASE_TYPE_CIVIL,
            court='محكمة',
            subject='دعوى المواطن 2',
            facts='وقائع',
            reasons='أسباب',
            requests='طلبات',
            created_by=self.citizen_user2
        )
        
        # Get tokens
        self.judge_token = str(RefreshToken.for_user(self.judge_user).access_token)
        self.lawyer_token = str(RefreshToken.for_user(self.lawyer_user).access_token)
        self.citizen_token1 = str(RefreshToken.for_user(self.citizen_user1).access_token)
        self.citizen_token2 = str(RefreshToken.for_user(self.citizen_user2).access_token)
        self.admin_token = str(RefreshToken.for_user(self.admin_user).access_token)
    
    def test_citizen_cannot_see_other_citizen_lawsuits(self):
        """Test that citizen1 cannot see citizen2's lawsuits"""
        self.client.credentials(HTTP_AUTHORIZATION=f'Bearer {self.citizen_token1}')
        response = self.client.get('/api/lawsuits/')
        self.assertEqual(response.status_code, status.HTTP_200_OK)
        
        if 'data' in response.data:
            case_numbers = [ls.get('case_number') for ls in response.data['data']]
            # Citizen1 should see their own lawsuit
            self.assertIn(self.lawsuit_citizen1.case_number, case_numbers)
            # Citizen1 should NOT see citizen2's lawsuit
            self.assertNotIn(self.lawsuit_citizen2.case_number, case_numbers)
            # Citizen1 should NOT see lawyer's lawsuit
            self.assertNotIn(self.lawsuit_lawyer.case_number, case_numbers)
    
    def test_citizen_cannot_access_other_citizen_lawsuit_detail(self):
        """Test that citizen1 cannot access citizen2's lawsuit detail"""
        self.client.credentials(HTTP_AUTHORIZATION=f'Bearer {self.citizen_token1}')
        response = self.client.get(f'/api/lawsuits/{self.lawsuit_citizen2.id}/')
        # Should return 404 (not found) because of queryset filtering
        self.assertEqual(response.status_code, status.HTTP_404_NOT_FOUND)
    
    def test_citizen_can_access_own_lawsuit_detail(self):
        """Test that citizen1 can access their own lawsuit detail"""
        self.client.credentials(HTTP_AUTHORIZATION=f'Bearer {self.citizen_token1}')
        response = self.client.get(f'/api/lawsuits/{self.lawsuit_citizen1.id}/')
        self.assertEqual(response.status_code, status.HTTP_200_OK)
        self.assertEqual(response.data.get('case_number'), self.lawsuit_citizen1.case_number)
    
    def test_lawyer_can_see_all_lawsuits(self):
        """Test that lawyer can see all lawsuits (no isolation)"""
        self.client.credentials(HTTP_AUTHORIZATION=f'Bearer {self.lawyer_token}')
        response = self.client.get('/api/lawsuits/')
        self.assertEqual(response.status_code, status.HTTP_200_OK)
        
        if 'data' in response.data:
            case_numbers = [ls.get('case_number') for ls in response.data['data']]
            # Lawyer should see all lawsuits
            self.assertIn(self.lawsuit_lawyer.case_number, case_numbers)
            self.assertIn(self.lawsuit_citizen1.case_number, case_numbers)
            self.assertIn(self.lawsuit_citizen2.case_number, case_numbers)
    
    def test_judge_can_see_all_lawsuits(self):
        """Test that judge can see all lawsuits"""
        self.client.credentials(HTTP_AUTHORIZATION=f'Bearer {self.judge_token}')
        response = self.client.get('/api/lawsuits/')
        self.assertEqual(response.status_code, status.HTTP_200_OK)
        
        if 'data' in response.data:
            case_numbers = [ls.get('case_number') for ls in response.data['data']]
            # Judge should see all lawsuits
            self.assertIn(self.lawsuit_lawyer.case_number, case_numbers)
            self.assertIn(self.lawsuit_citizen1.case_number, case_numbers)
            self.assertIn(self.lawsuit_citizen2.case_number, case_numbers)
    
    def test_admin_can_see_all_lawsuits(self):
        """Test that admin can see all lawsuits"""
        self.client.credentials(HTTP_AUTHORIZATION=f'Bearer {self.admin_token}')
        response = self.client.get('/api/lawsuits/')
        self.assertEqual(response.status_code, status.HTTP_200_OK)
        
        if 'data' in response.data:
            case_numbers = [ls.get('case_number') for ls in response.data['data']]
            # Admin should see all lawsuits
            self.assertIn(self.lawsuit_lawyer.case_number, case_numbers)
            self.assertIn(self.lawsuit_citizen1.case_number, case_numbers)
            self.assertIn(self.lawsuit_citizen2.case_number, case_numbers)
    
    def test_citizen_cannot_update_other_lawsuit(self):
        """Test that citizen cannot update another citizen's lawsuit"""
        self.client.credentials(HTTP_AUTHORIZATION=f'Bearer {self.citizen_token1}')
        data = {
            'case_number': self.lawsuit_citizen2.case_number,
            'gregorian_date': str(self.lawsuit_citizen2.gregorian_date),
            'hijri_date': self.lawsuit_citizen2.hijri_date,
            'case_type': self.lawsuit_citizen2.case_type,
            'court': 'محكمة محدثة',
            'subject': self.lawsuit_citizen2.subject,
            'facts': self.lawsuit_citizen2.facts,
            'reasons': self.lawsuit_citizen2.reasons,
            'requests': self.lawsuit_citizen2.requests,
        }
        # Should return 404 because the lawsuit is not in their queryset
        response = self.client.put(f'/api/lawsuits/{self.lawsuit_citizen2.id}/', data, format='json')
        self.assertEqual(response.status_code, status.HTTP_404_NOT_FOUND)
    
    def test_citizen_cannot_delete_other_lawsuit(self):
        """Test that citizen cannot delete another citizen's lawsuit"""
        self.client.credentials(HTTP_AUTHORIZATION=f'Bearer {self.citizen_token1}')
        # Should return 404 because the lawsuit is not in their queryset
        response = self.client.delete(f'/api/lawsuits/{self.lawsuit_citizen2.id}/')
        self.assertEqual(response.status_code, status.HTTP_404_NOT_FOUND)
    
    def test_admin_has_full_access(self):
        """Test that admin has full administrative access"""
        self.client.credentials(HTTP_AUTHORIZATION=f'Bearer {self.admin_token}')
        
        # Admin should be able to access any lawsuit
        response = self.client.get(f'/api/lawsuits/{self.lawsuit_citizen1.id}/')
        self.assertEqual(response.status_code, status.HTTP_200_OK)
        
        response = self.client.get(f'/api/lawsuits/{self.lawsuit_citizen2.id}/')
        self.assertEqual(response.status_code, status.HTTP_200_OK)
        
        response = self.client.get(f'/api/lawsuits/{self.lawsuit_lawyer.id}/')
        self.assertEqual(response.status_code, status.HTTP_200_OK)

