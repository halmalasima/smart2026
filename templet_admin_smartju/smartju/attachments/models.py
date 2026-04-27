from django.db import models
from lawsuits.models import Lawsuit
from smartju.validators import validate_file_size, validate_file_extension
import os


def attachment_upload_path(instance, filename):
    """
    Generate upload path for attachment files
    Format: attachments/lawsuit_{lawsuit_id}/{filename}
    """
    # Get file extension
    ext = filename.split('.')[-1]
    # Generate filename with timestamp to avoid conflicts
    from django.utils import timezone
    timestamp = timezone.now().strftime('%Y%m%d_%H%M%S')
    filename = f"{timestamp}_{instance.document_type}.{ext}"
    return os.path.join('attachments', f'lawsuit_{instance.lawsuit.id}', filename)


class Attachment(models.Model):
    """
    Attachment Model - represents documents attached to a lawsuit
    """
    
    # Document type choices
    DOC_TYPE_IDENTITY = 'identity'
    DOC_TYPE_CONTRACT = 'contract'
    DOC_TYPE_CERTIFICATE = 'certificate'
    DOC_TYPE_EVIDENCE = 'evidence'
    DOC_TYPE_STATEMENT = 'statement'
    DOC_TYPE_RECEIPT = 'receipt'
    DOC_TYPE_OTHER = 'other'
    
    DOC_TYPE_CHOICES = [
        (DOC_TYPE_IDENTITY, 'هوية/جواز سفر'),
        (DOC_TYPE_CONTRACT, 'عقد'),
        (DOC_TYPE_CERTIFICATE, 'شهادة'),
        (DOC_TYPE_EVIDENCE, 'دليل'),
        (DOC_TYPE_STATEMENT, 'بيان'),
        (DOC_TYPE_RECEIPT, 'إيصال'),
        (DOC_TYPE_OTHER, 'أخرى'),
    ]
    
    # ForeignKey to Lawsuit
    lawsuit = models.ForeignKey(
        Lawsuit,
        on_delete=models.CASCADE,
        related_name='attachments',
        verbose_name='الدعوى'
    )
    
    # Document type
    document_type = models.CharField(
        max_length=50,
        choices=DOC_TYPE_CHOICES,
        default=DOC_TYPE_OTHER,
        verbose_name='نوع المستند'
    )
    
    # Dates
    gregorian_date = models.DateField(
        blank=True,
        null=True,
        verbose_name='التاريخ الميلادي'
    )
    
    hijri_date = models.CharField(
        max_length=50,
        blank=True,
        default='',
        verbose_name='التاريخ الهجري'
    )
    
    # Number of pages
    page_count = models.PositiveIntegerField(
        default=1,
        verbose_name='عدد الصفحات'
    )
    
    # Document content/description
    content = models.TextField(
        blank=True,
        default='',
        verbose_name='مضمون المستند'
    )
    
    # Evidence basis/purpose
    evidence_basis = models.TextField(
        blank=True,
        default='',
        verbose_name='وجه الاستدلال'
    )
    
    # File attachment
    file = models.FileField(
        upload_to=attachment_upload_path,
        blank=True,
        null=True,
        verbose_name='الملف المرفق',
        validators=[validate_file_size, validate_file_extension],
    )
    
    # File name (stored separately for reference)
    original_filename = models.CharField(
        max_length=255,
        blank=True,
        verbose_name='اسم الملف الأصلي'
    )
    
    # File size in bytes
    file_size = models.PositiveIntegerField(
        blank=True,
        null=True,
        verbose_name='حجم الملف (بايت)'
    )
    
    # Timestamps
    created_at = models.DateTimeField(
        auto_now_add=True,
        verbose_name='تاريخ الإنشاء'
    )
    
    updated_at = models.DateTimeField(
        auto_now=True,
        verbose_name='تاريخ التحديث'
    )
    
    class Meta:
        verbose_name = 'مرفق'
        verbose_name_plural = 'مرفقات'
        ordering = ['-created_at']
        indexes = [
            models.Index(fields=['lawsuit']),
            models.Index(fields=['document_type']),
            models.Index(fields=['gregorian_date']),
        ]
    
    def __str__(self):
        return f'{self.get_document_type_display()} - {self.lawsuit.case_number}'
    
    def save(self, *args, **kwargs):
        """
        Override save to store original filename and file size
        """
        # Store original filename if file is being uploaded
        if self.file and hasattr(self.file, 'name'):
            # Get the original filename from the uploaded file
            if hasattr(self.file, 'original_name'):
                # If using InMemoryUploadedFile or similar
                self.original_filename = self.file.original_name
            else:
                # Extract just the filename from the path
                self.original_filename = os.path.basename(self.file.name)
        
        # Store file size
        if self.file:
            try:
                if hasattr(self.file, 'size'):
                    self.file_size = self.file.size
                elif hasattr(self.file, 'file') and hasattr(self.file.file, 'size'):
                    self.file_size = self.file.file.size
            except (ValueError, AttributeError, OSError):
                pass
        
        super().save(*args, **kwargs)
    
    def get_file_size_display(self):
        """
        Return human-readable file size
        """
        if not self.file_size:
            return '-'
        
        size = float(self.file_size)
        for unit in ['B', 'KB', 'MB', 'GB']:
            if size < 1024.0:
                return f'{size:.1f} {unit}'
            size /= 1024.0
        return f'{size:.1f} TB'
