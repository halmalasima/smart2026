import urllib.request
import urllib.parse
import json
from rest_framework import viewsets, status
from rest_framework.decorators import action, api_view, permission_classes
from rest_framework.response import Response
from rest_framework.permissions import IsAuthenticated, IsAdminUser, AllowAny
from django.contrib.auth.models import User
from django.conf import settings
from .models import UserProfile, OTPCode
from .serializers import (
    UserProfileSerializer, UserProfileCreateSerializer, UserProfileUpdateSerializer,
    UserRegistrationSerializer
)
from .permissions import IsJudgeOrAdmin
import logging

logger = logging.getLogger(__name__)


def _send_otp_sms(user, otp_code, purpose):
    """إرسال رمز التحقق عبر SMS باستخدام sms.arsi.fun API"""
    try:
        # Get phone number from user profile
        phone_number = None
        if hasattr(user, 'profile') and user.profile.phone_number:
            phone_number = user.profile.phone_number
        else:
            # Try to get from registration data (phone number may be in user.email temporarily)
            phone_number = getattr(user, 'phone_number', None)
        
        if not phone_number:
            logger.error(f'No phone number found for user {user.username}')
            return False
        
        # Format phone number with 967 prefix (no + sign)
        phone_number = phone_number.lstrip('+')
        if phone_number.startswith('967'):
            pass  # already has country code
        elif phone_number.startswith('7') and len(phone_number) == 9:
            phone_number = '967' + phone_number
        else:
            phone_number = '967' + phone_number
        
        # Prepare message
        if purpose == OTPCode.PURPOSE_VERIFY_EMAIL:
            message = f'منصة القضاء الذكية: رمز التحقق الخاص بك هو {otp_code.code}. صالح لمدة 10 دقائق.'
        else:
            message = f'منصة القضاء الذكية: رمز استعادة كلمة المرور هو {otp_code.code}. صالح لمدة 10 دقائق.'
        
        # SMS API configuration
        sms_api_url = getattr(settings, 'SMS_API_URL', 'https://sms.arsi.fun/api')
        sms_api_key = getattr(settings, 'SMS_API_KEY', '609aef4d393812a330427ed473bc14b0')
        sms_device_id = getattr(settings, 'SMS_DEVICE_ID', '5')
        sms_sim = str(getattr(settings, 'SMS_SIM', '6'))
        
        # Call SMS API using multipart/form-data (same as PHP curl with array)
        try:
            import uuid
            boundary = uuid.uuid4().hex
            fields = {
                'content': message,
                'device_id': sms_device_id,
                'sim_subscription_id': sms_sim,
                'phone_numbers': phone_number,
            }
            body = b''
            for key, value in fields.items():
                body += f'--{boundary}\r\n'.encode('utf-8')
                body += f'Content-Disposition: form-data; name="{key}"\r\n\r\n'.encode('utf-8')
                body += f'{value}\r\n'.encode('utf-8')
            body += f'--{boundary}--\r\n'.encode('utf-8')

            req = urllib.request.Request(
                f'{sms_api_url}/sms',
                data=body,
                headers={
                    'Authorization': f'Bearer {sms_api_key}',
                    'Content-Type': f'multipart/form-data; boundary={boundary}',
                },
                method='POST',
            )
            
            with urllib.request.urlopen(req, timeout=30) as response:
                response_data = json.loads(response.read().decode('utf-8'))
                if response_data.get('success') or response_data.get('data', {}).get('sms_ids'):
                    logger.info(f'SMS OTP sent successfully to {phone_number}')
                    return True
                else:
                    logger.error(f'SMS API error: {response_data}')
                    return False
        except urllib.error.HTTPError as e:
            logger.error(f'SMS API HTTP error: {e.code} - {e.reason}')
            return False
        except urllib.error.URLError as e:
            logger.error(f'SMS API URL error: {e.reason}')
            return False
        except Exception as e:
            logger.error(f'SMS API unexpected error: {e}')
            return False
    except Exception as e:
        logger.error(f'Failed to send OTP SMS: {e}')
        return False


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
            real_user = User.objects.select_related('profile').get(pk=request.user.id)
            profile = real_user.profile
        except User.DoesNotExist:
            return Response({'detail': 'User not found'}, status=status.HTTP_404_NOT_FOUND)
        except UserProfile.DoesNotExist:
            profile = UserProfile.objects.create(
                user=real_user,
                role=UserProfile.ROLE_ADMIN if real_user.is_superuser else UserProfile.ROLE_CITIZEN
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
    Register a new user and send email verification OTP
    """
    serializer = UserRegistrationSerializer(data=request.data)
    if serializer.is_valid():
        result = serializer.save()
        # Deactivate user until email is verified
        user = User.objects.get(pk=result['user']['id'])
        user.is_active = False
        user.save(update_fields=['is_active'])
        # Create and send OTP via SMS
        otp = OTPCode.create_otp(user, OTPCode.PURPOSE_VERIFY_EMAIL)
        sms_sent = _send_otp_sms(user, otp, OTPCode.PURPOSE_VERIFY_EMAIL)
        return Response(
            {
                'message': 'تم إنشاء الحساب. يرجى إدخال رمز التحقق المرسل إلى هاتفك',
                'user': result['user'],
                'profile': result['profile'],
                'sms_sent': sms_sent,
                'requires_verification': True,
            },
            status=status.HTTP_201_CREATED
        )
    return Response(serializer.errors, status=status.HTTP_400_BAD_REQUEST)


@api_view(['POST'])
@permission_classes([AllowAny])
def verify_email(request):
    """
    Verify OTP code for phone verification
    """
    phone = request.data.get('phone', request.data.get('email', '')).strip()
    code = request.data.get('code', '').strip()
    if not phone or not code:
        return Response({'error': 'رقم الهاتف ورمز التحقق مطلوبان'}, status=status.HTTP_400_BAD_REQUEST)
    
    # Find user by phone number (use latest created for verification)
    user = User.objects.filter(profile__phone_number=phone).order_by('-date_joined').first()
    if not user:
        return Response({'error': 'لم يتم العثور على حساب بهذا الرقم'}, status=status.HTTP_404_NOT_FOUND)

    # Verify OTP
    try:
        otp = OTPCode.objects.filter(user=user, purpose=OTPCode.PURPOSE_VERIFY_EMAIL, is_used=False).latest('created_at')
    except OTPCode.DoesNotExist:
        return Response({'error': 'رمز التحقق غير صالح أو منتهي الصلاحية'}, status=status.HTTP_400_BAD_REQUEST)

    if otp.is_expired:
        return Response({'error': 'رمز التحقق منتهي الصلاحية'}, status=status.HTTP_400_BAD_REQUEST)

    if otp.code != code:
        return Response({'error': 'رمز التحقق غير صحيح'}, status=status.HTTP_400_BAD_REQUEST)

    # Mark OTP as used
    otp.is_used = True
    otp.save(update_fields=['is_used'])

    # Activate user
    user.is_active = True
    user.save(update_fields=['is_active'])

    return Response({'message': 'تم تفعيل الحساب بنجاح. يمكنك تسجيل الدخول الآن.'})


@api_view(['POST'])
@permission_classes([AllowAny])
def resend_otp(request):
    """
    Resend OTP code for phone verification or password reset
    """
    phone = request.data.get('phone', request.data.get('email', '')).strip()
    purpose = request.data.get('purpose', OTPCode.PURPOSE_VERIFY_EMAIL)
    if not phone:
        return Response({'error': 'رقم الهاتف مطلوب'}, status=status.HTTP_400_BAD_REQUEST)
    user = User.objects.filter(profile__phone_number=phone).order_by('-date_joined').first()
    if not user:
        return Response({'error': 'لم يتم العثور على حساب بهذا الرقم'}, status=status.HTTP_404_NOT_FOUND)

    otp = OTPCode.create_otp(user, purpose)
    sms_sent = _send_otp_sms(user, otp, purpose)
    return Response({
        'message': 'تم إرسال رمز تحقق جديد',
        'sms_sent': sms_sent,
    })


@api_view(['POST'])
@permission_classes([AllowAny])
def request_password_reset(request):
    """
    Request password reset - sends OTP via SMS
    """
    phone = request.data.get('phone', request.data.get('email', '')).strip()
    if not phone:
        return Response({'error': 'رقم الهاتف مطلوب'}, status=status.HTTP_400_BAD_REQUEST)
    user = User.objects.filter(profile__phone_number=phone).order_by('-date_joined').first()
    if not user:
        return Response({'error': 'لا يوجد حساب بهذا الرقم'}, status=status.HTTP_404_NOT_FOUND)

    otp = OTPCode.create_otp(user, OTPCode.PURPOSE_RESET_PASSWORD)
    _send_otp_sms(user, otp, OTPCode.PURPOSE_RESET_PASSWORD)
    return Response({'message': 'إذا كان الرقم مسجلاً، سيتم إرسال رمز التحقق إلى هاتفك.'})


@api_view(['POST'])
@permission_classes([AllowAny])
def verify_reset_otp(request):
    """
    Verify OTP code for password reset (step 1 of 2)
    """
    phone = request.data.get('phone', request.data.get('email', '')).strip()
    code = request.data.get('code', '').strip()
    if not phone or not code:
        return Response({'error': 'رقم الهاتف ورمز التحقق مطلوبان'}, status=status.HTTP_400_BAD_REQUEST)
    user = User.objects.filter(profile__phone_number=phone).order_by('-date_joined').first()
    if not user:
        return Response({'error': 'بيانات غير صحيحة'}, status=status.HTTP_400_BAD_REQUEST)

    otp = OTPCode.objects.filter(
        user=user,
        code=code,
        purpose=OTPCode.PURPOSE_RESET_PASSWORD,
        is_used=False,
    ).order_by('-created_at').first()

    if not otp or not otp.is_valid:
        return Response({'error': 'رمز التحقق غير صحيح أو منتهي الصلاحية'}, status=status.HTTP_400_BAD_REQUEST)

    # Don't mark as used yet - will be used in reset_password
    return Response({'message': 'رمز التحقق صحيح', 'valid': True})


@api_view(['POST'])
@permission_classes([AllowAny])
def reset_password(request):
    """
    Reset password with verified OTP (step 2 of 2)
    """
    phone = request.data.get('phone', request.data.get('email', '')).strip()
    code = request.data.get('code', '').strip()
    new_password = request.data.get('new_password', '')
    if not phone or not code or not new_password:
        return Response({'error': 'جميع الحقول مطلوبة'}, status=status.HTTP_400_BAD_REQUEST)
    if len(new_password) < 6:
        return Response({'error': 'كلمة المرور يجب أن تكون 6 أحرف على الأقل'}, status=status.HTTP_400_BAD_REQUEST)

    user = User.objects.filter(profile__phone_number=phone).order_by('-date_joined').first()
    if not user:
        return Response({'error': 'بيانات غير صحيحة'}, status=status.HTTP_400_BAD_REQUEST)

    otp = OTPCode.objects.filter(
        user=user,
        code=code,
        purpose=OTPCode.PURPOSE_RESET_PASSWORD,
        is_used=False,
    ).order_by('-created_at').first()

    if not otp or not otp.is_valid:
        return Response({'error': 'رمز التحقق غير صحيح أو منتهي الصلاحية'}, status=status.HTTP_400_BAD_REQUEST)

    otp.is_used = True
    otp.save(update_fields=['is_used'])
    user.set_password(new_password)
    user.save(update_fields=['password'])

    return Response({'message': 'تم تغيير كلمة المرور بنجاح. يمكنك تسجيل الدخول الآن.'})

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


# ═══════════════════════════════════════════════════════════
# Phone-First Auth Flow
# ═══════════════════════════════════════════════════════════

def _find_user_by_phone(phone):
    """Find user by username or phone_number profile field."""
    user = User.objects.filter(username=phone).first()
    if not user:
        user = User.objects.filter(profile__phone_number=phone).first()
    return user


@api_view(['POST'])
@permission_classes([AllowAny])
def check_phone(request):
    """فحص رقم الهاتف — هل مسجل في قاعدة البيانات؟"""
    phone = request.data.get('phone', '').strip()
    if not phone:
        return Response({'error': 'رقم الهاتف مطلوب'}, status=status.HTTP_400_BAD_REQUEST)
    user = _find_user_by_phone(phone)
    return Response({'exists': user is not None})


@api_view(['POST'])
@permission_classes([AllowAny])
def quick_register(request):
    """تسجيل سريع برقم الهاتف فقط + إرسال OTP"""
    import random, string
    phone = request.data.get('phone', '').strip()
    if not phone:
        return Response({'error': 'رقم الهاتف مطلوب'}, status=status.HTTP_400_BAD_REQUEST)

    if _find_user_by_phone(phone):
        return Response({'error': 'هذا الرقم مسجل مسبقاً'}, status=status.HTTP_400_BAD_REQUEST)

    random_pass = ''.join(random.choices(string.ascii_letters + string.digits, k=16))
    user = User.objects.create_user(username=phone, password=random_pass, is_active=True)

    profile = user.profile
    profile.phone_number = phone
    profile.role = UserProfile.ROLE_CITIZEN
    profile.save()

    otp = OTPCode.create_otp(user, OTPCode.PURPOSE_VERIFY_EMAIL)
    sms_sent = _send_otp_sms(user, otp, OTPCode.PURPOSE_VERIFY_EMAIL)

    logger.info(f'📱 [Quick Register] OTP for {phone}: {otp.code}')
    return Response({
        'message': 'تم إنشاء الحساب وإرسال رمز التحقق',
        'otp_sent': True,
        'sms_sent': sms_sent,
    }, status=status.HTTP_201_CREATED)


@api_view(['POST'])
@permission_classes([AllowAny])
def verify_otp_login(request):
    """التحقق من رمز OTP وتسجيل الدخول (إرجاع JWT tokens)"""
    from rest_framework_simplejwt.tokens import RefreshToken

    phone = request.data.get('phone', '').strip()
    code = request.data.get('code', '').strip()
    if not phone or not code:
        return Response({'error': 'رقم الهاتف ورمز التحقق مطلوبان'}, status=status.HTTP_400_BAD_REQUEST)

    user = _find_user_by_phone(phone)
    if not user:
        return Response({'error': 'المستخدم غير موجود'}, status=status.HTTP_404_NOT_FOUND)

    # Verify OTP
    otp = OTPCode.objects.filter(
        user=user, purpose=OTPCode.PURPOSE_VERIFY_EMAIL, is_used=False
    ).order_by('-created_at').first()

    if not otp or otp.is_expired or otp.code != code:
        return Response({'error': 'رمز التحقق غير صحيح أو منتهي الصلاحية'}, status=status.HTTP_400_BAD_REQUEST)

    otp.is_used = True
    otp.save(update_fields=['is_used'])

    # Activate user if not active
    if not user.is_active:
        user.is_active = True
        user.save(update_fields=['is_active'])

    # Generate JWT
    refresh = RefreshToken.for_user(user)
    try:
        profile = user.profile
        refresh['role'] = profile.role
        refresh['is_active'] = profile.is_active
    except UserProfile.DoesNotExist:
        refresh['role'] = 'citizen'
    refresh['is_superuser'] = user.is_superuser
    refresh['username'] = user.username

    is_new = not user.first_name
    logger.info(f'✅ [OTP Login] {phone} (new={is_new})')

    return Response({
        'access': str(refresh.access_token),
        'refresh': str(refresh),
        'is_new_user': is_new,
    })


@api_view(['POST'])
@permission_classes([AllowAny])
def send_otp(request):
    """إرسال / إعادة إرسال رمز OTP"""
    phone = request.data.get('phone', '').strip()
    if not phone:
        return Response({'error': 'رقم الهاتف مطلوب'}, status=status.HTTP_400_BAD_REQUEST)

    user = _find_user_by_phone(phone)
    if not user:
        return Response({'error': 'المستخدم غير موجود'}, status=status.HTTP_404_NOT_FOUND)

    otp = OTPCode.create_otp(user, OTPCode.PURPOSE_VERIFY_EMAIL)
    sms_sent = _send_otp_sms(user, otp, OTPCode.PURPOSE_VERIFY_EMAIL)

    logger.info(f'📱 [Send OTP] for {phone}: {otp.code}')
    return Response({'message': 'تم إرسال رمز التحقق', 'otp_sent': True, 'sms_sent': sms_sent})

