"""
Integration API Tests - Complete workflows
"""
from django.test import TestCase
from django.contrib.auth.models import User
from rest_framework.test import APIClient
from rest_framework import status
from rest_framework_simplejwt.tokens import RefreshToken
from datetime import date
from lawsuits.models import Lawsuit
from parties.models import Plaintiff, Defendant
from responses.models import Response
from appeals.models import Appeal
from judgments.models import Judgment
from accounts.models import UserProfile


class IntegrationAPITest(TestCase):
    """
    Integration tests for complete workflows
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
        
        # Get tokens
        self.judge_token = str(RefreshToken.for_user(self.judge_user).access_token)
        self.lawyer_token = str(RefreshToken.for_user(self.lawyer_user).access_token)
    
    def test_complete_lawsuit_workflow(self):
        """Test complete workflow: Create lawsuit -> Add parties -> Add response -> Create appeal -> Issue judgment"""
        self.client.credentials(HTTP_AUTHORIZATION=f'Bearer {self.lawyer_token}')
        
        # 1. Create lawsuit
        lawsuit_data = {
            'case_number': 'INT-001/2024',
            'gregorian_date': '2024-01-15',
            'hijri_date': '1445/06/03',
            'case_type': Lawsuit.CASE_TYPE_CIVIL,
            'court': 'محكمة الاستئناف',
            'subject': 'دعوى تكاملية',
            'facts': 'وقائع الدعوى',
            'reasons': 'الأسباب',
            'requests': 'الطلبات'
        }
        lawsuit_response = self.client.post('/api/lawsuits/', lawsuit_data, format='json')
        self.assertEqual(lawsuit_response.status_code, status.HTTP_201_CREATED)
        lawsuit_id = lawsuit_response.data.get('id')
        
        # 2. Add plaintiff
        plaintiff_data = {
            'lawsuit_id': lawsuit_id,
            'name': 'أحمد محمد علي',
            'gender': Plaintiff.GENDER_MALE,
            'nationality': 'يمني',
            'address': 'صنعاء',
            'phone': '777123456'
        }
        plaintiff_response = self.client.post('/api/plaintiffs/', plaintiff_data, format='json')
        self.assertEqual(plaintiff_response.status_code, status.HTTP_201_CREATED)
        
        # 3. Add defendant
        defendant_data = {
            'lawsuit_id': lawsuit_id,
            'name': 'خالد سعيد حسن',
            'gender': Defendant.GENDER_MALE,
            'nationality': 'يمني',
            'address': 'عدن',
            'phone': '777987654'
        }
        defendant_response = self.client.post('/api/defendants/', defendant_data, format='json')
        self.assertEqual(defendant_response.status_code, status.HTTP_201_CREATED)
        
        # 4. Add response
        response_data = {
            'lawsuit_id': lawsuit_id,
            'response_text': 'نص الرد الكامل',
            'submitted_by': 'محمد أحمد',
            'submission_date': '2024-01-20',
            'hijri_date': '1445/06/08',
            'response_type': Response.RESPONSE_TYPE_REPLY
        }
        response_response = self.client.post('/api/responses/', response_data, format='json')
        self.assertEqual(response_response.status_code, status.HTTP_201_CREATED)
        
        # 5. Create appeal (as lawyer)
        appeal_data = {
            'lawsuit_id': lawsuit_id,
            'appeal_type': Appeal.APPEAL_TYPE_APPEAL,
            'appeal_number': 'AP-INT-001/2024',
            'appeal_reasons': 'أسباب الطعن',
            'appeal_requests': 'طلبات الطعن',
            'higher_court': 'محكمة التمييز',
            'appeal_date': '2024-02-01',
            'hijri_date': '1445/07/20',
            'submitted_by': 'محمد أحمد'
        }
        appeal_response = self.client.post('/api/appeals/', appeal_data, format='json')
        self.assertEqual(appeal_response.status_code, status.HTTP_201_CREATED)
        
        # 6. Issue judgment (as judge)
        self.client.credentials(HTTP_AUTHORIZATION=f'Bearer {self.judge_token}')
        judgment_data = {
            'lawsuit_id': lawsuit_id,
            'judgment_type': Judgment.JUDGMENT_TYPE_PRIMARY,
            'judgment_number': 'J-INT-001/2024',
            'judgment_date': '2024-04-01',
            'hijri_date': '1445/09/21',
            'judgment_text': 'نص الحكم',
            'judge_name': 'القاضي محمد أحمد',
            'court_name': 'محكمة الاستئناف',
            'status': Judgment.STATUS_PENDING
        }
        judgment_response = self.client.post('/api/judgments/', judgment_data, format='json')
        self.assertEqual(judgment_response.status_code, status.HTTP_201_CREATED)
        
        # Verify all data exists
        lawsuit = Lawsuit.objects.get(id=lawsuit_id)
        self.assertEqual(lawsuit.plaintiffs.count(), 1)
        self.assertEqual(lawsuit.defendants.count(), 1)
        self.assertEqual(lawsuit.responses.count(), 1)
        self.assertEqual(lawsuit.appeals.count(), 1)
        self.assertEqual(lawsuit.judgments.count(), 1)

