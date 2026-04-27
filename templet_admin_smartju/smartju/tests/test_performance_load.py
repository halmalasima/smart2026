"""
Performance and Load Tests
"""
import time
from django.test import TestCase, TransactionTestCase
from django.contrib.auth.models import User
from django.db import connection, reset_queries
from rest_framework.test import APIClient
from rest_framework import status
from rest_framework_simplejwt.tokens import RefreshToken
from datetime import date, timedelta
from lawsuits.models import Lawsuit
from parties.models import Plaintiff, Defendant
from attachments.models import Attachment
from responses.models import Response
from accounts.models import UserProfile
from django.core.files.uploadedfile import SimpleUploadedFile
import os


class PerformanceLoadTest(TransactionTestCase):
    """
    Performance and Load Tests
    Note: Using TransactionTestCase to allow testing large datasets
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
        
        self.lawyer_token = str(RefreshToken.for_user(self.lawyer_user).access_token)
        self.client.credentials(HTTP_AUTHORIZATION=f'Bearer {self.lawyer_token}')
    
    def tearDown(self):
        """Clean up"""
        # Clean up uploaded files
        for attachment in Attachment.objects.all():
            if attachment.file:
                try:
                    if os.path.exists(attachment.file.path):
                        os.remove(attachment.file.path)
                except (ValueError, AttributeError):
                    pass
    
    def test_create_1000_lawsuits_performance(self):
        """
        Test creating 1000 lawsuits and measure performance
        """
        print("\n" + "="*60)
        print("Performance Test: Creating 1000 Lawsuits")
        print("="*60)
        
        start_time = time.time()
        reset_queries()
        
        lawsuits_created = 0
        for i in range(1000):
            Lawsuit.objects.create(
                case_number=f'PERF-{i:04d}/2024',
                gregorian_date=date(2024, 1, 1) + timedelta(days=i % 365),
                hijri_date=f'1445/{6 + (i % 12):02d}/{(i % 28) + 1:02d}',
                case_type=Lawsuit.CASE_TYPE_CIVIL if i % 3 == 0 else Lawsuit.CASE_TYPE_COMMERCIAL,
                court=f'محكمة {i % 10}',
                subject=f'دعوى أداء {i}',
                facts=f'وقائع الدعوى رقم {i}',
                reasons=f'الأسباب والأسانيد للدعوى {i}',
                requests=f'الطلبات المقدمة في الدعوى {i}',
                status=Lawsuit.STATUS_PENDING if i % 2 == 0 else Lawsuit.STATUS_IN_PROGRESS,
                created_by=self.lawyer_user
            )
            lawsuits_created += 1
        
        end_time = time.time()
        execution_time = end_time - start_time
        query_count = len(connection.queries)
        
        print(f"Lawsuits Created: {lawsuits_created}")
        print(f"Execution Time: {execution_time:.2f} seconds")
        print(f"Average Time per Lawsuit: {(execution_time / lawsuits_created) * 1000:.2f} ms")
        print(f"Database Queries: {query_count}")
        print(f"Queries per Lawsuit: {query_count / lawsuits_created:.2f}")
        print("="*60)
        
        # Verify all lawsuits were created
        self.assertEqual(Lawsuit.objects.count(), lawsuits_created)
        
        # Performance assertions (adjust thresholds based on your requirements)
        self.assertLess(execution_time, 60.0, "Creating 1000 lawsuits should take less than 60 seconds")
        print(f"✅ Performance test passed: {execution_time:.2f}s < 60s")
    
    def test_fetch_lawsuits_with_relations_performance(self):
        """
        Test fetching lawsuits with related parties and attachments
        Measure performance with and without select_related/prefetch_related
        """
        print("\n" + "="*60)
        print("Performance Test: Fetching Lawsuits with Relations")
        print("="*60)
        
        # Create test data: 100 lawsuits, each with 2 plaintiffs, 2 defendants, 3 attachments
        lawsuits = []
        for i in range(100):
            lawsuit = Lawsuit.objects.create(
                case_number=f'REL-{i:03d}/2024',
                gregorian_date=date(2024, 1, 1) + timedelta(days=i),
                hijri_date=f'1445/06/{(i % 28) + 1:02d}',
                case_type=Lawsuit.CASE_TYPE_CIVIL,
                court='محكمة',
                subject=f'دعوى علاقات {i}',
                facts='وقائع',
                reasons='أسباب',
                requests='طلبات',
                created_by=self.lawyer_user
            )
            lawsuits.append(lawsuit)
            
            # Add 2 plaintiffs
            for j in range(2):
                Plaintiff.objects.create(
                    lawsuit=lawsuit,
                    name=f'مدعي {i}-{j}',
                    gender=Plaintiff.GENDER_MALE,
                    nationality='يمني',
                    address='صنعاء',
                    phone=f'777{i:03d}{j}'
                )
            
            # Add 2 defendants
            for j in range(2):
                Defendant.objects.create(
                    lawsuit=lawsuit,
                    name=f'مدعى عليه {i}-{j}',
                    gender=Defendant.GENDER_MALE,
                    nationality='يمني',
                    address='عدن',
                    phone=f'777{i:03d}{j+2}'
                )
            
            # Add 3 attachments
            for j in range(3):
                test_file = SimpleUploadedFile(
                    f"test_{i}_{j}.txt",
                    b"Test file content",
                    content_type="text/plain"
                )
                Attachment.objects.create(
                    lawsuit=lawsuit,
                    document_type=Attachment.DOC_TYPE_EVIDENCE,
                    gregorian_date=date(2024, 1, 1) + timedelta(days=i),
                    hijri_date=f'1445/06/{(i % 28) + 1:02d}',
                    page_count=1,
                    content=f'محتوى {i}-{j}',
                    evidence_basis='وجه استدلال',
                    file=test_file
                )
        
        print(f"\nCreated test data: 100 lawsuits, 200 plaintiffs, 200 defendants, 300 attachments")
        
        # Test 1: Fetch WITHOUT optimization (N+1 problem)
        print("\n--- Test 1: Fetch WITHOUT optimization ---")
        reset_queries()
        start_time = time.time()
        
        lawsuits_list = list(Lawsuit.objects.all()[:50])  # Get first 50
        for lawsuit in lawsuits_list:
            _ = lawsuit.plaintiffs.all()  # N+1 query
            _ = lawsuit.defendants.all()  # N+1 query
            _ = lawsuit.attachments.all()  # N+1 query
            _ = lawsuit.created_by  # N+1 query
        
        end_time = time.time()
        query_count_no_opt = len(connection.queries)
        time_no_opt = end_time - start_time
        
        print(f"Execution Time: {time_no_opt:.4f} seconds")
        print(f"Database Queries: {query_count_no_opt}")
        print(f"Queries per Lawsuit: {query_count_no_opt / 50:.2f}")
        
        # Test 2: Fetch WITH optimization (select_related/prefetch_related)
        print("\n--- Test 2: Fetch WITH optimization ---")
        reset_queries()
        start_time = time.time()
        
        lawsuits_list_opt = list(
            Lawsuit.objects
            .select_related('created_by')  # Optimize ForeignKey
            .prefetch_related('plaintiffs', 'defendants', 'attachments')  # Optimize reverse ForeignKey
            .all()[:50]
        )
        for lawsuit in lawsuits_list_opt:
            _ = list(lawsuit.plaintiffs.all())  # No additional query
            _ = list(lawsuit.defendants.all())  # No additional query
            _ = list(lawsuit.attachments.all())  # No additional query
            _ = lawsuit.created_by  # No additional query
        
        end_time = time.time()
        query_count_opt = len(connection.queries)
        time_opt = end_time - start_time
        
        print(f"Execution Time: {time_opt:.4f} seconds")
        print(f"Database Queries: {query_count_opt}")
        print(f"Queries per Lawsuit: {query_count_opt / 50:.2f}")
        
        # Performance improvement
        improvement = ((time_no_opt - time_opt) / time_no_opt) * 100
        query_reduction = query_count_no_opt - query_count_opt
        
        print("\n--- Performance Improvement ---")
        print(f"Time Improvement: {improvement:.1f}%")
        print(f"Query Reduction: {query_reduction} queries ({query_reduction/query_count_no_opt*100:.1f}% reduction)")
        print("="*60)
        
        # Assertions
        self.assertLess(query_count_opt, query_count_no_opt, "Optimized queries should be less than unoptimized")
        self.assertLess(time_opt, time_no_opt, "Optimized time should be less than unoptimized")
        
        print(f"✅ Optimization test passed: {improvement:.1f}% improvement, {query_reduction} fewer queries")
    
    def test_api_response_time_lawsuits_list(self):
        """
        Test API response time for lawsuits list endpoint
        """
        print("\n" + "="*60)
        print("Performance Test: API Response Time - Lawsuits List")
        print("="*60)
        
        # Create 200 lawsuits
        for i in range(200):
            Lawsuit.objects.create(
                case_number=f'API-{i:03d}/2024',
                gregorian_date=date(2024, 1, 1) + timedelta(days=i % 365),
                hijri_date=f'1445/06/{(i % 28) + 1:02d}',
                case_type=Lawsuit.CASE_TYPE_CIVIL,
                court='محكمة',
                subject=f'دعوى API {i}',
                facts='وقائع',
                reasons='أسباب',
                requests='طلبات',
                created_by=self.lawyer_user
            )
        
        print(f"Created 200 lawsuits for testing")
        
        # Test API response time
        reset_queries()
        start_time = time.time()
        
        response = self.client.get('/api/lawsuits/')
        
        end_time = time.time()
        response_time = end_time - start_time
        query_count = len(connection.queries)
        
        print(f"\nAPI Response Time: {response_time:.4f} seconds ({response_time * 1000:.2f} ms)")
        print(f"Database Queries: {query_count}")
        print(f"Status Code: {response.status_code}")
        
        if 'pagination' in response.data:
            print(f"Results Returned: {len(response.data.get('data', []))}")
            print(f"Total Count: {response.data['pagination'].get('count', 0)}")
        
        print("="*60)
        
        # Assertions
        self.assertEqual(response.status_code, status.HTTP_200_OK)
        self.assertLess(response_time, 2.0, "API response should be less than 2 seconds")
        
        print(f"✅ API response time test passed: {response_time * 1000:.2f}ms < 2000ms")
    
    def test_bulk_create_performance(self):
        """
        Test bulk_create performance vs individual creates
        """
        print("\n" + "="*60)
        print("Performance Test: Bulk Create vs Individual Create")
        print("="*60)
        
        # Test 1: Individual creates
        print("\n--- Test 1: Individual Creates (100 lawsuits) ---")
        reset_queries()
        start_time = time.time()
        
        lawsuits_individual = []
        for i in range(100):
            lawsuit = Lawsuit(
                case_number=f'IND-{i:03d}/2024',
                gregorian_date=date(2024, 1, 1) + timedelta(days=i),
                hijri_date=f'1445/06/{(i % 28) + 1:02d}',
                case_type=Lawsuit.CASE_TYPE_CIVIL,
                court='محكمة',
                subject=f'دعوى فردية {i}',
                facts='وقائع',
                reasons='أسباب',
                requests='طلبات',
                created_by=self.lawyer_user
            )
            lawsuits_individual.append(lawsuit)
            lawsuit.save()  # Individual save
        
        end_time = time.time()
        time_individual = end_time - start_time
        query_count_individual = len(connection.queries)
        
        print(f"Execution Time: {time_individual:.4f} seconds")
        print(f"Database Queries: {query_count_individual}")
        
        # Clean up
        Lawsuit.objects.filter(case_number__startswith='IND-').delete()
        
        # Test 2: Bulk create
        print("\n--- Test 2: Bulk Create (100 lawsuits) ---")
        reset_queries()
        start_time = time.time()
        
        lawsuits_bulk = []
        for i in range(100):
            lawsuit = Lawsuit(
                case_number=f'BULK-{i:03d}/2024',
                gregorian_date=date(2024, 1, 1) + timedelta(days=i),
                hijri_date=f'1445/06/{(i % 28) + 1:02d}',
                case_type=Lawsuit.CASE_TYPE_CIVIL,
                court='محكمة',
                subject=f'دعوى جماعية {i}',
                facts='وقائع',
                reasons='أسباب',
                requests='طلبات',
                created_by=self.lawyer_user
            )
            lawsuits_bulk.append(lawsuit)
        
        Lawsuit.objects.bulk_create(lawsuits_bulk, batch_size=50)
        
        end_time = time.time()
        time_bulk = end_time - start_time
        query_count_bulk = len(connection.queries)
        
        print(f"Execution Time: {time_bulk:.4f} seconds")
        print(f"Database Queries: {query_count_bulk}")
        
        improvement = ((time_individual - time_bulk) / time_individual) * 100 if time_individual > 0 else 0
        query_reduction = query_count_individual - query_count_bulk
        
        print("\n--- Performance Improvement ---")
        print(f"Time Improvement: {improvement:.1f}%")
        print(f"Query Reduction: {query_reduction} queries")
        print("="*60)
        
        # Verify bulk create worked
        self.assertEqual(Lawsuit.objects.filter(case_number__startswith='BULK-').count(), 100)
        
        print(f"✅ Bulk create test passed: {improvement:.1f}% improvement")

