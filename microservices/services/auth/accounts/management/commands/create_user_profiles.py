"""
Management command to create UserProfile for users who don't have one
"""
from django.core.management.base import BaseCommand
from django.contrib.auth.models import User
from accounts.models import UserProfile


class Command(BaseCommand):
    help = 'Create UserProfile for users who don\'t have one'

    def add_arguments(self, parser):
        parser.add_argument(
            '--role',
            type=str,
            default='citizen',
            help='Default role for new profiles (default: citizen)',
            choices=['judge', 'lawyer', 'notary', 'citizen', 'admin'],
        )

    def handle(self, *args, **options):
        role = options['role']
        users_without_profile = User.objects.filter(profile__isnull=True)
        
        if not users_without_profile.exists():
            self.stdout.write(
                self.style.SUCCESS('All users already have profiles!')
            )
            return

        count = 0
        for user in users_without_profile:
            profile, created = UserProfile.objects.get_or_create(
                user=user,
                defaults={'role': role}
            )
            if created:
                count += 1
                self.stdout.write(
                    self.style.SUCCESS(
                        f'Created profile for user: {user.username} (role: {role})'
                    )
                )

        self.stdout.write(
            self.style.SUCCESS(
                f'\nSuccessfully created {count} user profile(s)'
            )
        )

