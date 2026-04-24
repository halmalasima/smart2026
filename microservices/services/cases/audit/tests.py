from django.test import TestCase
from django.contrib.auth.models import User
from lawsuits.models import Lawsuit
from parties.models import Plaintiff, Defendant
from attachments.models import Attachment
from responses.models import Response
from appeals.models import Appeal
from judgments.models import Judgment
from hearings.models import Hearing
from datetime import date
from django.core.files.uploadedfile import SimpleUploadedFile
from .models import AuditLog


class AuditLogModelTest(TestCase):
    """
    Test cases for AuditLog model
    """
    
    def setUp(self):
        """Set up test data"""
        self.user = User.objects.create_user(
            username='testuser',
            email='test@example.com',
            password='testpass123'
        )
        self.lawsuit = Lawsuit.objects.create(
            case_number='800/2024',
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
    
    def test_audit_log_lawsuit_created(self):
        """Test that audit log is created when lawsuit is created"""
        # Audit log should be created automatically via signal
        audit_logs = AuditLog.objects.filter(
            action_type=AuditLog.ACTION_LAWSUIT_CREATED,
            lawsuit=self.lawsuit
        )
        self.assertEqual(audit_logs.count(), 1)
        audit_log = audit_logs.first()
        self.assertEqual(audit_log.user, self.user)
        self.assertEqual(audit_log.lawsuit, self.lawsuit)
    
    def test_audit_log_plaintiff_added(self):
        """Test that audit log is created when plaintiff is added"""
        plaintiff = Plaintiff.objects.create(
            lawsuit=self.lawsuit,
            name='أحمد محمد',
            gender=Plaintiff.GENDER_MALE,
            nationality='يمني',
            address='صنعاء'
        )
        
        audit_logs = AuditLog.objects.filter(
            action_type=AuditLog.ACTION_PARTY_ADDED,
            lawsuit=self.lawsuit
        )
        self.assertGreaterEqual(audit_logs.count(), 1)
    
    def test_audit_log_defendant_added(self):
        """Test that audit log is created when defendant is added"""
        defendant = Defendant.objects.create(
            lawsuit=self.lawsuit,
            name='خالد سعيد',
            gender=Defendant.GENDER_MALE,
            nationality='يمني',
            address='عدن'
        )
        
        audit_logs = AuditLog.objects.filter(
            action_type=AuditLog.ACTION_PARTY_ADDED,
            lawsuit=self.lawsuit
        )
        self.assertGreaterEqual(audit_logs.count(), 1)
    
    def test_audit_log_attachment_uploaded(self):
        """Test that audit log is created when attachment is uploaded"""
        test_file = SimpleUploadedFile(
            "test.pdf",
            b"content",
            content_type="application/pdf"
        )
        attachment = Attachment.objects.create(
            lawsuit=self.lawsuit,
            document_type=Attachment.DOC_TYPE_CERTIFICATE,
            gregorian_date=date(2024, 1, 10),
            hijri_date='1445/05/28',
            page_count=3,
            content='مضمون',
            evidence_basis='وجه',
            file=test_file
        )
        
        audit_logs = AuditLog.objects.filter(
            action_type=AuditLog.ACTION_ATTACHMENT_UPLOADED,
            lawsuit=self.lawsuit
        )
        self.assertEqual(audit_logs.count(), 1)
    
    def test_audit_log_response_submitted(self):
        """Test that audit log is created when response is submitted"""
        response = Response.objects.create(
            lawsuit=self.lawsuit,
            response_text='نص الرد',
            submitted_by='محمد أحمد',
            submission_date=date(2024, 1, 20),
            hijri_date='1445/06/08',
            response_type=Response.RESPONSE_TYPE_REPLY,
            submitted_by_user=self.user
        )
        
        audit_logs = AuditLog.objects.filter(
            action_type=AuditLog.ACTION_RESPONSE_SUBMITTED,
            lawsuit=self.lawsuit
        )
        self.assertEqual(audit_logs.count(), 1)
    
    def test_audit_log_appeal_filed(self):
        """Test that audit log is created when appeal is filed"""
        appeal = Appeal.objects.create(
            lawsuit=self.lawsuit,
            appeal_type=Appeal.APPEAL_TYPE_APPEAL,
            appeal_number='AP-001/2024',
            appeal_reasons='أسباب',
            appeal_requests='طلبات',
            higher_court='محكمة التمييز',
            appeal_date=date(2024, 2, 1),
            hijri_date='1445/07/20',
            submitted_by='محمد',
            submitted_by_user=self.user
        )
        
        audit_logs = AuditLog.objects.filter(
            action_type=AuditLog.ACTION_APPEAL_FILED,
            lawsuit=self.lawsuit
        )
        self.assertEqual(audit_logs.count(), 1)
    
    def test_audit_log_judgment_issued(self):
        """Test that audit log is created when judgment is issued"""
        judgment = Judgment.objects.create(
            lawsuit=self.lawsuit,
            judgment_type=Judgment.JUDGMENT_TYPE_PRIMARY,
            judgment_number='J-001/2024',
            judgment_date=date(2024, 4, 1),
            hijri_date='1445/09/21',
            judgment_text='نص الحكم',
            judge_name='القاضي محمد',
            judge=self.user,
            court_name='محكمة',
            created_by=self.user
        )
        
        audit_logs = AuditLog.objects.filter(
            action_type=AuditLog.ACTION_JUDGMENT_ISSUED,
            lawsuit=self.lawsuit
        )
        self.assertEqual(audit_logs.count(), 1)
    
    def test_audit_log_hearing_scheduled(self):
        """Test that audit log is created when hearing is scheduled"""
        hearing = Hearing.objects.create(
            lawsuit=self.lawsuit,
            hearing_date=date(2024, 3, 1),
            hijri_date='1445/08/19',
            notes='ملاحظات',
            hearing_type=Hearing.HEARING_TYPE_MAIN,
            created_by=self.user
        )
        
        audit_logs = AuditLog.objects.filter(
            action_type=AuditLog.ACTION_HEARING_SCHEDULED,
            lawsuit=self.lawsuit
        )
        self.assertEqual(audit_logs.count(), 1)
    
    def test_audit_log_cannot_be_updated(self):
        """Test that audit log cannot be updated"""
        audit_log = AuditLog.objects.create(
            action_type=AuditLog.ACTION_OTHER,
            lawsuit=self.lawsuit,
            description='وصف',
            user=self.user
        )
        
        audit_log.description = 'وصف معدل'
        with self.assertRaises(ValueError):
            audit_log.save()
    
    def test_audit_log_cannot_be_deleted(self):
        """Test that audit log cannot be deleted"""
        audit_log = AuditLog.objects.create(
            action_type=AuditLog.ACTION_OTHER,
            lawsuit=self.lawsuit,
            description='وصف',
            user=self.user
        )
        
        with self.assertRaises(ValueError):
            audit_log.delete()
    
    def test_audit_log_cascade_delete(self):
        """Test that audit log is deleted when lawsuit is deleted"""
        audit_log = AuditLog.objects.create(
            action_type=AuditLog.ACTION_OTHER,
            lawsuit=self.lawsuit,
            description='وصف',
            user=self.user
        )
        audit_log_id = audit_log.id
        
        self.lawsuit.delete()
        
        self.assertFalse(AuditLog.objects.filter(id=audit_log_id).exists())
