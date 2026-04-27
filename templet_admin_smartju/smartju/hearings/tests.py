from django.test import TestCase
from django.contrib.auth.models import User
from lawsuits.models import Lawsuit
from datetime import date, time
from .models import Hearing


class HearingModelTest(TestCase):
    """
    Test cases for Hearing model
    """
    
    def setUp(self):
        """Set up test data"""
        self.user = User.objects.create_user(
            username='judge1',
            email='judge@example.com',
            password='testpass123'
        )
        self.lawsuit = Lawsuit.objects.create(
            case_number='600/2024',
            gregorian_date=date(2024, 1, 15),
            hijri_date='1445/06/03',
            case_type=Lawsuit.CASE_TYPE_CIVIL,
            court='محكمة الاستئناف',
            subject='دعوى تجريبية',
            facts='وقائع الدعوى',
            reasons='الأسباب',
            requests='الطلبات',
            created_by=self.user
        )
    
    def test_create_hearing(self):
        """Test creating a hearing"""
        hearing = Hearing.objects.create(
            lawsuit=self.lawsuit,
            hearing_date=date(2024, 3, 1),
            hijri_date='1445/08/19',
            hearing_time=time(9, 0),
            notes='ملاحظات الجلسة...',
            judge_name='القاضي محمد أحمد',
            judge=self.user,
            hearing_type=Hearing.HEARING_TYPE_MAIN,
            created_by=self.user
        )
        
        self.assertIsNotNone(hearing.id)
        self.assertEqual(hearing.lawsuit, self.lawsuit)
        self.assertEqual(hearing.judge, self.user)
        self.assertEqual(hearing.hearing_type, Hearing.HEARING_TYPE_MAIN)
        self.assertEqual(hearing.hearing_time, time(9, 0))
    
    def test_hearing_cascade_delete(self):
        """Test that hearing is deleted when lawsuit is deleted"""
        hearing = Hearing.objects.create(
            lawsuit=self.lawsuit,
            hearing_date=date(2024, 3, 1),
            hijri_date='1445/08/19',
            notes='ملاحظات',
            hearing_type=Hearing.HEARING_TYPE_PRELIMINARY,
            created_by=self.user
        )
        hearing_id = hearing.id
        
        self.lawsuit.delete()
        
        self.assertFalse(Hearing.objects.filter(id=hearing_id).exists())
    
    def test_hearing_set_null_on_user_delete(self):
        """Test that judge and created_by are set to NULL when user is deleted"""
        hearing = Hearing.objects.create(
            lawsuit=self.lawsuit,
            hearing_date=date(2024, 3, 1),
            hijri_date='1445/08/19',
            notes='ملاحظات',
            judge_name='القاضي محمد',
            judge=self.user,
            hearing_type=Hearing.HEARING_TYPE_MAIN,
            created_by=self.user
        )
        hearing_id = hearing.id
        
        self.user.delete()
        
        hearing.refresh_from_db()
        self.assertIsNone(hearing.judge)
        self.assertIsNone(hearing.created_by)
        self.assertTrue(Hearing.objects.filter(id=hearing_id).exists())
    
    def test_hearing_type_choices(self):
        """Test Hearing type choices"""
        hearing = Hearing.objects.create(
            lawsuit=self.lawsuit,
            hearing_date=date(2024, 3, 1),
            hijri_date='1445/08/19',
            notes='ملاحظات',
            hearing_type=Hearing.HEARING_TYPE_DECISION,
            created_by=self.user
        )
        self.assertEqual(hearing.get_hearing_type_display(), 'قرار')
