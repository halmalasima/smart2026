from django.test import TestCase
from django.contrib.auth.models import User
from lawsuits.models import Lawsuit
from datetime import date
from .models import Appeal


class AppealModelTest(TestCase):
    """
    Test cases for Appeal model
    """
    
    def setUp(self):
        """Set up test data"""
        self.user = User.objects.create_user(
            username='lawyer1',
            email='lawyer@example.com',
            password='testpass123'
        )
        self.lawsuit = Lawsuit.objects.create(
            case_number='500/2024',
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
    
    def test_create_appeal(self):
        """Test creating an appeal"""
        appeal = Appeal.objects.create(
            lawsuit=self.lawsuit,
            appeal_type=Appeal.APPEAL_TYPE_APPEAL,
            appeal_number='AP-001/2024',
            appeal_reasons='أسباب الطعن...',
            appeal_requests='طلبات الطعن...',
            higher_court='محكمة التمييز',
            status=Appeal.STATUS_PENDING,
            appeal_date=date(2024, 2, 1),
            hijri_date='1445/07/20',
            submitted_by='محمد أحمد',
            submitted_by_user=self.user
        )
        
        self.assertIsNotNone(appeal.id)
        self.assertEqual(appeal.lawsuit, self.lawsuit)
        self.assertEqual(appeal.appeal_number, 'AP-001/2024')
        self.assertEqual(appeal.appeal_type, Appeal.APPEAL_TYPE_APPEAL)
        self.assertEqual(appeal.status, Appeal.STATUS_PENDING)
    
    def test_appeal_number_unique(self):
        """Test that appeal_number must be unique"""
        Appeal.objects.create(
            lawsuit=self.lawsuit,
            appeal_type=Appeal.APPEAL_TYPE_APPEAL,
            appeal_number='AP-001/2024',
            appeal_reasons='أسباب',
            appeal_requests='طلبات',
            higher_court='محكمة التمييز',
            appeal_date=date(2024, 2, 1),
            hijri_date='1445/07/20',
            submitted_by='محمد'
        )
        
        lawsuit2 = Lawsuit.objects.create(
            case_number='501/2024',
            gregorian_date=date(2024, 1, 16),
            hijri_date='1445/06/04',
            case_type=Lawsuit.CASE_TYPE_CIVIL,
            court='محكمة',
            subject='دعوى 2',
            facts='وقائع',
            reasons='أسباب',
            requests='طلبات',
            created_by=self.user
        )
        
        with self.assertRaises(Exception):  # IntegrityError
            Appeal.objects.create(
                lawsuit=lawsuit2,
                appeal_type=Appeal.APPEAL_TYPE_APPEAL,
                appeal_number='AP-001/2024',  # Duplicate
                appeal_reasons='أسباب',
                appeal_requests='طلبات',
                higher_court='محكمة',
                appeal_date=date(2024, 2, 2),
                hijri_date='1445/07/21',
                submitted_by='أحمد'
            )
    
    def test_appeal_cascade_delete(self):
        """Test that appeal is deleted when lawsuit is deleted"""
        appeal = Appeal.objects.create(
            lawsuit=self.lawsuit,
            appeal_type=Appeal.APPEAL_TYPE_APPEAL,
            appeal_number='AP-002/2024',
            appeal_reasons='أسباب',
            appeal_requests='طلبات',
            higher_court='محكمة',
            appeal_date=date(2024, 2, 1),
            hijri_date='1445/07/20',
            submitted_by='محمد'
        )
        appeal_id = appeal.id
        
        self.lawsuit.delete()
        
        self.assertFalse(Appeal.objects.filter(id=appeal_id).exists())
    
    def test_appeal_set_null_on_user_delete(self):
        """Test that submitted_by_user is set to NULL when user is deleted"""
        appeal = Appeal.objects.create(
            lawsuit=self.lawsuit,
            appeal_type=Appeal.APPEAL_TYPE_APPEAL,
            appeal_number='AP-003/2024',
            appeal_reasons='أسباب',
            appeal_requests='طلبات',
            higher_court='محكمة',
            appeal_date=date(2024, 2, 1),
            hijri_date='1445/07/20',
            submitted_by='محمد',
            submitted_by_user=self.user
        )
        appeal_id = appeal.id
        
        self.user.delete()
        
        appeal.refresh_from_db()
        self.assertIsNone(appeal.submitted_by_user)
        self.assertTrue(Appeal.objects.filter(id=appeal_id).exists())
    
    def test_appeal_type_choices(self):
        """Test Appeal type choices"""
        appeal = Appeal.objects.create(
            lawsuit=self.lawsuit,
            appeal_type=Appeal.APPEAL_TYPE_CASSATION,
            appeal_number='AP-004/2024',
            appeal_reasons='أسباب',
            appeal_requests='طلبات',
            higher_court='محكمة',
            appeal_date=date(2024, 2, 1),
            hijri_date='1445/07/20',
            submitted_by='محمد'
        )
        self.assertEqual(appeal.get_appeal_type_display(), 'تمييز')
