"""Add case_type, case_subtype to Case model; add CaseParty model."""

from django.conf import settings
from django.db import migrations, models
import django.db.models.deletion


class Migration(migrations.Migration):

    dependencies = [
        migrations.swappable_dependency(settings.AUTH_USER_MODEL),
        ('lawsuits', '0009_alter_case_subject_and_more'),
    ]

    operations = [
        migrations.AddField(
            model_name='case',
            name='case_type',
            field=models.CharField(
                choices=[
                    ('مدنية', 'مدنية'),
                    ('جزائية', 'جزائية'),
                    ('شخصية', 'شخصية'),
                    ('إدارية', 'إدارية'),
                    ('تجارية', 'تجارية'),
                    ('تنفيذ', 'تنفيذ'),
                ],
                default='مدنية',
                max_length=50,
                verbose_name='نوع القضية',
            ),
        ),
        migrations.AddField(
            model_name='case',
            name='case_subtype',
            field=models.CharField(
                blank=True,
                max_length=100,
                null=True,
                verbose_name='النوع الفرعي',
            ),
        ),
        migrations.CreateModel(
            name='CaseParty',
            fields=[
                ('id', models.BigAutoField(auto_created=True, primary_key=True, serialize=False, verbose_name='ID')),
                ('role', models.CharField(choices=[('client', 'موكل (طرف أول)'), ('opponent', 'خصم (طرف ثاني)')], max_length=20, verbose_name='الدور')),
                ('entity_type', models.CharField(choices=[('person', 'شخص'), ('organization', 'مؤسسة / شركة')], default='person', max_length=20, verbose_name='نوع الطرف')),
                ('name', models.CharField(max_length=200, verbose_name='الاسم')),
                ('phone', models.CharField(blank=True, max_length=20, null=True, verbose_name='الهاتف')),
                ('id_number', models.CharField(blank=True, max_length=50, null=True, verbose_name='رقم الهوية / السجل')),
                ('id_issued_from', models.CharField(blank=True, max_length=100, null=True, verbose_name='جهة الإصدار')),
                ('id_date', models.DateField(blank=True, null=True, verbose_name='تاريخ الإصدار')),
                ('address', models.TextField(blank=True, null=True, verbose_name='العنوان')),
                ('nationality', models.CharField(blank=True, max_length=100, null=True, verbose_name='الجنسية')),
                ('created_at', models.DateTimeField(auto_now_add=True, verbose_name='تاريخ الإنشاء')),
                ('updated_at', models.DateTimeField(auto_now=True, verbose_name='تاريخ التحديث')),
                ('case', models.ForeignKey(on_delete=django.db.models.deletion.CASCADE, related_name='parties', to='lawsuits.case', verbose_name='القضية')),
                ('user_account', models.ForeignKey(blank=True, null=True, on_delete=django.db.models.deletion.SET_NULL, related_name='case_party_account', to=settings.AUTH_USER_MODEL, verbose_name='حساب المستخدم')),
            ],
            options={
                'verbose_name': 'طرف القضية',
                'verbose_name_plural': 'أطراف القضية',
                'ordering': ['role', 'name'],
            },
        ),
    ]
