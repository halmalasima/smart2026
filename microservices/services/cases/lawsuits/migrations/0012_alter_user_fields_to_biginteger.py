# Generated manually to change user ForeignKey fields to BigIntegerField

from django.db import migrations, models


class Migration(migrations.Migration):

    dependencies = [
        ('lawsuits', '0011_alter_casefileitem_file'),
    ]

    operations = [
        migrations.AlterField(
            model_name='case',
            name='client',
            field=models.BigIntegerField(blank=True, null=True, verbose_name='الموكل'),
        ),
        migrations.AlterField(
            model_name='case',
            name='created_by',
            field=models.BigIntegerField(blank=True, null=True, verbose_name='أنشأ بواسطة'),
        ),
        migrations.AlterField(
            model_name='casefileitem',
            name='created_by',
            field=models.BigIntegerField(blank=True, null=True, verbose_name='أنشأ بواسطة'),
        ),
        migrations.AlterField(
            model_name='lawsuit',
            name='archived_by',
            field=models.BigIntegerField(blank=True, null=True, verbose_name='أرشف بواسطة'),
        ),
        migrations.AlterField(
            model_name='lawsuit',
            name='client',
            field=models.BigIntegerField(blank=True, null=True, verbose_name='الموكل'),
        ),
        migrations.AlterField(
            model_name='lawsuit',
            name='created_by',
            field=models.BigIntegerField(blank=True, null=True, verbose_name='منشئ الدعوى'),
        ),
    ]
