"""
Management command to seed the database with test data
"""
from django.core.management.base import BaseCommand
from django.contrib.auth.models import User
from django.utils import timezone
from datetime import date, timedelta
from accounts.models import UserProfile
from lawsuits.models import Lawsuit
from parties.models import Plaintiff, Defendant
from attachments.models import Attachment
from responses.models import Response
from appeals.models import Appeal
from hearings.models import Hearing
from judgments.models import Judgment
from django.core.files.uploadedfile import SimpleUploadedFile
import random


class Command(BaseCommand):
    help = 'Seed the database with test data (judges, lawyers, citizens, courts, lawsuits, appeals, judgments)'

    def add_arguments(self, parser):
        parser.add_argument(
            '--clear',
            action='store_true',
            help='Clear existing data before seeding',
        )

    def handle(self, *args, **options):
        if options['clear']:
            self.stdout.write(self.style.WARNING('Clearing existing data...'))
            # Clear data (in reverse order of dependencies)
            Judgment.objects.all().delete()
            Hearing.objects.all().delete()
            Appeal.objects.all().delete()
            Response.objects.all().delete()
            Attachment.objects.all().delete()
            Defendant.objects.all().delete()
            Plaintiff.objects.all().delete()
            Lawsuit.objects.all().delete()
            UserProfile.objects.all().delete()
            User.objects.filter(is_superuser=False).delete()
            self.stdout.write(self.style.SUCCESS('Data cleared.'))

        self.stdout.write(self.style.SUCCESS('Starting data seeding...'))

        # Create Users with different roles
        users = self.create_users()
        
        # Create Lawsuits
        lawsuits = self.create_lawsuits(users)
        
        # Create Parties
        self.create_parties(lawsuits)
        
        # Create Attachments
        self.create_attachments(lawsuits, users)
        
        # Create Responses
        self.create_responses(lawsuits, users)
        
        # Create Appeals
        self.create_appeals(lawsuits, users)
        
        # Create Hearings
        self.create_hearings(lawsuits, users)
        
        # Create Judgments
        self.create_judgments(lawsuits, users)

        self.stdout.write(self.style.SUCCESS('\n✅ Data seeding completed successfully!'))
        self.stdout.write(self.style.SUCCESS(f'\nCreated:'))
        self.stdout.write(f'  - {User.objects.count()} Users')
        self.stdout.write(f'  - {Lawsuit.objects.count()} Lawsuits')
        self.stdout.write(f'  - {Plaintiff.objects.count()} Plaintiffs')
        self.stdout.write(f'  - {Defendant.objects.count()} Defendants')
        self.stdout.write(f'  - {Attachment.objects.count()} Attachments')
        self.stdout.write(f'  - {Response.objects.count()} Responses')
        self.stdout.write(f'  - {Appeal.objects.count()} Appeals')
        self.stdout.write(f'  - {Hearing.objects.count()} Hearings')
        self.stdout.write(f'  - {Judgment.objects.count()} Judgments')

    def create_users(self):
        """Create users with different roles"""
        self.stdout.write('Creating users...')
        
        users_data = [
            # Judges
            {'username': 'judge1', 'email': 'judge1@smartjudi.local', 'role': UserProfile.ROLE_JUDGE, 'first_name': 'محمد', 'last_name': 'أحمد'},
            {'username': 'judge2', 'email': 'judge2@smartjudi.local', 'role': UserProfile.ROLE_JUDGE, 'first_name': 'علي', 'last_name': 'سعيد'},
            
            # Lawyers
            {'username': 'lawyer1', 'email': 'lawyer1@smartjudi.local', 'role': UserProfile.ROLE_LAWYER, 'first_name': 'خالد', 'last_name': 'محمد'},
            {'username': 'lawyer2', 'email': 'lawyer2@smartjudi.local', 'role': UserProfile.ROLE_LAWYER, 'first_name': 'أحمد', 'last_name': 'علي'},
            {'username': 'lawyer3', 'email': 'lawyer3@smartjudi.local', 'role': UserProfile.ROLE_LAWYER, 'first_name': 'سعيد', 'last_name': 'حسن'},
            
            # Citizens
            {'username': 'citizen1', 'email': 'citizen1@smartjudi.local', 'role': UserProfile.ROLE_CITIZEN, 'first_name': 'عمر', 'last_name': 'يوسف'},
            {'username': 'citizen2', 'email': 'citizen2@smartjudi.local', 'role': UserProfile.ROLE_CITIZEN, 'first_name': 'فاطمة', 'last_name': 'أحمد'},
            {'username': 'citizen3', 'email': 'citizen3@smartjudi.local', 'role': UserProfile.ROLE_CITIZEN, 'first_name': 'مريم', 'last_name': 'خالد'},
            
            # Admin
            {'username': 'admin', 'email': 'admin@smartjudi.local', 'role': UserProfile.ROLE_ADMIN, 'first_name': 'مدير', 'last_name': 'النظام', 'is_staff': True, 'is_superuser': True},
        ]
        
        users = {}
        for user_data in users_data:
            username = user_data.pop('username')
            role = user_data.pop('role')
            is_staff = user_data.pop('is_staff', False)
            is_superuser = user_data.pop('is_superuser', False)
            
            user, created = User.objects.get_or_create(
                username=username,
                defaults={
                    'email': user_data['email'],
                    'first_name': user_data['first_name'],
                    'last_name': user_data['last_name'],
                    'is_staff': is_staff,
                    'is_superuser': is_superuser,
                }
            )
            
            if created:
                user.set_password('password123')
                user.save()
            
            # Set role
            profile = user.profile
            profile.role = role
            profile.phone_number = f'777{random.randint(100000, 999999)}'
            profile.national_id = f'{random.randint(100000, 999999)}'
            profile.save()
            
            users[username] = user
        
        return users

    def create_lawsuits(self, users):
        """Create lawsuits"""
        self.stdout.write('Creating lawsuits...')
        
        courts = [
            'محكمة الاستئناف بصنعاء',
            'المحكمة الابتدائية بصنعاء',
            'المحكمة التجارية بصنعاء',
            'محكمة الاستئناف بعدن',
            'المحكمة الابتدائية بعدن',
        ]
        
        case_types = [
            Lawsuit.CASE_TYPE_CIVIL,
            Lawsuit.CASE_TYPE_COMMERCIAL,
            Lawsuit.CASE_TYPE_PERSONAL_STATUS,
            Lawsuit.CASE_TYPE_LABOR,
        ]
        
        statuses = [
            Lawsuit.STATUS_NEW,
            Lawsuit.STATUS_UNDER_REVIEW,
            Lawsuit.STATUS_COMPLETED,
            Lawsuit.STATUS_CLOSED,
        ]
        
        lawsuits = []
        lawyer_users = [u for u in users.values() if u.profile.role == UserProfile.ROLE_LAWYER]
        citizen_users = [u for u in users.values() if u.profile.role == UserProfile.ROLE_CITIZEN]
        
        for i in range(10):
            lawsuit = Lawsuit.objects.create(
                case_number=f'{2024 - (i % 3)}/{100 + i:03d}',
                gregorian_date=date(2024, 1, 1) + timedelta(days=i * 30),
                hijri_date=f'1445/{6 + (i % 6):02d}/{(i % 28) + 1:02d}',
                case_type=random.choice(case_types),
                court=random.choice(courts),
                subject=f'دعوى {i+1}: مطالبة مالية / إخلاء / نفقة / تعويض',
                facts=f'وقائع الدعوى رقم {i+1}، حيث قام المدعي برفع دعوى ضد المدعى عليه بسبب...',
                reasons='الأسباب والأسانيد القانونية: طبقاً للمادة...',
                requests='الطلبات المقدمة: الحكم لصالح المدعي...',
                case_status=random.choice(statuses),
                created_by=random.choice(lawyer_users) if i % 3 != 0 else random.choice(citizen_users),
            )
            lawsuits.append(lawsuit)
        
        return lawsuits

    def create_parties(self, lawsuits):
        """Create plaintiffs and defendants"""
        self.stdout.write('Creating parties...')
        
        for lawsuit in lawsuits:
            # Create 1-2 plaintiffs
            for i in range(random.randint(1, 2)):
                Plaintiff.objects.create(
                    lawsuit=lawsuit,
                    name=f'مدعي {lawsuit.case_number} - {i+1}',
                    gender=random.choice([Plaintiff.GENDER_MALE, Plaintiff.GENDER_FEMALE]),
                    nationality='يمني',
                    occupation=random.choice(['موظف', 'تاجر', 'مهندس', 'طبيب', 'معلم']),
                    address=f'صنعاء، شارع {random.choice(["الزبيري", "حدة", "الستين", "الجامعة"])}',
                    phone=f'777{random.randint(100000, 999999)}',
                    attorney_name=f'المحامي {random.choice(["أحمد", "خالد", "سعيد"])}',
                    attorney_phone=f'777{random.randint(100000, 999999)}',
                )
            
            # Create 1-2 defendants
            for i in range(random.randint(1, 2)):
                Defendant.objects.create(
                    lawsuit=lawsuit,
                    name=f'مدعى عليه {lawsuit.case_number} - {i+1}',
                    gender=random.choice([Defendant.GENDER_MALE, Defendant.GENDER_FEMALE]),
                    nationality='يمني',
                    occupation=random.choice(['موظف', 'تاجر', 'مهندس', 'طبيب', 'معلم']),
                    address=f'عدن، شارع {random.choice(["كريتر", "الشهيد", "التحرير"])}',
                    phone=f'777{random.randint(100000, 999999)}',
                )

    def create_attachments(self, lawsuits, users):
        """Create attachments"""
        self.stdout.write('Creating attachments...')
        
        doc_types = [
            Attachment.DOC_TYPE_CONTRACT,
            Attachment.DOC_TYPE_CERTIFICATE,
            Attachment.DOC_TYPE_EVIDENCE,
            Attachment.DOC_TYPE_IDENTITY,
        ]
        
        for lawsuit in lawsuits[:5]:  # Only for first 5 lawsuits
            for i in range(random.randint(1, 3)):
                test_file = SimpleUploadedFile(
                    f"document_{lawsuit.id}_{i}.txt",
                    b"Test document content for attachment",
                    content_type="text/plain"
                )
                Attachment.objects.create(
                    lawsuit=lawsuit,
                    document_type=random.choice(doc_types),
                    gregorian_date=lawsuit.gregorian_date + timedelta(days=i+1),
                    hijri_date=lawsuit.hijri_date,
                    page_count=random.randint(1, 10),
                    content=f'محتوى المستند {i+1} للدعوى {lawsuit.case_number}',
                    evidence_basis=f'وجه الاستدلال من المستند {i+1}',
                    file=test_file,
                )

    def create_responses(self, lawsuits, users):
        """Create responses"""
        self.stdout.write('Creating responses...')
        
        response_types = [
            Response.RESPONSE_TYPE_MEMORANDUM,
            Response.RESPONSE_TYPE_REPLY,
            Response.RESPONSE_TYPE_OBJECTION,
        ]
        
        lawyer_users = [u for u in users.values() if u.profile.role == UserProfile.ROLE_LAWYER]
        
        for lawsuit in lawsuits[:7]:  # For first 7 lawsuits
            response = Response.objects.create(
                lawsuit=lawsuit,
                response_text=f'نص الرد المقدم للدعوى {lawsuit.case_number}',
                submitted_by=f'المحامي {random.choice(["أحمد", "خالد", "سعيد"])}',
                submitted_by_user=random.choice(lawyer_users) if lawyer_users else None,
                submission_date=lawsuit.gregorian_date + timedelta(days=random.randint(5, 30)),
                hijri_date=lawsuit.hijri_date,
                response_type=random.choice(response_types),
            )

    def create_appeals(self, lawsuits, users):
        """Create appeals"""
        self.stdout.write('Creating appeals...')
        
        appeal_types = [
            Appeal.APPEAL_TYPE_APPEAL,
            Appeal.APPEAL_TYPE_CASSATION,
        ]
        
        appeal_statuses = [
            Appeal.STATUS_PENDING,
            Appeal.STATUS_UNDER_REVIEW,
            Appeal.STATUS_ACCEPTED,
        ]
        
        lawyer_users = [u for u in users.values() if u.profile.role == UserProfile.ROLE_LAWYER]
        judged_lawsuits = [ls for ls in lawsuits if ls.case_status == Lawsuit.STATUS_COMPLETED][:3]
        
        for i, lawsuit in enumerate(judged_lawsuits):
            Appeal.objects.create(
                lawsuit=lawsuit,
                appeal_type=random.choice(appeal_types),
                appeal_number=f'AP-{lawsuit.case_number}',
                appeal_reasons=f'أسباب الطعن على الحكم في الدعوى {lawsuit.case_number}',
                appeal_requests='طلبات الطعن: إلغاء الحكم...',
                higher_court='محكمة التمييز',
                status=random.choice(appeal_statuses),
                appeal_date=lawsuit.gregorian_date + timedelta(days=30),
                hijri_date=lawsuit.hijri_date,
                submitted_by=f'المحامي {random.choice(["أحمد", "خالد", "سعيد"])}',
                submitted_by_user=random.choice(lawyer_users) if lawyer_users else None,
            )

    def create_hearings(self, lawsuits, users):
        """Create hearings"""
        self.stdout.write('Creating hearings...')
        
        hearing_types = [
            Hearing.HEARING_TYPE_PRELIMINARY,
            Hearing.HEARING_TYPE_MAIN,
            Hearing.HEARING_TYPE_DECISION,
            Hearing.HEARING_TYPE_ADJOURNED,
        ]
        
        judge_users = [u for u in users.values() if u.profile.role == UserProfile.ROLE_JUDGE]
        
        for lawsuit in lawsuits:
            for i in range(random.randint(1, 3)):
                Hearing.objects.create(
                    lawsuit=lawsuit,
                    hearing_date=lawsuit.gregorian_date + timedelta(days=random.randint(10, 60) + i*30),
                    hijri_date=lawsuit.hijri_date,
                    hearing_time=timezone.now().replace(hour=10 + i, minute=0).time(),
                    notes=f'ملاحظات الجلسة {i+1} للدعوى {lawsuit.case_number}',
                    judge_name=f'القاضي {random.choice(["محمد", "علي", "أحمد"])}',
                    judge=random.choice(judge_users) if judge_users else None,
                    hearing_type=random.choice(hearing_types),
                    created_by=random.choice(judge_users) if judge_users else None,
                )

    def create_judgments(self, lawsuits, users):
        """Create judgments"""
        self.stdout.write('Creating judgments...')
        
        judgment_types = [
            Judgment.JUDGMENT_TYPE_PRIMARY,
            Judgment.JUDGMENT_TYPE_APPEAL,
        ]
        
        judgment_statuses = [
            Judgment.STATUS_PENDING,
            Judgment.STATUS_EXECUTABLE,
            Judgment.STATUS_FINAL,
        ]
        
        judge_users = [u for u in users.values() if u.profile.role == UserProfile.ROLE_JUDGE]
        judged_lawsuits = [ls for ls in lawsuits if ls.case_status in [Lawsuit.STATUS_COMPLETED, Lawsuit.STATUS_CLOSED]][:5]
        
        for i, lawsuit in enumerate(judged_lawsuits):
            Judgment.objects.create(
                lawsuit=lawsuit,
                judgment_type=random.choice(judgment_types),
                judgment_number=f'J-{lawsuit.case_number}',
                judgment_date=lawsuit.gregorian_date + timedelta(days=random.randint(60, 120)),
                hijri_date=lawsuit.hijri_date,
                judgment_text=f'نص الحكم في الدعوى {lawsuit.case_number}: بناءً على...',
                summary=f'ملخص الحكم: حكم لصالح...',
                judge_name=f'القاضي {random.choice(["محمد", "علي", "أحمد"])}',
                judge=random.choice(judge_users) if judge_users else None,
                court_name=lawsuit.court,
                status=random.choice(judgment_statuses),
                created_by=random.choice(judge_users) if judge_users else None,
            )

