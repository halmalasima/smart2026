"""
Performance Optimization Suggestions and Analysis
"""
from django.test import TestCase
from django.db import connection, reset_queries
from django.contrib.auth.models import User
from datetime import date, timedelta
from lawsuits.models import Lawsuit
from parties.models import Plaintiff, Defendant
from attachments.models import Attachment
from responses.models import Response
from appeals.models import Appeal
from judgments.models import Judgment
from accounts.models import UserProfile


class PerformanceOptimizationAnalysis(TestCase):
    """
    Analyze current query patterns and suggest optimizations
    """
    
    def setUp(self):
        """Set up test data"""
        self.user = User.objects.create_user(
            username='testuser',
            email='test@example.com',
            password='testpass123'
        )
        self.user.profile.role = UserProfile.ROLE_LAWYER
        self.user.profile.save()
        
        # Create lawsuit with related data
        self.lawsuit = Lawsuit.objects.create(
            case_number='OPT-001/2024',
            gregorian_date=date(2024, 1, 15),
            hijri_date='1445/06/03',
            case_type=Lawsuit.CASE_TYPE_CIVIL,
            court='محكمة',
            subject='دعوى تحسين',
            facts='وقائع',
            reasons='أسباب',
            requests='طلبات',
            created_by=self.user
        )
        
        # Add related data
        Plaintiff.objects.create(
            lawsuit=self.lawsuit,
            name='مدعي',
            gender=Plaintiff.GENDER_MALE,
            nationality='يمني',
            address='صنعاء'
        )
        
        Defendant.objects.create(
            lawsuit=self.lawsuit,
            name='مدعى عليه',
            gender=Defendant.GENDER_MALE,
            nationality='يمني',
            address='عدن'
        )
    
    def test_analyze_lawsuit_list_queries(self):
        """
        Analyze queries when fetching lawsuit list
        """
        print("\n" + "="*60)
        print("Query Analysis: Lawsuit List")
        print("="*60)
        
        # Create multiple lawsuits
        for i in range(10):
            Lawsuit.objects.create(
                case_number=f'OPT-{i:03d}/2024',
                gregorian_date=date(2024, 1, 15) + timedelta(days=i),
                hijri_date='1445/06/03',
                case_type=Lawsuit.CASE_TYPE_CIVIL,
                court='محكمة',
                subject=f'دعوى {i}',
                facts='وقائع',
                reasons='أسباب',
                requests='طلبات',
                created_by=self.user
            )
        
        # Test current implementation (without optimization)
        reset_queries()
        lawsuits = list(Lawsuit.objects.all())
        
        # Access related data (simulates what serializer might do)
        for lawsuit in lawsuits:
            _ = lawsuit.created_by  # ForeignKey access
        
        query_count = len(connection.queries)
        print(f"\nCurrent Implementation:")
        print(f"Total Queries: {query_count}")
        print(f"Queries per Lawsuit: {query_count / len(lawsuits):.2f}")
        
        # Test optimized version
        reset_queries()
        lawsuits_opt = list(Lawsuit.objects.select_related('created_by').all())
        
        for lawsuit in lawsuits_opt:
            _ = lawsuit.created_by  # No additional query
        
        query_count_opt = len(connection.queries)
        print(f"\nOptimized Implementation (select_related):")
        print(f"Total Queries: {query_count_opt}")
        print(f"Queries per Lawsuit: {query_count_opt / len(lawsuits_opt):.2f}")
        print(f"Query Reduction: {query_count - query_count_opt} queries")
        print("="*60)
        
        # Recommendation
        print("\n✅ RECOMMENDATION: Use select_related('created_by') in LawsuitViewSet.queryset")
        print("   This reduces N+1 queries when accessing created_by user")
    
    def test_analyze_lawsuit_detail_with_relations_queries(self):
        """
        Analyze queries when fetching lawsuit detail with all relations
        """
        print("\n" + "="*60)
        print("Query Analysis: Lawsuit Detail with Relations")
        print("="*60)
        
        # Test current implementation
        reset_queries()
        lawsuit = Lawsuit.objects.get(id=self.lawsuit.id)
        plaintiffs = list(lawsuit.plaintiffs.all())
        defendants = list(lawsuit.defendants.all())
        attachments = list(lawsuit.attachments.all())
        responses = list(lawsuit.responses.all())
        appeals = list(lawsuit.appeals.all())
        judgments = list(lawsuit.judgments.all())
        created_by_user = lawsuit.created_by
        
        query_count = len(connection.queries)
        print(f"\nCurrent Implementation:")
        print(f"Total Queries: {query_count}")
        print("  - 1 query for lawsuit")
        print("  - 1 query for plaintiffs")
        print("  - 1 query for defendants")
        print("  - 1 query for attachments")
        print("  - 1 query for responses")
        print("  - 1 query for appeals")
        print("  - 1 query for judgments")
        print("  - 1 query for created_by")
        
        # Test optimized version
        reset_queries()
        lawsuit_opt = Lawsuit.objects.select_related('created_by').prefetch_related(
            'plaintiffs', 'defendants', 'attachments', 'responses', 'appeals', 'judgments'
        ).get(id=self.lawsuit.id)
        
        plaintiffs_opt = list(lawsuit_opt.plaintiffs.all())
        defendants_opt = list(lawsuit_opt.defendants.all())
        attachments_opt = list(lawsuit_opt.attachments.all())
        responses_opt = list(lawsuit_opt.responses.all())
        appeals_opt = list(lawsuit_opt.appeals.all())
        judgments_opt = list(lawsuit_opt.judgments.all())
        created_by_user_opt = lawsuit_opt.created_by
        
        query_count_opt = len(connection.queries)
        print(f"\nOptimized Implementation:")
        print(f"Total Queries: {query_count_opt}")
        print(f"Query Reduction: {query_count - query_count_opt} queries")
        print("="*60)
        
        # Recommendation
        print("\n✅ RECOMMENDATION: Use prefetch_related for reverse ForeignKey relations")
        print("   - prefetch_related('plaintiffs', 'defendants', 'attachments', ...)")
        print("   - select_related('created_by') for ForeignKey")
    
    def generate_optimization_report(self):
        """
        Generate optimization suggestions report
        """
        print("\n" + "="*60)
        print("PERFORMANCE OPTIMIZATION RECOMMENDATIONS")
        print("="*60)
        
        recommendations = [
            {
                'viewset': 'LawsuitViewSet',
                'current': 'queryset = Lawsuit.objects.select_related("created_by").all()',
                'suggestion': 'Already uses select_related for created_by. Good!',
                'priority': 'Low'
            },
            {
                'viewset': 'LawsuitViewSet (detail with relations)',
                'current': 'Serializers access related objects directly',
                'suggestion': 'Consider using prefetch_related in detail view or custom action',
                'priority': 'Medium'
            },
            {
                'viewset': 'PlaintiffViewSet / DefendantViewSet',
                'current': 'queryset = Plaintiff.objects.select_related("lawsuit").all()',
                'suggestion': 'Already uses select_related for lawsuit. Good!',
                'priority': 'Low'
            },
            {
                'viewset': 'JudgmentViewSet',
                'current': 'May access lawsuit and judge',
                'suggestion': 'Use select_related("lawsuit", "judge", "created_by")',
                'priority': 'Medium'
            },
            {
                'viewset': 'HearingViewSet',
                'current': 'May access lawsuit and judge',
                'suggestion': 'Use select_related("lawsuit", "judge", "created_by")',
                'priority': 'Medium'
            },
            {
                'viewset': 'ResponseViewSet',
                'current': 'May access lawsuit and submitted_by_user',
                'suggestion': 'Use select_related("lawsuit", "submitted_by_user")',
                'priority': 'Medium'
            },
            {
                'viewset': 'AppealViewSet',
                'current': 'May access lawsuit and submitted_by_user',
                'suggestion': 'Use select_related("lawsuit", "submitted_by_user")',
                'priority': 'Medium'
            },
        ]
        
        print("\nDetailed Recommendations:")
        for i, rec in enumerate(recommendations, 1):
            print(f"\n{i}. {rec['viewset']}")
            print(f"   Priority: {rec['priority']}")
            print(f"   Suggestion: {rec['suggestion']}")
        
        print("\n" + "="*60)
        print("GENERAL RECOMMENDATIONS:")
        print("="*60)
        print("""
1. Use select_related() for ForeignKey and OneToOneField relationships
   - Example: .select_related('created_by', 'judge')

2. Use prefetch_related() for reverse ForeignKey and ManyToMany relationships
   - Example: .prefetch_related('plaintiffs', 'defendants', 'attachments')

3. Use only() and defer() to limit fields when fetching large datasets
   - Example: .only('id', 'case_number', 'subject')

4. Use database indexes (already implemented in models)

5. Consider pagination for large result sets (already implemented)

6. Use bulk_create() for creating multiple objects (faster than individual creates)

7. Monitor query count in development using django-debug-toolbar

8. Use connection.queries in tests to analyze query patterns
        """)
        
        return recommendations

