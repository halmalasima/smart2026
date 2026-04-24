from django.core.management.base import BaseCommand
from lawyers.models import Lawyer, LawyerFilterOptions


class Command(BaseCommand):
    help = 'Populate LawyerFilterOptions with branches and grades from existing lawyers'

    def handle(self, *args, **options):
        self.stdout.write('Populating filter options...')
        
        # Get distinct branches from lawyers
        branches = Lawyer.objects.values_list('branch', flat=True).distinct().exclude(branch__isnull=True).exclude(branch='')
        
        # Get distinct grades from lawyers
        grades = Lawyer.objects.values_list('grade', flat=True).distinct().exclude(grade__isnull=True).exclude(grade='')
        
        # Create or update branch options
        for i, branch in enumerate(sorted(branches)):
            LawyerFilterOptions.objects.update_or_create(
                option_type='branch',
                option_value=branch,
                defaults={
                    'display_name': branch,
                    'sort_order': i,
                    'is_active': True
                }
            )
        
        # Create or update grade options
        for i, grade in enumerate(sorted(grades)):
            LawyerFilterOptions.objects.update_or_create(
                option_type='grade',
                option_value=grade,
                defaults={
                    'display_name': grade,
                    'sort_order': i,
                    'is_active': True
                }
            )
        
        self.stdout.write(
            self.style.SUCCESS(
                f'Successfully populated filter options: {len(branches)} branches, {len(grades)} grades'
            )
        )
