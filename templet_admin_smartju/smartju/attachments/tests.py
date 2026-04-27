from django.test import TestCase
from django.core.files.uploadedfile import SimpleUploadedFile
from django.contrib.auth.models import User
from lawsuits.models import Lawsuit
from datetime import date
from .models import Attachment


class AttachmentModelTest(TestCase):
    """
    Test cases for Attachment model
    """
    
    def setUp(self):
        """Set up test data"""
        self.user = User.objects.create_user(
            username='lawyer1',
            email='lawyer@example.com',
            password='testpass123'
        )
        self.lawsuit = Lawsuit.objects.create(
            case_number='300/2024',
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
    
    def test_create_attachment(self):
        """Test creating an attachment"""
        test_file = SimpleUploadedFile(
            "test_document.pdf",
            b"file_content",
            content_type="application/pdf"
        )
        
        attachment = Attachment.objects.create(
            lawsuit=self.lawsuit,
            document_type=Attachment.DOC_TYPE_CONTRACT,
            gregorian_date=date(2024, 1, 10),
            hijri_date='1445/05/28',
            page_count=5,
            content='مضمون المستند...',
            evidence_basis='وجه الاستدلال...',
            file=test_file
        )
        
        self.assertIsNotNone(attachment.id)
        self.assertEqual(attachment.lawsuit, self.lawsuit)
        self.assertEqual(attachment.document_type, Attachment.DOC_TYPE_CONTRACT)
        self.assertEqual(attachment.page_count, 5)
        self.assertTrue(attachment.file.name)
    
    def test_attachment_cascade_delete(self):
        """Test that attachment is deleted when lawsuit is deleted"""
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
        attachment_id = attachment.id
        
        self.lawsuit.delete()
        
        self.assertFalse(Attachment.objects.filter(id=attachment_id).exists())
    
    def test_attachment_document_type_choices(self):
        """Test Attachment document type choices"""
        test_file = SimpleUploadedFile(
            "test.pdf",
            b"content",
            content_type="application/pdf"
        )
        attachment = Attachment.objects.create(
            lawsuit=self.lawsuit,
            document_type=Attachment.DOC_TYPE_IDENTITY,
            gregorian_date=date(2024, 1, 10),
            hijri_date='1445/05/28',
            page_count=1,
            content='مضمون',
            evidence_basis='وجه',
            file=test_file
        )
        self.assertEqual(attachment.get_document_type_display(), 'هوية/جواز سفر')
    
    def test_attachment_str(self):
        """Test Attachment string representation"""
        test_file = SimpleUploadedFile(
            "test.pdf",
            b"content",
            content_type="application/pdf"
        )
        attachment = Attachment.objects.create(
            lawsuit=self.lawsuit,
            document_type=Attachment.DOC_TYPE_EVIDENCE,
            gregorian_date=date(2024, 1, 10),
            hijri_date='1445/05/28',
            page_count=10,
            content='مضمون',
            evidence_basis='وجه',
            file=test_file
        )
        expected_str = f'{attachment.get_document_type_display()} - {self.lawsuit.case_number}'
        self.assertEqual(str(attachment), expected_str)
    
    def test_attachment_file_size_display(self):
        """Test Attachment file_size_display method"""
        test_file = SimpleUploadedFile(
            "test.pdf",
            b"x" * 1024,  # 1KB
            content_type="application/pdf"
        )
        attachment = Attachment.objects.create(
            lawsuit=self.lawsuit,
            document_type=Attachment.DOC_TYPE_OTHER,
            gregorian_date=date(2024, 1, 10),
            hijri_date='1445/05/28',
            page_count=1,
            content='مضمون',
            evidence_basis='وجه',
            file=test_file
        )
        # File size should be stored
        self.assertIsNotNone(attachment.file_size)
        # Display method should return readable format
        size_display = attachment.get_file_size_display()
        self.assertIsInstance(size_display, str)
