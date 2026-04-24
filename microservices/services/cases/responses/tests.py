from django.test import TestCase
from django.contrib.auth.models import User
from lawsuits.models import Lawsuit
from datetime import date
from .models import Response


class ResponseModelTest(TestCase):
    """
    Test cases for Response model
    """
    
    def setUp(self):
        """Set up test data"""
        self.user = User.objects.create_user(
            username='lawyer1',
            email='lawyer@example.com',
            password='testpass123'
        )
        self.lawsuit = Lawsuit.objects.create(
            case_number='400/2024',
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
    
    def test_create_response(self):
        """Test creating a response"""
        response = Response.objects.create(
            lawsuit=self.lawsuit,
            response_text='نص الرد الكامل...',
            submitted_by='محمد أحمد',
            submission_date=date(2024, 1, 20),
            hijri_date='1445/06/08',
            response_type=Response.RESPONSE_TYPE_REPLY,
            submitted_by_user=self.user
        )
        
        self.assertIsNotNone(response.id)
        self.assertEqual(response.lawsuit, self.lawsuit)
        self.assertEqual(response.submitted_by, 'محمد أحمد')
        self.assertEqual(response.response_type, Response.RESPONSE_TYPE_REPLY)
        self.assertEqual(response.submitted_by_user, self.user)
    
    def test_response_cascade_delete(self):
        """Test that response is deleted when lawsuit is deleted"""
        response = Response.objects.create(
            lawsuit=self.lawsuit,
            response_text='نص الرد',
            submitted_by='محمد أحمد',
            submission_date=date(2024, 1, 20),
            hijri_date='1445/06/08',
            response_type=Response.RESPONSE_TYPE_MEMORANDUM
        )
        response_id = response.id
        
        self.lawsuit.delete()
        
        self.assertFalse(Response.objects.filter(id=response_id).exists())
    
    def test_response_set_null_on_user_delete(self):
        """Test that submitted_by_user is set to NULL when user is deleted"""
        response = Response.objects.create(
            lawsuit=self.lawsuit,
            response_text='نص الرد',
            submitted_by='محمد أحمد',
            submission_date=date(2024, 1, 20),
            hijri_date='1445/06/08',
            response_type=Response.RESPONSE_TYPE_REPLY,
            submitted_by_user=self.user
        )
        response_id = response.id
        
        self.user.delete()
        
        response.refresh_from_db()
        self.assertIsNone(response.submitted_by_user)
        self.assertTrue(Response.objects.filter(id=response_id).exists())
    
    def test_response_get_submitted_by_display(self):
        """Test Response get_submitted_by_display method"""
        response = Response.objects.create(
            lawsuit=self.lawsuit,
            response_text='نص الرد',
            submitted_by='محمد أحمد',
            submission_date=date(2024, 1, 20),
            hijri_date='1445/06/08',
            response_type=Response.RESPONSE_TYPE_REPLY,
            submitted_by_user=self.user
        )
        # Should return user's name if user exists
        display = response.get_submitted_by_display()
        self.assertIsNotNone(display)
        
        # Test without user
        response.submitted_by_user = None
        response.save()
        display = response.get_submitted_by_display()
        self.assertEqual(display, 'محمد أحمد')
    
    def test_response_type_choices(self):
        """Test Response type choices"""
        response = Response.objects.create(
            lawsuit=self.lawsuit,
            response_text='نص الرد',
            submitted_by='محمد',
            submission_date=date(2024, 1, 20),
            hijri_date='1445/06/08',
            response_type=Response.RESPONSE_TYPE_MEMORANDUM
        )
        self.assertEqual(response.get_response_type_display(), 'مذكرة')
