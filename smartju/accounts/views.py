from rest_framework import viewsets, status
from rest_framework.decorators import action, api_view, permission_classes
from rest_framework.response import Response
from rest_framework.permissions import IsAuthenticated, IsAdminUser, AllowAny
from django.contrib.auth.models import User
from django.core.cache import cache
from rest_framework_simplejwt.views import TokenObtainPairView
from rest_framework_simplejwt.tokens import RefreshToken
from .models import UserProfile
from .serializers import (
    UserProfileSerializer, UserProfileCreateSerializer, UserProfileUpdateSerializer,
    UserRegistrationSerializer, CustomTokenObtainPairSerializer
)
from .permissions import IsJudgeOrAdmin
import logging
import random
import string

logger = logging.getLogger(__name__)


class CustomTokenObtainPairView(TokenObtainPairView):
    """
    Custom JWT login view that uses CustomTokenObtainPairSerializer.
    """
    serializer_class = CustomTokenObtainPairSerializer

    def post(self, request, *args, **kwargs):
        response = super().post(request, *args, **kwargs)
        if response.status_code == status.HTTP_200_OK:
            try:
                username = request.data.get("username")
                user = User.objects.filter(username=username).first() or User.objects.filter(profile__phone_number=username).first()
                if user:
                    from logs.models import UserSession
                    from control_panel.models import ActivityLog
                    
                    x_forwarded_for = request.META.get('HTTP_X_FORWARDED_FOR')
                    ip = x_forwarded_for.split(',')[0].strip() if x_forwarded_for else request.META.get('REMOTE_ADDR')
                    
                    # Parse user agent simply
                    ua = request.META.get('HTTP_USER_AGENT', '').lower()
                    browser = 'Unknown'
                    if 'chrome' in ua: browser = 'Chrome'
                    elif 'safari' in ua: browser = 'Safari'
                    elif 'firefox' in ua: browser = 'Firefox'
                    elif 'edge' in ua: browser = 'Edge'
                    elif 'dart' in ua: browser = 'Flutter App'
                    
                    device_type = 'Desktop'
                    if 'mobi' in ua or 'android' in ua or 'iphone' in ua:
                        device_type = 'Mobile'
                    elif 'tablet' in ua or 'ipad' in ua:
                        device_type = 'Tablet'
                        
                    # Geolocation from headers (Cloudflare, Nginx, etc) if available
                    country = request.META.get('HTTP_CF_IPCOUNTRY', '')
                    city = request.META.get('HTTP_X_CITY', '')
                    
                    UserSession.objects.create(
                        user=user,
                        ip_address=ip,
                        browser=browser,
                        device_type=device_type,
                        country=country,
                        city=city
                    )
                    
                    ActivityLog.objects.create(
                        user=user,
                        action='login',
                        target=user.username,
                        description=f'تسجيل دخول عبر التطبيق (API) - {device_type}',
                        ip_address=ip,
                        user_agent=request.META.get('HTTP_USER_AGENT', '')
                    )
            except Exception as e:
                logger.error(f"Error logging API session: {e}")
                
        return response

class UserProfileViewSet(viewsets.ModelViewSet):
    """
    ViewSet for UserProfile
    """
    queryset = UserProfile.objects.select_related('user').all()
    permission_classes = [IsAuthenticated]
    
    def get_serializer_class(self):
        if self.action == 'create':
            return UserProfileCreateSerializer
        elif self.action in ['update', 'partial_update']:
            return UserProfileUpdateSerializer
        return UserProfileSerializer
    
    def get_permissions(self):
        # Allow users to update their own profile via 'me' action
        if self.action == 'me':
            return [IsAuthenticated()]
        if self.action in ['create', 'update', 'partial_update', 'destroy']:
            return [IsJudgeOrAdmin()]
        return [IsAuthenticated()]
    
    @action(detail=False, methods=['get', 'put', 'patch'])
    def me(self, request):
        """
        Get or update current user's profile
        """
        try:
            profile = request.user.profile
        except UserProfile.DoesNotExist:
            return Response(
                {'detail': 'Profile not found'}, 
                status=status.HTTP_404_NOT_FOUND
            )
        
        if request.method == 'GET':
            serializer = self.get_serializer(profile)
            return Response(serializer.data)
        
        elif request.method in ['PUT', 'PATCH']:
            # Allow users to update their own profile
            logger.info(f"Updating profile for user {request.user.username}. Data: {request.data}")
            serializer = UserProfileUpdateSerializer(profile, data=request.data, partial=True)
            if serializer.is_valid():
                logger.info(f"Serializer is valid. Validated data: {serializer.validated_data}")
                # Save will update both UserProfile and User models
                serializer.save()
                
                # Refresh from database to get updated data
                profile.refresh_from_db()
                profile.user.refresh_from_db()
                
                logger.info(f"Profile updated. User first_name: {profile.user.first_name}, last_name: {profile.user.last_name}")
                
                # Return updated profile
                updated_serializer = UserProfileSerializer(profile)
                return Response(updated_serializer.data)
            logger.error(f"Serializer errors: {serializer.errors}")
            return Response(serializer.errors, status=status.HTTP_400_BAD_REQUEST)
    
    def get_queryset(self):
        queryset = super().get_queryset()
        # Filter by role if provided
        role = self.request.query_params.get('role', None)
        if role:
            queryset = queryset.filter(role=role)
        return queryset


@api_view(['POST'])
@permission_classes([AllowAny])
def register_user(request):
    """
    Register a new user
    """
    serializer = UserRegistrationSerializer(data=request.data)
    if serializer.is_valid():
        result = serializer.save()
        return Response(
            {
                'message': 'تم إنشاء الحساب بنجاح',
                'user': result['user'],
                'profile': result['profile'],
            },
            status=status.HTTP_201_CREATED
        )
    return Response(serializer.errors, status=status.HTTP_400_BAD_REQUEST)

@api_view(['POST'])
@permission_classes([IsAuthenticated])
def create_sub_account(request):
    """
    Lawyer creating a client or assistant account
    نظام إنشاء الحسابات الفرعية للموكلين أو المعاونين
    """
    try:
        if not hasattr(request.user, 'profile') or request.user.profile.role != UserProfile.ROLE_LAWYER:
            return Response({'error': 'هذا الإجراء متاح للمحامين فقط'}, status=status.HTTP_403_FORBIDDEN)
            
        phone = request.data.get('phone')
        full_name = request.data.get('full_name')
        role = request.data.get('role') # 'citizen' or 'assistant'
        password = request.data.get('password')
        
        if not phone or not full_name or not role:
            return Response({'error': 'رقم الهاتف، الاسم، والدور مطلوبان'}, status=status.HTTP_400_BAD_REQUEST)

        if not password or len(password) < 8:
            return Response({'error': 'كلمة المرور مطلوبة ويجب أن تكون 8 أحرف على الأقل'}, status=status.HTTP_400_BAD_REQUEST)

        # Use phone as username
        if User.objects.filter(username=phone).exists():
            return Response({'error': 'حساب بهذا الرقم موجود مسبقاً'}, status=status.HTTP_400_BAD_REQUEST)
            
        user = User.objects.create_user(
            username=phone,
            password=password,
            first_name=full_name
        )
        
        profile = user.profile
        profile.phone_number = phone
        profile.role = role
        profile.supervisor = request.user
        profile.save()
        
        return Response({
            'message': 'تم إنشاء الحساب بنجاح',
            'username': phone,
            'role': role,
            'role_display': profile.get_role_display()
        }, status=status.HTTP_201_CREATED)
    except Exception as e:
        logger.exception(f"Error creating sub-account: {e}")
        return Response({'error': str(e)}, status=status.HTTP_500_INTERNAL_SERVER_ERROR)


def _generate_otp():
    """Generate a 6-digit OTP code."""
    return ''.join(random.choices(string.digits, k=6))


def _find_user_by_phone(phone):
    """Find user by username or phone_number profile field."""
    user = User.objects.filter(username=phone).first()
    if not user:
        user = User.objects.filter(profile__phone_number=phone).first()
    return user


@api_view(['POST'])
@permission_classes([AllowAny])
def check_phone(request):
    """
    فحص رقم الهاتف — هل مسجل في قاعدة البيانات؟
    POST /api/register/check-phone/
    Body: { "phone": "771234567" }
    Response: { "exists": true/false }
    """
    phone = request.data.get('phone', '').strip()
    if not phone:
        return Response(
            {'error': 'رقم الهاتف مطلوب'},
            status=status.HTTP_400_BAD_REQUEST,
        )

    user = _find_user_by_phone(phone)
    return Response({'exists': user is not None})


@api_view(['POST'])
@permission_classes([AllowAny])
def quick_register(request):
    """
    تسجيل سريع برقم الهاتف فقط + إرسال OTP
    POST /api/register/quick-register/
    Body: { "phone": "771234567" }
    Response: { "message": "...", "otp_sent": true }
    """
    phone = request.data.get('phone', '').strip()
    if not phone:
        return Response(
            {'error': 'رقم الهاتف مطلوب'},
            status=status.HTTP_400_BAD_REQUEST,
        )

    # تحقق من عدم وجود الرقم مسبقاً
    if _find_user_by_phone(phone):
        return Response(
            {'error': 'هذا الرقم مسجل مسبقاً'},
            status=status.HTTP_400_BAD_REQUEST,
        )

    # إنشاء مستخدم بكلمة مرور عشوائية مؤقتة
    random_pass = ''.join(random.choices(string.ascii_letters + string.digits, k=16))
    user = User.objects.create_user(
        username=phone,
        password=random_pass,
        is_active=True,
    )

    # تحديث البروفايل
    profile = user.profile
    profile.phone_number = phone
    profile.role = UserProfile.ROLE_CITIZEN
    profile.save()

    # توليد OTP وحفظه في الكاش (صالح 5 دقائق)
    otp = _generate_otp()
    cache_key = f'otp_register_{phone}'
    cache.set(cache_key, otp, timeout=300)

    # طباعة الرمز في الكونسول (للتطوير — لاحقاً SMS/WhatsApp)
    logger.info(f'[OTP] رمز التحقق لـ {phone}: {otp}')
    print(f'\n{"="*50}')
    print(f'رمز التحقق OTP لـ {phone}: {otp}')
    print(f'{"="*50}\n')

    return Response({
        'message': 'تم إنشاء الحساب وإرسال رمز التحقق',
        'otp_sent': True,
    }, status=status.HTTP_201_CREATED)


@api_view(['POST'])
@permission_classes([AllowAny])
def verify_otp_login(request):
    """
    التحقق من رمز OTP وتسجيل الدخول (إرجاع JWT tokens)
    POST /api/register/verify-otp/
    Body: { "phone": "771234567", "code": "123456" }
    Response: { "access": "...", "refresh": "...", "is_new_user": true/false }
    """
    phone = request.data.get('phone', '').strip()
    code = request.data.get('code', '').strip()

    if not phone or not code:
        return Response(
            {'error': 'رقم الهاتف ورمز التحقق مطلوبان'},
            status=status.HTTP_400_BAD_REQUEST,
        )

    # التحقق من الرمز
    cache_key = f'otp_register_{phone}'
    stored_otp = cache.get(cache_key)

    if not stored_otp or stored_otp != code:
        return Response(
            {'error': 'رمز التحقق غير صحيح أو منتهي الصلاحية'},
            status=status.HTTP_400_BAD_REQUEST,
        )

    # حذف الرمز بعد الاستخدام
    cache.delete(cache_key)

    # البحث عن المستخدم
    user = _find_user_by_phone(phone)
    if not user:
        return Response(
            {'error': 'المستخدم غير موجود'},
            status=status.HTTP_404_NOT_FOUND,
        )

    # توليد JWT tokens
    refresh = RefreshToken.for_user(user)

    # إضافة بيانات إضافية للتوكن
    try:
        profile = user.profile
        refresh['role'] = profile.role
        refresh['is_active'] = profile.is_active
    except UserProfile.DoesNotExist:
        refresh['role'] = 'citizen'

    refresh['is_superuser'] = user.is_superuser
    refresh['username'] = user.username

    # هل المستخدم جديد (لا يوجد اسم أول)؟
    is_new = not user.first_name

    logger.info(f'[OTP Login] تسجيل دخول ناجح لـ {phone} (new={is_new})')

    return Response({
        'access': str(refresh.access_token),
        'refresh': str(refresh),
        'is_new_user': is_new,
    })


@api_view(['POST'])
@permission_classes([AllowAny])
def send_otp(request):
    """
    إرسال رمز OTP لمستخدم موجود أو جديد
    POST /api/register/send-otp/
    Body: { "phone": "771234567" }
    """
    phone = request.data.get('phone', '').strip()
    if not phone:
        return Response(
            {'error': 'رقم الهاتف مطلوب'},
            status=status.HTTP_400_BAD_REQUEST,
        )

    otp = _generate_otp()
    cache_key = f'otp_register_{phone}'
    cache.set(cache_key, otp, timeout=300)

    logger.info(f'[OTP] رمز التحقق لـ {phone}: {otp}')
    print(f'\n{"="*50}')
    print(f'رمز التحقق OTP لـ {phone}: {otp}')
    print(f'{"="*50}\n')

    return Response({
        'message': 'تم إرسال رمز التحقق',
        'otp_sent': True,
    })


@api_view(['POST'])
@permission_classes([IsAuthenticated])
def set_password(request):
    """
    تعيين كلمة مرور جديدة للمستخدم (بعد التسجيل عبر OTP).
    POST /api/register/set-password/
    Body: { "password": "NewPass@123", "confirm_password": "NewPass@123" }
    """
    password = request.data.get('password', '').strip()
    confirm = request.data.get('confirm_password', '').strip()

    if not password:
        return Response(
            {'error': 'كلمة المرور مطلوبة'},
            status=status.HTTP_400_BAD_REQUEST,
        )

    if len(password) < 8:
        return Response(
            {'error': 'كلمة المرور يجب أن تكون 8 أحرف على الأقل'},
            status=status.HTTP_400_BAD_REQUEST,
        )

    if password != confirm:
        return Response(
            {'error': 'كلمات المرور غير متطابقة'},
            status=status.HTTP_400_BAD_REQUEST,
        )

    user = request.user
    user.set_password(password)
    user.save()

    # إعادة توليد JWT tokens بعد تغيير كلمة المرور
    refresh = RefreshToken.for_user(user)
    try:
        profile = user.profile
        refresh['role'] = profile.role
        refresh['is_active'] = profile.is_active
    except UserProfile.DoesNotExist:
        refresh['role'] = 'citizen'

    refresh['is_superuser'] = user.is_superuser
    refresh['username'] = user.username

    logger.info(f'[SetPassword] تم تعيين كلمة مرور لـ {user.username}')

    return Response({
        'message': 'تم تعيين كلمة المرور بنجاح',
        'access': str(refresh.access_token),
        'refresh': str(refresh),
    })


@api_view(['POST'])
@permission_classes([AllowAny])
def reset_password_otp(request):
    """
    إعادة تعيين كلمة المرور بعد التحقق من OTP (نسيت كلمة المرور).
    POST /api/register/reset-password/
    Body: { "phone": "771234567", "code": "123456", "new_password": "..." }
    """
    phone = request.data.get('phone', '').strip()
    code = request.data.get('code', '').strip()
    new_password = request.data.get('new_password', '').strip()

    if not phone or not code or not new_password:
        return Response(
            {'error': 'رقم الهاتف ورمز التحقق وكلمة المرور الجديدة مطلوبة'},
            status=status.HTTP_400_BAD_REQUEST,
        )

    if len(new_password) < 8:
        return Response(
            {'error': 'كلمة المرور يجب أن تكون 8 أحرف على الأقل'},
            status=status.HTTP_400_BAD_REQUEST,
        )

    # Verify OTP
    cache_key = f'otp_register_{phone}'
    stored_otp = cache.get(cache_key)

    if not stored_otp or stored_otp != code:
        return Response(
            {'error': 'رمز التحقق غير صحيح أو منتهي الصلاحية'},
            status=status.HTTP_400_BAD_REQUEST,
        )

    cache.delete(cache_key)

    # Find user
    user = _find_user_by_phone(phone)
    if not user:
        return Response(
            {'error': 'المستخدم غير موجود'},
            status=status.HTTP_404_NOT_FOUND,
        )

    # Set new password
    user.set_password(new_password)
    user.save()

    # Generate new JWT tokens
    refresh = RefreshToken.for_user(user)
    try:
        profile = user.profile
        refresh['role'] = profile.role
        refresh['is_active'] = profile.is_active
    except UserProfile.DoesNotExist:
        refresh['role'] = 'citizen'

    refresh['is_superuser'] = user.is_superuser
    refresh['username'] = user.username

    logger.info(f'[ResetPassword] Password reset via OTP for {phone}')

    return Response({
        'message': 'تم تغيير كلمة المرور بنجاح',
        'access': str(refresh.access_token),
        'refresh': str(refresh),
    })
