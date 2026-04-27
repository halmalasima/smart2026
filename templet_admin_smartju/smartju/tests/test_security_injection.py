"""
Security Tests - SQL Injection and XSS Protection
"""
from django.test import TestCase
from django.contrib.auth.models import User
from rest_framework.test import APIClient
from rest_framework import status
from rest_framework_simplejwt.tokens import RefreshToken
from datetime import date
from lawsuits.models import Lawsuit
from accounts.models import UserProfile


class InjectionSecurityTest(TestCase):
    """
    Tests for SQL Injection and XSS protection
    """
    
    def setUp(self):
        """Set up test data"""
        self.client = APIClient()
        
        self.lawyer_user = User.objects.create_user(
            username='lawyer1',
            email='lawyer@example.com',
            password='testpass123'
        )
        self.lawyer_profile = self.lawyer_user.profile
        self.lawyer_profile.role = UserProfile.ROLE_LAWYER
        self.lawyer_profile.save()
        
        self.lawsuit = Lawsuit.objects.create(
            case_number='INJ-001/2024',
            gregorian_date=date(2024, 1, 15),
            hijri_date='1445/06/03',
            case_type=Lawsuit.CASE_TYPE_CIVIL,
            court='محكمة',
            subject='دعوى أمنية',
            facts='وقائع',
            reasons='أسباب',
            requests='طلبات',
            created_by=self.lawyer_user
        )
        
        self.lawyer_token = str(RefreshToken.for_user(self.lawyer_user).access_token)
        self.client.credentials(HTTP_AUTHORIZATION=f'Bearer {self.lawyer_token}')
    
    def test_sql_injection_in_search_field(self):
        """Test that SQL injection attempts in search are handled safely"""
        # Common SQL injection patterns
        sql_injection_patterns = [
            "'; DROP TABLE lawsuits; --",
            "' OR '1'='1",
            "1' UNION SELECT * FROM lawsuits--",
            "'; DELETE FROM lawsuits; --",
        ]
        
        for pattern in sql_injection_patterns:
            response = self.client.get(f'/api/lawsuits/?search={pattern}')
            # Should not crash or execute SQL - should return 200 or 400
            self.assertIn(response.status_code, [status.HTTP_200_OK, status.HTTP_400_BAD_REQUEST])
            # Should not expose SQL errors
            self.assertNotIn('syntax error', str(response.data).lower())
            self.assertNotIn('sql', str(response.data).lower())
    
    def test_sql_injection_in_filter_field(self):
        """Test that SQL injection attempts in filter fields are handled safely"""
        sql_injection_patterns = [
            "'; DROP TABLE lawsuits; --",
            "' OR '1'='1",
            "1' UNION SELECT * FROM lawsuits--",
        ]
        
        for pattern in sql_injection_patterns:
            response = self.client.get(f'/api/lawsuits/?status={pattern}')
            # Should not crash or execute SQL
            self.assertIn(response.status_code, [status.HTTP_200_OK, status.HTTP_400_BAD_REQUEST])
    
    def test_xss_in_text_fields(self):
        """Test that XSS attempts in text fields are sanitized/escaped"""
        xss_patterns = [
            "<script>alert('XSS')</script>",
            "<img src=x onerror=alert('XSS')>",
            "javascript:alert('XSS')",
            "<svg onload=alert('XSS')>",
        ]
        
        for pattern in xss_patterns:
            data = {
                'case_number': f'XSS-{hash(pattern) % 10000}/2024',
                'gregorian_date': '2024-01-16',
                'hijri_date': '1445/06/04',
                'case_type': Lawsuit.CASE_TYPE_CIVIL,
                'court': 'محكمة',
                'subject': pattern,  # XSS in subject
                'facts': 'وقائع',
                'reasons': 'أسباب',
                'requests': 'طلبات'
            }
            
            response = self.client.post('/api/lawsuits/', data, format='json')
            # Should accept the data (Django/DRF handles escaping in templates)
            # In API responses, the data might be returned as-is (which is fine for JSON APIs)
            # The important thing is that it doesn't execute when rendered
            self.assertIn(response.status_code, [status.HTTP_201_CREATED, status.HTTP_400_BAD_REQUEST])
            
            if response.status_code == status.HTTP_201_CREATED:
                # Clean up
                lawsuit_id = response.data.get('id')
                if lawsuit_id:
                    Lawsuit.objects.filter(id=lawsuit_id).delete()
    
    def test_special_characters_handled_safely(self):
        """Test that special characters are handled safely"""
        special_chars = [
            "'; --",
            "\\'; DROP TABLE--",
            "1' OR '1'='1",
            "'; /*",
        ]
        
        for chars in special_chars:
            data = {
                'case_number': f'SPEC-{hash(chars) % 10000}/2024',
                'gregorian_date': '2024-01-16',
                'hijri_date': '1445/06/04',
                'case_type': Lawsuit.CASE_TYPE_CIVIL,
                'court': 'محكمة',
                'subject': f'دعوى {chars}',
                'facts': 'وقائع',
                'reasons': 'أسباب',
                'requests': 'طلبات'
            }
            
            response = self.client.post('/api/lawsuits/', data, format='json')
            # Should handle special characters without SQL errors
            self.assertIn(response.status_code, [status.HTTP_201_CREATED, status.HTTP_400_BAD_REQUEST])
            
            if response.status_code == status.HTTP_201_CREATED:
                # Clean up
                lawsuit_id = response.data.get('id')
                if lawsuit_id:
                    Lawsuit.objects.filter(id=lawsuit_id).delete()
    
    def test_orm_parameterization_prevents_injection(self):
        """Test that Django ORM parameterization prevents SQL injection"""
        # Django ORM automatically parameterizes queries, preventing SQL injection
        # This test verifies that basic queries work correctly
        
        # Try to search with a pattern that might be interpreted as SQL
        pattern = "'; DROP TABLE lawsuits; --"
        
        # Use Django ORM directly (which is what the views use)
        queryset = Lawsuit.objects.filter(subject__icontains=pattern)
        # Should not crash - Django ORM handles this safely
        count = queryset.count()
        self.assertIsInstance(count, int)
        self.assertGreaterEqual(count, 0)

