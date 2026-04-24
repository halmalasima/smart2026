from django.test import TestCase
from django.contrib.auth.models import User
from lawsuits.models import Lawsuit
from datetime import date
from .models import Plaintiff, Defendant


class PartyModelTest(TestCase):
    """
    Test cases for Plaintiff and Defendant models
    """
    
    def setUp(self):
        """Set up test data"""
        self.user = User.objects.create_user(
            username='lawyer1',
            email='lawyer@example.com',
            password='testpass123'
        )
        self.lawsuit = Lawsuit.objects.create(
            case_number='200/2024',
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
    
    def test_create_plaintiff(self):
        """Test creating a plaintiff"""
        plaintiff = Plaintiff.objects.create(
            lawsuit=self.lawsuit,
            name='أحمد محمد علي',
            gender=Plaintiff.GENDER_MALE,
            nationality='يمني',
            occupation='مهندس',
            address='صنعاء - شارع الزبيري',
            phone='777123456',
            attorney_name='محمد أحمد',
            attorney_phone='777654321'
        )
        
        self.assertIsNotNone(plaintiff.id)
        self.assertEqual(plaintiff.lawsuit, self.lawsuit)
        self.assertEqual(plaintiff.name, 'أحمد محمد علي')
        self.assertEqual(plaintiff.gender, Plaintiff.GENDER_MALE)
        self.assertEqual(plaintiff.nationality, 'يمني')
    
    def test_create_defendant(self):
        """Test creating a defendant"""
        defendant = Defendant.objects.create(
            lawsuit=self.lawsuit,
            name='خالد سعيد حسن',
            gender=Defendant.GENDER_MALE,
            nationality='يمني',
            occupation='تاجر',
            address='عدن - شارع الجمهورية',
            phone='777987654'
        )
        
        self.assertIsNotNone(defendant.id)
        self.assertEqual(defendant.lawsuit, self.lawsuit)
        self.assertEqual(defendant.name, 'خالد سعيد حسن')
        self.assertEqual(defendant.gender, Defendant.GENDER_MALE)
    
    def test_plaintiff_cascade_delete(self):
        """Test that plaintiff is deleted when lawsuit is deleted"""
        plaintiff = Plaintiff.objects.create(
            lawsuit=self.lawsuit,
            name='أحمد محمد',
            gender=Plaintiff.GENDER_MALE,
            nationality='يمني',
            address='صنعاء'
        )
        plaintiff_id = plaintiff.id
        
        self.lawsuit.delete()
        
        self.assertFalse(Plaintiff.objects.filter(id=plaintiff_id).exists())
    
    def test_defendant_cascade_delete(self):
        """Test that defendant is deleted when lawsuit is deleted"""
        defendant = Defendant.objects.create(
            lawsuit=self.lawsuit,
            name='خالد سعيد',
            gender=Defendant.GENDER_MALE,
            nationality='يمني',
            address='عدن'
        )
        defendant_id = defendant.id
        
        self.lawsuit.delete()
        
        self.assertFalse(Defendant.objects.filter(id=defendant_id).exists())
    
    def test_plaintiff_str(self):
        """Test Plaintiff string representation"""
        plaintiff = Plaintiff.objects.create(
            lawsuit=self.lawsuit,
            name='أحمد محمد علي',
            gender=Plaintiff.GENDER_MALE,
            nationality='يمني',
            address='صنعاء'
        )
        expected_str = f'{plaintiff.name} - {self.lawsuit.case_number}'
        self.assertEqual(str(plaintiff), expected_str)
    
    def test_defendant_str(self):
        """Test Defendant string representation"""
        defendant = Defendant.objects.create(
            lawsuit=self.lawsuit,
            name='خالد سعيد حسن',
            gender=Defendant.GENDER_MALE,
            nationality='يمني',
            address='عدن'
        )
        expected_str = f'{defendant.name} - {self.lawsuit.case_number}'
        self.assertEqual(str(defendant), expected_str)
    
    def test_multiple_plaintiffs_per_lawsuit(self):
        """Test that multiple plaintiffs can be added to one lawsuit"""
        plaintiff1 = Plaintiff.objects.create(
            lawsuit=self.lawsuit,
            name='أحمد محمد',
            gender=Plaintiff.GENDER_MALE,
            nationality='يمني',
            address='صنعاء'
        )
        plaintiff2 = Plaintiff.objects.create(
            lawsuit=self.lawsuit,
            name='فاطمة علي',
            gender=Plaintiff.GENDER_FEMALE,
            nationality='يمنية',
            address='تعز'
        )
        
        self.assertEqual(self.lawsuit.plaintiffs.count(), 2)
        self.assertIn(plaintiff1, self.lawsuit.plaintiffs.all())
        self.assertIn(plaintiff2, self.lawsuit.plaintiffs.all())
    
    def test_multiple_defendants_per_lawsuit(self):
        """Test that multiple defendants can be added to one lawsuit"""
        defendant1 = Defendant.objects.create(
            lawsuit=self.lawsuit,
            name='خالد سعيد',
            gender=Defendant.GENDER_MALE,
            nationality='يمني',
            address='عدن'
        )
        defendant2 = Defendant.objects.create(
            lawsuit=self.lawsuit,
            name='سارة أحمد',
            gender=Defendant.GENDER_FEMALE,
            nationality='يمنية',
            address='الحديدة'
        )
        
        self.assertEqual(self.lawsuit.defendants.count(), 2)
        self.assertIn(defendant1, self.lawsuit.defendants.all())
        self.assertIn(defendant2, self.lawsuit.defendants.all())
    
    def test_plaintiff_gender_choices(self):
        """Test Plaintiff gender choices"""
        plaintiff = Plaintiff.objects.create(
            lawsuit=self.lawsuit,
            name='أحمد محمد',
            gender=Plaintiff.GENDER_MALE,
            nationality='يمني',
            address='صنعاء'
        )
        self.assertEqual(plaintiff.get_gender_display(), 'ذكر')
        
        plaintiff.gender = Plaintiff.GENDER_FEMALE
        plaintiff.save()
        self.assertEqual(plaintiff.get_gender_display(), 'أنثى')
