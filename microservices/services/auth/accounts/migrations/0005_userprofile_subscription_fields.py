from django.db import migrations, models


class Migration(migrations.Migration):

    dependencies = [
        ('accounts', '0004_userprofile_supervisor_alter_userprofile_role'),
    ]

    operations = [
        migrations.AddField(
            model_name='userprofile',
            name='subscription_plan',
            field=models.CharField(
                choices=[('free', 'مجاني'), ('starter', 'مبتدئ'), ('professional', 'احترافي'), ('enterprise', 'مؤسسي')],
                default='free',
                max_length=50,
                verbose_name='باقة الاشتراك',
            ),
        ),
        migrations.AddField(
            model_name='userprofile',
            name='is_trial',
            field=models.BooleanField(default=True, verbose_name='فترة تجريبية'),
        ),
        migrations.AddField(
            model_name='userprofile',
            name='subscription_expiry',
            field=models.DateTimeField(blank=True, null=True, verbose_name='انتهاء الاشتراك'),
        ),
    ]
