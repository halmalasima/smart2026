"""
Management command to automatically create a superuser if none exists.
This is useful for deployment environments where shell access is not available.
"""
import os
from django.core.management.base import BaseCommand
from django.contrib.auth.models import User


class Command(BaseCommand):
    help = 'Create a superuser automatically if none exists (for deployment)'

    def add_arguments(self, parser):
        parser.add_argument(
            '--username',
            type=str,
            default=os.environ.get('SUPERUSER_USERNAME', 'admin'),
            help='Superuser username (default: admin or from SUPERUSER_USERNAME env var)',
        )
        parser.add_argument(
            '--email',
            type=str,
            default=os.environ.get('SUPERUSER_EMAIL', 'admin@smartjudi.local'),
            help='Superuser email (default: admin@smartjudi.local or from SUPERUSER_EMAIL env var)',
        )
        parser.add_argument(
            '--password',
            type=str,
            default=os.environ.get('SUPERUSER_PASSWORD', 'admin123'),
            help='Superuser password (default: from SUPERUSER_PASSWORD env var, or auto-generated)',
        )
        parser.add_argument(
            '--no-input',
            action='store_true',
            help='Run non-interactively (use environment variables or defaults)',
        )

    def handle(self, *args, **options):
        username = options['username']
        email = options['email']
        password = options['password']
        no_input = options['no_input']

        # Check if superuser already exists
        if User.objects.filter(is_superuser=True).exists():
            self.stdout.write(
                self.style.SUCCESS('Superuser already exists. Skipping creation.')
            )
            return

        # Generate password if not provided
        if not password:
            import secrets
            password = secrets.token_urlsafe(16)
            self.stdout.write(
                self.style.WARNING(
                    f'⚠️  No password provided. Generated password: {password}\n'
                    '⚠️  Please save this password or set SUPERUSER_PASSWORD environment variable!'
                )
            )

        # Create superuser
        try:
            user = User.objects.create_superuser(
                username=username,
                email=email,
                password=password,
            )
            self.stdout.write(
                self.style.SUCCESS(
                    f'✅ Superuser created successfully!\n'
                    f'   Username: {username}\n'
                    f'   Email: {email}'
                )
            )
        except Exception as e:
            self.stdout.write(
                self.style.ERROR(f'❌ Error creating superuser: {e}')
            )
            raise
