import os
import django
import random
from datetime import date, timedelta

# Setup Django environment
os.environ.setdefault('DJANGO_SETTINGS_MODULE', 'smartju.settings.base')
django.setup()

from django.contrib.auth.models import User
from lawsuits.models import Lawsuit
from courts.models import Court, Governorate
from payments.models import PaymentOrder
from appeals.models import Appeal
from responses.models import Response

def generate_test_data():
    # 1. Get or Create User M
    user, created = User.objects.get_or_create(username='M')
    if created or not user.check_password('admin123'):
        user.set_password('admin123')
        user.save()
        print(f"User 'M' ready.")

    # 2. Get available courts
    courts = list(Court.objects.all())
    if not courts:
        print("No courts found. Please import courts first.")
        return

    governorates = list(Governorate.objects.all())

    # Data templates
    subjects = [
        "دعوى مطالبة مالية", "دعوى إخلاء عقار", "دعوى تعويض عن ضرر", 
        "دعوى فسخ عقد عمل", "دعوى تركة ومواريث", "دعوى حضانة ونفقة",
        "دعوى تجارية - إخلال بالتزام", "دعوى ملكية فكرية", "قضية جنائية - سرقة",
        "دعوى إدارية - إلغاء قرار", "دعوى صحة توقيع", "دعوى إثبات زواج"
    ]
    
    facts = "تتلخص وقائع هذه الدعوى في قيام المدعي عليه بالامتناع عن أداء الالتزامات المترتبة عليه تجاه المدعي رغم المطالبات المتكررة، مما ألحق بالمدعي أضراراً مادية ومعنوية جسيمة تستوجب التدخل القضائي."
    legal_basis = "استناداً إلى أحكام القانون المدني وقانون الإثبات وقانون المرافعات والتنفيذ المدني المعمول به."
    requests = "1. القضاء بإلزام المدعى عليه بالمطلوب.\n2. إلزامه بدفع أتعاب المحاماة ومصاريف التقاضي."

    # --- Generate 30 Lawsuits ---
    print("Generating 30 Lawsuits...")
    lawsuits = []
    for i in range(1, 31):
        case_type = random.choice(['دعوى', 'civil', 'commercial', 'criminal', 'personal_status'])
        gov = random.choice(governorates) if governorates else None
        
        l = Lawsuit.objects.create(
            case_number=f"CASE-2026-{100+i}",
            subject=f"{random.choice(subjects)} - {i}",
            case_type=case_type,
            case_status='جديد',
            governorate=gov.name if gov else "صنعاء",
            court_fk=random.choice(courts),
            facts=facts,
            legal_basis=legal_basis,
            requests=requests,
            created_by=user,
            filing_date=date.today() - timedelta(days=random.randint(0, 30))
        )
        lawsuits.append(l)
    print(f"Created 30 Lawsuits.")

    # --- Generate 10 Payment Orders ---
    print("Generating 10 Payment Orders...")
    for i in range(1, 11):
        l = random.choice(lawsuits)
        PaymentOrder.objects.create(
            lawsuit=l,
            amount=random.randint(50000, 1000000),
            order_date=date.today() - timedelta(days=random.randint(0, 10)),
            order_number=f"ORD-2026-{500+i}",
            description=f"أمر أداء مالي ناتج عن المطالبة رقم {l.case_number}",
            status='pending'
        )
    print("Created 10 Payment Orders.")

    # --- Generate 10 Appeals ---
    print("Generating 10 Appeals...")
    for i in range(1, 11):
        l = random.choice(lawsuits)
        Appeal.objects.create(
            lawsuit=l,
            appeal_type='appeal',
            appeal_number=f"APP-2026-{700+i}",
            appeal_reasons="الخطأ في تطبيق القانون والفساد في الاستدلال ومخالفة الثابت بالأوراق.",
            appeal_requests="قبول الاستئناف شكلاً وفي الموضوع بإلغاء الحكم المستأنف والقضاء مجدداً بطلباتنا.",
            higher_court="محكمة الاستئناف - الشعبة المدنية",
            status='pending',
            appeal_date=date.today(),
            submitted_by="المستأنف بواسطة محاميه",
            submitted_by_user=user
        )
    print("Created 10 Appeals.")

    # --- Generate 10 Responses ---
    print("Generating 10 Responses...")
    for i in range(1, 11):
        l = random.choice(lawsuits)
        Response.objects.create(
            lawsuit=l,
            response_text="بالإشارة إلى الدعوى المذكورة أعلاه، نود إفادة المحكمة الموقرة بإنكار كافة الادعاءات الواردة في صحيفة الدعوى جملة وتفصيلاً لعدم استنادها إلى دليل صحيح من القانون أو الواقع.",
            submitted_by="المدعى عليه / وكيله",
            submitted_by_user=user,
            submission_date=date.today(),
            response_type='reply'
        )
    print("Created 10 Responses.")

    print("-" * 30)
    print("Test Data Generation Successful!")

if __name__ == "__main__":
    generate_test_data()
