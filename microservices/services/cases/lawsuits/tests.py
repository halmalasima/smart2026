from django.test import TestCase
from django.contrib.auth.models import User
from django.core.exceptions import ValidationError
from datetime import date
from .models import Lawsuit


class LawsuitModelTest(TestCase):
    """
    Test cases for Lawsuit model
    """
    
    def setUp(self):
        """Set up test data"""
        self.user = User.objects.create_user(
            username='lawyer1',
            email='lawyer@example.com',
            password='testpass123'
        )
    
    def test_create_lawsuit(self):
        """Test creating a lawsuit"""
        lawsuit = Lawsuit.objects.create(
            case_number='123/2024',
            gregorian_date=date(2024, 1, 15),
            hijri_date='1445/06/03',
            case_type=Lawsuit.CASE_TYPE_CIVIL,
            court='محكمة الاستئناف - صنعاء',
            subject='دعوى تعويض عن أضرار',
            facts='وقائع الدعوى...',
            reasons='الأسباب والأسانيد...',
            requests='الطلبات...',
            status=Lawsuit.STATUS_PENDING,
            created_by=self.user
        )
        
        self.assertIsNotNone(lawsuit.id)
        self.assertEqual(lawsuit.case_number, '123/2024')
        self.assertEqual(lawsuit.case_type, Lawsuit.CASE_TYPE_CIVIL)
        self.assertEqual(lawsuit.created_by, self.user)
        self.assertEqual(lawsuit.status, Lawsuit.STATUS_PENDING)
    
    def test_lawsuit_case_number_unique(self):
        """Test that case_number must be unique"""
        Lawsuit.objects.create(
            case_number='123/2024',
            gregorian_date=date(2024, 1, 15),
            hijri_date='1445/06/03',
            case_type=Lawsuit.CASE_TYPE_CIVIL,
            court='محكمة الاستئناف',
            subject='دعوى 1',
            facts='وقائع',
            reasons='أسباب',
            requests='طلبات',
            created_by=self.user
        )
        
        with self.assertRaises(Exception):  # IntegrityError
            Lawsuit.objects.create(
                case_number='123/2024',  # Duplicate
                gregorian_date=date(2024, 1, 16),
                hijri_date='1445/06/04',
                case_type=Lawsuit.CASE_TYPE_COMMERCIAL,
                court='محكمة أخرى',
                subject='دعوى 2',
                facts='وقائع',
                reasons='أسباب',
                requests='طلبات',
                created_by=self.user
            )
    
    def test_lawsuit_subject_max_length(self):
        """Test that subject respects max_length of 150 characters"""
        lawsuit = Lawsuit(
            case_number='124/2024',
            gregorian_date=date(2024, 1, 15),
            hijri_date='1445/06/03',
            case_type=Lawsuit.CASE_TYPE_CIVIL,
            court='محكمة',
            subject='أ' * 150,  # Exactly 150 characters
            facts='وقائع',
            reasons='أسباب',
            requests='طلبات',
            created_by=self.user
        )
        lawsuit.full_clean()  # Should pass
        
        lawsuit.subject = 'أ' * 151  # Exceeds max_length
        with self.assertRaises(ValidationError):
            lawsuit.full_clean()
    
    def test_lawsuit_str(self):
        """Test Lawsuit string representation"""
        lawsuit = Lawsuit.objects.create(
            case_number='125/2024',
            gregorian_date=date(2024, 1, 15),
            hijri_date='1445/06/03',
            case_type=Lawsuit.CASE_TYPE_CIVIL,
            court='محكمة',
            subject='دعوى تجريبية',
            facts='وقائع',
            reasons='أسباب',
            requests='طلبات',
            created_by=self.user
        )
        expected_str = f'{lawsuit.case_number} - {lawsuit.subject}'
        self.assertEqual(str(lawsuit), expected_str)
    
    def test_lawsuit_set_null_on_user_delete(self):
        """Test that created_by is set to NULL when user is deleted"""
        lawsuit = Lawsuit.objects.create(
            case_number='126/2024',
            gregorian_date=date(2024, 1, 15),
            hijri_date='1445/06/03',
            case_type=Lawsuit.CASE_TYPE_CIVIL,
            court='محكمة',
            subject='دعوى',
            facts='وقائع',
            reasons='أسباب',
            requests='طلبات',
            created_by=self.user
        )
        lawsuit_id = lawsuit.id
        
        self.user.delete()
        
        lawsuit.refresh_from_db()
        self.assertIsNone(lawsuit.created_by)
        self.assertTrue(Lawsuit.objects.filter(id=lawsuit_id).exists())
    
    def test_lawsuit_case_type_choices(self):
        """Test Lawsuit case type choices"""
        lawsuit = Lawsuit.objects.create(
            case_number='127/2024',
            gregorian_date=date(2024, 1, 15),
            hijri_date='1445/06/03',
            case_type=Lawsuit.CASE_TYPE_CRIMINAL,
            court='محكمة',
            subject='دعوى جنائية',
            facts='وقائع',
            reasons='أسباب',
            requests='طلبات',
            created_by=self.user
        )
        self.assertEqual(lawsuit.get_case_type_display(), 'جنائي')
    
    def test_lawsuit_status_choices(self):
        """Test Lawsuit status choices"""
        lawsuit = Lawsuit.objects.create(
            case_number='128/2024',
            gregorian_date=date(2024, 1, 15),
            hijri_date='1445/06/03',
            case_type=Lawsuit.CASE_TYPE_CIVIL,
            court='محكمة',
            subject='دعوى',
            facts='وقائع',
            reasons='أسباب',
            requests='طلبات',
            status=Lawsuit.STATUS_JUDGED,
            created_by=self.user
        )
        self.assertEqual(lawsuit.get_status_display(), 'تم الحكم')
