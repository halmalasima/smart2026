# Rewritten for hearings-service (standalone microservice).
# lawsuit_id is a plain BigIntegerField — no cross-service FK.

import django.db.models.deletion
from django.conf import settings
from django.db import migrations, models


class Migration(migrations.Migration):

    initial = True

    dependencies = [
        migrations.swappable_dependency(settings.AUTH_USER_MODEL),
    ]

    operations = [
        migrations.CreateModel(
            name='Hearing',
            fields=[
                ('id', models.BigAutoField(auto_created=True, primary_key=True, serialize=False, verbose_name='ID')),
                ('lawsuit_id', models.BigIntegerField(db_index=True, verbose_name='رقم معرف الدعوى')),
                ('lawsuit_case_number', models.CharField(blank=True, default='', max_length=100, verbose_name='رقم ملف القضية')),
                ('hearing_date', models.DateField(verbose_name='تاريخ الجلسة')),
                ('hijri_date', models.CharField(blank=True, max_length=50, null=True, verbose_name='التاريخ الهجري')),
                ('hearing_time', models.TimeField(blank=True, null=True, verbose_name='وقت الجلسة')),
                ('notes', models.TextField(verbose_name='ملاحظات الجلسة')),
                ('judge_name', models.CharField(blank=True, max_length=200, null=True, verbose_name='اسم القاضي')),
                ('hearing_type', models.CharField(
                    choices=[('preliminary', 'تمهيدية'), ('main', 'رئيسية'), ('decision', 'قرار'), ('adjourned', 'مؤجلة'), ('other', 'أخرى')],
                    default='main', max_length=50, verbose_name='نوع الجلسة',
                )),
                ('archive_status', models.CharField(
                    choices=[('active', 'نشط'), ('semi_active', 'شبه نشط'), ('archived', 'محفوظ')],
                    default='active', max_length=20, verbose_name='حالة الأرشفة',
                )),
                ('archive_date', models.DateTimeField(blank=True, null=True, verbose_name='تاريخ الأرشفة')),
                ('archive_reason', models.TextField(blank=True, null=True, verbose_name='سبب الأرشفة')),
                ('is_deleted', models.BooleanField(default=False, verbose_name='محذوف')),
                ('deleted_at', models.DateTimeField(blank=True, null=True, verbose_name='تاريخ الحذف')),
                ('created_at', models.DateTimeField(auto_now_add=True, verbose_name='تاريخ الإنشاء')),
                ('updated_at', models.DateTimeField(auto_now=True, verbose_name='تاريخ التحديث')),
                ('archived_by', models.ForeignKey(
                    blank=True, null=True, on_delete=django.db.models.deletion.SET_NULL,
                    related_name='archived_hearings', to=settings.AUTH_USER_MODEL, verbose_name='أرشف بواسطة',
                )),
                ('created_by', models.ForeignKey(
                    blank=True, null=True, on_delete=django.db.models.deletion.SET_NULL,
                    related_name='created_hearings', to=settings.AUTH_USER_MODEL, verbose_name='منشئ السجل',
                )),
                ('judge', models.ForeignKey(
                    blank=True, null=True, on_delete=django.db.models.deletion.SET_NULL,
                    related_name='presided_hearings', to=settings.AUTH_USER_MODEL, verbose_name='القاضي',
                )),
            ],
            options={
                'verbose_name': 'جلسة',
                'verbose_name_plural': 'جلسات',
                'ordering': ['-hearing_date', '-hearing_time'],
                'indexes': [
                    models.Index(fields=['lawsuit_id'], name='hearings_lawsuit_id_idx'),
                    models.Index(fields=['hearing_date'], name='hearings_date_idx'),
                    models.Index(fields=['hearing_type'], name='hearings_type_idx'),
                    models.Index(fields=['judge'], name='hearings_judge_idx'),
                    models.Index(fields=['archive_status'], name='hearings_archive_idx'),
                    models.Index(fields=['is_deleted'], name='hearings_deleted_idx'),
                ],
            },
        ),
    ]
