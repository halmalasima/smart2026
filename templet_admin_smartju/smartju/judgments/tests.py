from django.test import TestCase
from django.contrib.auth.models import User
from lawsuits.models import Lawsuit
from datetime import date
from .models import Judgment


class JudgmentModelTest(TestCase):
    """
    Test cases for Judgment model
    """
    
    def setUp(self):
        """Set up test data"""
        self.user = User.objects.create_user(
            username='judge1',
            email='judge@example.com',
            password='testpass123'
        )
        self.lawsuit = Lawsuit.objects.create(
            case_number='700/2024',
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
    
    def test_create_judgment(self):
        """Test creating a judgment"""
        judgment = Judgment.objects.create(
            lawsuit=self.lawsuit,
            judgment_type=Judgment.JUDGMENT_TYPE_PRIMARY,
            judgment_number='J-001/2024',
            judgment_date=date(2024, 4, 1),
            hijri_date='1445/09/21',
            judgment_text='نص الحكم الكامل...',
            summary='ملخص الحكم',
            judge_name='القاضي محمد أحمد',
            judge=self.user,
            court_name='محكمة الاستئناف - صنعاء',
            status=Judgment.STATUS_PENDING,
            created_by=self.user
        )
        
        self.assertIsNotNone(judgment.id)
        self.assertEqual(judgment.lawsuit, self.lawsuit)
        self.assertEqual(judgment.judgment_number, 'J-001/2024')
        self.assertEqual(judgment.judgment_type, Judgment.JUDGMENT_TYPE_PRIMARY)
        self.assertEqual(judgment.status, Judgment.STATUS_PENDING)
    
    def test_judgment_unique_together(self):
        """Test that judgment_number must be unique per lawsuit"""
        Judgment.objects.create(
            lawsuit=self.lawsuit,
            judgment_type=Judgment.JUDGMENT_TYPE_PRIMARY,
            judgment_number='J-001/2024',
            judgment_date=date(2024, 4, 1),
            hijri_date='1445/09/21',
            judgment_text='نص الحكم',
            judge_name='القاضي محمد',
            court_name='محكمة',
            created_by=self.user
        )
        
        # Same judgment_number for same lawsuit should fail
        with self.assertRaises(Exception):  # IntegrityError
            Judgment.objects.create(
                lawsuit=self.lawsuit,
                judgment_type=Judgment.JUDGMENT_TYPE_APPEAL,
                judgment_number='J-001/2024',  # Duplicate for same lawsuit
                judgment_date=date(2024, 5, 1),
                hijri_date='1445/10/21',
                judgment_text='نص حكم آخر',
                judge_name='القاضي أحمد',
                court_name='محكمة أخرى',
                created_by=self.user
            )
    
    def test_multiple_judgments_per_lawsuit(self):
        """Test that multiple judgments can exist for one lawsuit with different numbers"""
        judgment1 = Judgment.objects.create(
            lawsuit=self.lawsuit,
            judgment_type=Judgment.JUDGMENT_TYPE_PRIMARY,
            judgment_number='J-001/2024',
            judgment_date=date(2024, 4, 1),
            hijri_date='1445/09/21',
            judgment_text='حكم ابتدائي',
            judge_name='القاضي محمد',
            court_name='محكمة',
            created_by=self.user
        )
        judgment2 = Judgment.objects.create(
            lawsuit=self.lawsuit,
            judgment_type=Judgment.JUDGMENT_TYPE_APPEAL,
            judgment_number='J-002/2024',  # Different number
            judgment_date=date(2024, 5, 1),
            hijri_date='1445/10/21',
            judgment_text='حكم استئناف',
            judge_name='القاضي أحمد',
            court_name='محكمة',
            created_by=self.user
        )
        
        self.assertEqual(self.lawsuit.judgments.count(), 2)
        self.assertIn(judgment1, self.lawsuit.judgments.all())
        self.assertIn(judgment2, self.lawsuit.judgments.all())
    
    def test_judgment_cascade_delete(self):
        """Test that judgment is deleted when lawsuit is deleted"""
        judgment = Judgment.objects.create(
            lawsuit=self.lawsuit,
            judgment_type=Judgment.JUDGMENT_TYPE_PRIMARY,
            judgment_number='J-003/2024',
            judgment_date=date(2024, 4, 1),
            hijri_date='1445/09/21',
            judgment_text='نص الحكم',
            judge_name='القاضي محمد',
            court_name='محكمة',
            created_by=self.user
        )
        judgment_id = judgment.id
        
        self.lawsuit.delete()
        
        self.assertFalse(Judgment.objects.filter(id=judgment_id).exists())
    
    def test_judgment_set_null_on_user_delete(self):
        """Test that judge and created_by are set to NULL when user is deleted"""
        judgment = Judgment.objects.create(
            lawsuit=self.lawsuit,
            judgment_type=Judgment.JUDGMENT_TYPE_PRIMARY,
            judgment_number='J-004/2024',
            judgment_date=date(2024, 4, 1),
            hijri_date='1445/09/21',
            judgment_text='نص الحكم',
            judge_name='القاضي محمد',
            judge=self.user,
            court_name='محكمة',
            created_by=self.user
        )
        judgment_id = judgment.id
        
        self.user.delete()
        
        judgment.refresh_from_db()
        self.assertIsNone(judgment.judge)
        self.assertIsNone(judgment.created_by)
        self.assertTrue(Judgment.objects.filter(id=judgment_id).exists())
    
    def test_judgment_type_choices(self):
        """Test Judgment type choices"""
        judgment = Judgment.objects.create(
            lawsuit=self.lawsuit,
            judgment_type=Judgment.JUDGMENT_TYPE_FINAL,
            judgment_number='J-005/2024',
            judgment_date=date(2024, 4, 1),
            hijri_date='1445/09/21',
            judgment_text='نص الحكم',
            judge_name='القاضي محمد',
            court_name='محكمة',
            created_by=self.user
        )
        self.assertEqual(judgment.get_judgment_type_display(), 'بات')
