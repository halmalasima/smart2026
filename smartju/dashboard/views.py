from django.shortcuts import render
from django.views.generic import RedirectView

from django.contrib.auth.decorators import login_required, user_passes_test
from django.contrib.auth.models import User
from django.contrib.sessions.models import Session
from django.utils import timezone
from datetime import timedelta
from lawsuits.models import Lawsuit
from courts.models import Court
from parties.models import Plaintiff, Defendant

from laws.models import Law
from logs.models import UserSession, SearchLog, AIChatLog
from .models import SubscriptionPlan, UserSubscription

def intro_page(request):
    """
    Public landing page for SmartJudi website - Marketing/Intro
    """
    total_lawsuits = Lawsuit.objects.count()
    total_users = User.objects.count()
    total_laws = Law.objects.count()
    
    context = {
        'total_lawsuits': total_lawsuits,
        'total_users': total_users,
        'total_laws': total_laws,
    }
    return render(request, 'dashboard/intro.html', context)

@login_required(login_url='/login/')
def web_portal(request):
    """
    Main services portal after login
    """
    total_lawsuits = Lawsuit.objects.count()
    total_users = User.objects.count()
    total_laws = Law.objects.count()
    
    # Check subscription
    has_active_sub = UserSubscription.objects.filter(user=request.user, is_active=True, end_date__gte=timezone.now()).exists()
    
    context = {
        'total_lawsuits': total_lawsuits,
        'total_users': total_users,
        'total_laws': total_laws,
        'has_active_sub': has_active_sub,
        'user_role': getattr(request.user, 'profile', None).role if hasattr(request.user, 'profile') else 'citizen',
    }
    return render(request, 'dashboard/landing.html', context)

from django.contrib.auth import authenticate, login
from django.contrib import messages
from accounts.models import UserProfile


def custom_login(request):
    """
    Custom login page — accepts phone number (or username/email) + password.
    """
    if request.user.is_authenticated:
        return RedirectView.as_view(url='/portal/')(request)

    if request.method == 'POST':
        identifier = (request.POST.get('phone') or request.POST.get('username') or '').strip()
        p = request.POST.get('password')
        user = authenticate(request, username=identifier, password=p)

        if user is not None:
            login(request, user)
            if user.is_superuser or (hasattr(user, 'profile') and user.profile.role == 'admin'):
                return RedirectView.as_view(url='/cp/')(request)
            return RedirectView.as_view(url='/portal/')(request)
        else:
            messages.error(request, 'رقم الهاتف أو كلمة المرور غير صحيحة')

    return render(request, 'dashboard/login_custom.html')


def custom_register(request):
    """
    Custom registration page — phone is the primary identifier.
    """
    if request.user.is_authenticated:
        return RedirectView.as_view(url='/portal/')(request)

    if request.method == 'POST':
        full_name   = (request.POST.get('full_name') or '').strip()
        phone       = (request.POST.get('phone') or '').strip()
        national_id = (request.POST.get('national_id') or '').strip() or None
        username    = (request.POST.get('username') or '').strip()
        email       = (request.POST.get('email') or '').strip()
        role        = (request.POST.get('role') or 'citizen').strip()
        password    = request.POST.get('password') or ''
        password2   = request.POST.get('password2') or ''

        errors = []
        if not full_name:                  errors.append('الاسم الكامل مطلوب')
        if not phone or len(''.join(c for c in phone if c.isdigit())) < 7:
            errors.append('رقم الهاتف غير صالح')
        if not username:                   username = ''.join(c for c in phone if c.isdigit()) or f'user{User.objects.count()+1}'
        if len(password) < 6:              errors.append('كلمة المرور يجب أن تكون 6 أحرف على الأقل')
        if password != password2:          errors.append('كلمتا المرور غير متطابقتين')
        if role not in [c[0] for c in UserProfile.ROLE_CHOICES]: role = 'citizen'

        # Uniqueness checks
        if not errors and User.objects.filter(username__iexact=username).exists():
            errors.append('اسم المستخدم مستخدم بالفعل')
        if not errors and email and User.objects.filter(email__iexact=email).exists():
            errors.append('البريد الإلكتروني مستخدم بالفعل')

        if errors:
            for e in errors:
                messages.error(request, e)
            return render(request, 'dashboard/register_custom.html', {'form': request.POST})

        # Create user + profile
        first, _, last = full_name.partition(' ')
        user = User.objects.create_user(
            username=username,
            email=email or '',
            password=password,
            first_name=first,
            last_name=last,
        )
        # ensure profile exists (signal may have created it)
        profile, _ = UserProfile.objects.get_or_create(user=user)
        profile.phone_number = phone
        profile.national_id = national_id
        profile.role = role
        profile.save()

        login(request, user, backend='accounts.auth_backends.PhoneOrUsernameBackend')
        messages.success(request, 'تم إنشاء حسابك بنجاح، أهلاً بك في منصة القضاء الذكية')
        return RedirectView.as_view(url='/portal/')(request)

    return render(request, 'dashboard/register_custom.html')

@login_required(login_url='/login/')
def dashboard_home(request):
    if not request.user.is_superuser and not (hasattr(request.user, 'profile') and request.user.profile.role == 'admin'):
        from django.http import HttpResponseForbidden
        return HttpResponseForbidden("Access Denied")

    now = timezone.now()
    today_start = now.replace(hour=0, minute=0, second=0, microsecond=0)
    
    # stats
    total_users = User.objects.count()
    active_visitors = UserSession.objects.filter(is_active=True).count()
    search_count = SearchLog.objects.count()
    ai_chat_count = AIChatLog.objects.count()
    total_subs = UserSubscription.objects.filter(is_active=True).count()
    
    total_lawsuits = Lawsuit.objects.count()
    new_lawsuits_today = Lawsuit.objects.filter(created_at__gte=today_start).count()
    
    recent_lawsuits = Lawsuit.objects.order_by('-created_at')[:7]
    recent_users = User.objects.order_by('-date_joined')[:5]

    context = {
        'total_users': total_users,
        'active_visitors': active_visitors,
        'search_count': search_count,
        'ai_chat_count': ai_chat_count,
        'total_subs': total_subs,
        'total_lawsuits': total_lawsuits,
        'new_lawsuits_today': new_lawsuits_today,
        'recent_lawsuits': recent_lawsuits,
        'recent_users': recent_users,
    }
    return render(request, 'dashboard/index.html', context)
