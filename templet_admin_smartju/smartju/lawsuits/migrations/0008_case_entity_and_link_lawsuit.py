from django.conf import settings
from django.db import migrations, models
import django.db.models.deletion


def forwards_create_cases(apps, schema_editor):
    Case = apps.get_model('lawsuits', 'Case')
    Lawsuit = apps.get_model('lawsuits', 'Lawsuit')

    # Create a Case for each existing Lawsuit and link it.
    # This preserves existing data while introducing the new Case entity.
    for lawsuit in Lawsuit.objects.all().iterator():
        if getattr(lawsuit, 'case_id', None):
            continue

        case = Case.objects.create(
            case_number=lawsuit.case_number,
            filing_date=lawsuit.filing_date,
            gregorian_date=lawsuit.gregorian_date,
            hijri_date=lawsuit.hijri_date,
            case_year_hijri=lawsuit.case_year_hijri,
            case_status=lawsuit.case_status,
            governorate=lawsuit.governorate,
            court_fk_id=lawsuit.court_fk_id,
            court=lawsuit.court,
            subject=lawsuit.subject,
            description=lawsuit.description,
            created_by_id=lawsuit.created_by_id,
            client_id=lawsuit.client_id,
            created_at=lawsuit.created_at,
            updated_at=lawsuit.updated_at,
        )

        lawsuit.case_id = case.id
        lawsuit.save(update_fields=['case'])


def backwards_delete_cases(apps, schema_editor):
    Case = apps.get_model('lawsuits', 'Case')
    Lawsuit = apps.get_model('lawsuits', 'Lawsuit')

    # Unlink lawsuits then delete cases.
    Lawsuit.objects.update(case=None)
    Case.objects.all().delete()


class Migration(migrations.Migration):

    dependencies = [
        ('courts', '0001_initial'),
        ('lawsuits', '0007_lawsuit_case_subtype_lawsuit_case_year_hijri'),
    ]

    operations = [
        migrations.CreateModel(
            name='Case',
            fields=[
                ('id', models.BigAutoField(auto_created=True, primary_key=True, serialize=False, verbose_name='ID')),
                ('case_number', models.CharField(db_index=True, max_length=100, unique=True, verbose_name='رقم القضية')),
                ('filing_date', models.DateField(blank=True, null=True, verbose_name='تاريخ الورود')),
                ('gregorian_date', models.DateField(blank=True, null=True, verbose_name='التاريخ الميلادي')),
                ('hijri_date', models.CharField(blank=True, max_length=50, null=True, verbose_name='التاريخ الهجري')),
                ('case_year_hijri', models.PositiveSmallIntegerField(blank=True, null=True, verbose_name='سنة القضية (هجري)')),
                ('case_status', models.CharField(choices=[('جديد', 'جديد'), ('قيد_النظر', 'قيد النظر'), ('مكتمل', 'مكتمل'), ('مغلق', 'مغلق')], default='جديد', max_length=50, verbose_name='حالة القضية')),
                ('governorate', models.CharField(blank=True, max_length=50, null=True, verbose_name='المحافظة')),
                ('court', models.CharField(blank=True, max_length=200, null=True, verbose_name='المحكمة (نص)')),
                ('subject', models.CharField(max_length=150, verbose_name='موضوع القضية')),
                ('description', models.TextField(blank=True, null=True, verbose_name='الوصف')),
                ('created_at', models.DateTimeField(auto_now_add=True, verbose_name='تاريخ الإنشاء')),
                ('updated_at', models.DateTimeField(auto_now=True, verbose_name='تاريخ التحديث')),
                ('client', models.ForeignKey(blank=True, null=True, on_delete=django.db.models.deletion.SET_NULL, related_name='client_cases', to=settings.AUTH_USER_MODEL, verbose_name='الموكل')),
                ('court_fk', models.ForeignKey(blank=True, null=True, on_delete=django.db.models.deletion.SET_NULL, related_name='cases', to='courts.court', verbose_name='المحكمة')),
                ('created_by', models.ForeignKey(blank=True, null=True, on_delete=django.db.models.deletion.SET_NULL, related_name='created_cases', to=settings.AUTH_USER_MODEL, verbose_name='أنشأ بواسطة')),
            ],
            options={
                'verbose_name': 'قضية',
                'verbose_name_plural': 'قضايا',
                'ordering': ['-created_at'],
            },
        ),
        migrations.AddField(
            model_name='lawsuit',
            name='case',
            field=models.ForeignKey(blank=True, null=True, on_delete=django.db.models.deletion.SET_NULL, related_name='lawsuits', to='lawsuits.case', verbose_name='القضية'),
        ),
        migrations.RunPython(forwards_create_cases, backwards_delete_cases),
    ]
