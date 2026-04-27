"""
Management command to seed legal templates from SQL file
"""
from django.core.management.base import BaseCommand
from lawsuits.models import LegalTemplate


class Command(BaseCommand):
    help = 'Add legal templates from SQL file to the database'

    def handle(self, *args, **options):
        self.stdout.write(self.style.SUCCESS('Starting to add legal templates...'))
        
        # Data from SQL file
        templates_data = [
            # أمر أداء
            {
                'case_type': LegalTemplate.CASE_TYPE_PAYMENT_ORDER,
                'section_key': 'facts',
                'section_title': 'الوقائع',
                'default_text': 'أولاً: الوقائع\nحيث إن في ذمة المطلوب الأمر ضده مبلغاً ثابتاً بالكتابة، وحال الأداء، ولم يقم بالسداد حتى تاريخه.',
                'is_required': True
            },
            {
                'case_type': LegalTemplate.CASE_TYPE_PAYMENT_ORDER,
                'section_key': 'requests',
                'section_title': 'الطلبات',
                'default_text': 'ثانياً: الطلبات\nنلتمس من عدالتكم إصدار أمر أداء بإلزام المطلوب الأمر ضده بسداد المبلغ محل الطلب مع الرسوم.',
                'is_required': True
            },
            
            # دعوى
            {
                'case_type': LegalTemplate.CASE_TYPE_LAWSUIT,
                'section_key': 'facts',
                'section_title': 'وقائع الدعوى',
                'default_text': 'وقائع الدعوى:\nتتلخص وقائع هذه الدعوى في أن المدعي قد تضرر من المدعى عليه على النحو المبين.',
                'is_required': True
            },
            {
                'case_type': LegalTemplate.CASE_TYPE_LAWSUIT,
                'section_key': 'legal',
                'section_title': 'الأسباب والأسناد القانونية',
                'default_text': 'الأسباب والأسناد القانونية:\nاستناداً إلى القوانين النافذة وأحكام الشريعة الإسلامية.',
                'is_required': True
            },
            {
                'case_type': LegalTemplate.CASE_TYPE_LAWSUIT,
                'section_key': 'requests',
                'section_title': 'طلبات الدعوى',
                'default_text': 'طلبات الدعوى:\nنلتمس الحكم وفقاً لما ورد أعلاه.',
                'is_required': True
            },
            
            # رد على دعوى
            {
                'case_type': LegalTemplate.CASE_TYPE_REPLY,
                'section_key': 'reply',
                'section_title': 'الرد على الدعوى',
                'default_text': 'رداً على ما ورد بصحيفة الدعوى، فإن المدعى عليه يتمسك بالدفوع الآتية.',
                'is_required': True
            },
            
            # استئناف
            {
                'case_type': LegalTemplate.CASE_TYPE_APPEAL,
                'section_key': 'formal',
                'section_title': 'من الناحية الشكلية',
                'default_text': 'أولاً: من الناحية الشكلية\nوحيث إن الاستئناف قُدم في الميعاد القانوني المستوجب قبوله شكلاً.',
                'is_required': True
            },
            {
                'case_type': LegalTemplate.CASE_TYPE_APPEAL,
                'section_key': 'substantive',
                'section_title': 'من الناحية الموضوعية',
                'default_text': 'ثانياً: من الناحية الموضوعية\nوحيث إن الحكم المستأنف قد جانبه الصواب في التطبيق.',
                'is_required': True
            },
            
            # طعن
            {
                'case_type': LegalTemplate.CASE_TYPE_CHALLENGE,
                'section_key': 'grounds',
                'section_title': 'أسباب الطعن',
                'default_text': 'أسباب الطعن:\nبُني الطعن على مخالفة القانون والخطأ في تطبيقه.',
                'is_required': True
            },
        ]
        
        created_count = 0
        updated_count = 0
        
        for template_data in templates_data:
            try:
                template, created = LegalTemplate.objects.update_or_create(
                    case_type=template_data['case_type'],
                    section_key=template_data['section_key'],
                    defaults={
                        'section_title': template_data['section_title'],
                        'default_text': template_data['default_text'],
                        'is_required': template_data['is_required'],
                    }
                )
                
                if created:
                    created_count += 1
                else:
                    updated_count += 1
            except Exception as e:
                self.stdout.write(self.style.ERROR(f'Error creating template: {e}'))
        
        # Summary
        self.stdout.write('')
        self.stdout.write(self.style.SUCCESS('=' * 60))
        self.stdout.write(self.style.SUCCESS('Summary:'))
        self.stdout.write(self.style.SUCCESS(f'  - Templates created: {created_count}'))
        self.stdout.write(self.style.SUCCESS(f'  - Templates updated: {updated_count}'))
        self.stdout.write(self.style.SUCCESS(f'  - Total templates: {LegalTemplate.objects.count()}'))
        self.stdout.write(self.style.SUCCESS('=' * 60))
        self.stdout.write(self.style.SUCCESS('Successfully added all legal templates!'))

