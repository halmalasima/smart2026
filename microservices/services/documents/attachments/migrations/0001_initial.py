# Rewritten for documents-service (standalone microservice).
# lawsuit_id is a plain BigIntegerField — no cross-service FK.

import attachments.models
from django.db import migrations, models


class Migration(migrations.Migration):

    initial = True

    dependencies = []

    operations = [
        migrations.CreateModel(
            name='Attachment',
            fields=[
                ('id', models.BigAutoField(auto_created=True, primary_key=True, serialize=False, verbose_name='ID')),
                ('lawsuit_id', models.BigIntegerField(db_index=True, verbose_name='رقم معرف الدعوى')),
                ('lawsuit_case_number', models.CharField(blank=True, default='', max_length=100, verbose_name='رقم ملف القضية')),
                ('document_type', models.CharField(
                    choices=[('identity', 'هوية/جواز سفر'), ('contract', 'عقد'), ('certificate', 'شهادة'),
                             ('evidence', 'دليل'), ('statement', 'بيان'), ('receipt', 'إيصال'), ('other', 'أخرى')],
                    default='other', max_length=50, verbose_name='نوع المستند',
                )),
                ('gregorian_date', models.DateField(blank=True, null=True, verbose_name='التاريخ الميلادي')),
                ('hijri_date', models.CharField(blank=True, default='', max_length=50, verbose_name='التاريخ الهجري')),
                ('page_count', models.PositiveIntegerField(default=1, verbose_name='عدد الصفحات')),
                ('content', models.TextField(blank=True, default='', verbose_name='مضمون المستند')),
                ('evidence_basis', models.TextField(blank=True, default='', verbose_name='وجه الاستدلال')),
                ('file', models.FileField(blank=True, null=True, upload_to=attachments.models.attachment_upload_path, verbose_name='الملف المرفق')),
                ('original_filename', models.CharField(blank=True, max_length=255, verbose_name='اسم الملف الأصلي')),
                ('file_size', models.PositiveIntegerField(blank=True, null=True, verbose_name='حجم الملف (بايت)')),
                ('created_at', models.DateTimeField(auto_now_add=True, verbose_name='تاريخ الإنشاء')),
                ('updated_at', models.DateTimeField(auto_now=True, verbose_name='تاريخ التحديث')),
            ],
            options={
                'verbose_name': 'مرفق',
                'verbose_name_plural': 'مرفقات',
                'ordering': ['-created_at'],
                'indexes': [
                    models.Index(fields=['lawsuit_id'], name='attachments_lawsuit_id_idx'),
                    models.Index(fields=['document_type'], name='attachments_doc_type_idx'),
                    models.Index(fields=['gregorian_date'], name='attachments_greg_date_idx'),
                ],
            },
        ),
    ]
