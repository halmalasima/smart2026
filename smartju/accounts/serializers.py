from rest_framework import serializers
from django.contrib.auth.models import User
from .models import UserProfile
from rest_framework_simplejwt.serializers import TokenObtainPairSerializer
import logging

logger = logging.getLogger(__name__)


class UserSerializer(serializers.ModelSerializer):
    """
    Serializer for Django User model
    """
    class Meta:
        model = User
        fields = ('id', 'username', 'email', 'first_name', 'last_name')
        read_only_fields = ('id',)


class UserProfileSerializer(serializers.ModelSerializer):
    """
    Serializer for UserProfile model
    """
    user = UserSerializer(read_only=True)
    role_display = serializers.CharField(source='get_role_display', read_only=True)
    # Include user fields directly for easier access
    username = serializers.CharField(source='user.username', read_only=True)
    email = serializers.EmailField(source='user.email', read_only=True)
    first_name = serializers.CharField(source='user.first_name', read_only=True)
    last_name = serializers.CharField(source='user.last_name', read_only=True)
    
    class Meta:
        model = UserProfile
        fields = (
            'id', 'user', 'username', 'email', 'first_name', 'last_name',
            'role', 'role_display', 'phone_number', 
            'national_id', 'is_active', 'created_at', 'updated_at'
        )
        read_only_fields = ('id', 'created_at', 'updated_at')


class UserProfileCreateSerializer(serializers.ModelSerializer):
    """
    Serializer for creating UserProfile
    """
    class Meta:
        model = UserProfile
        fields = ('role', 'phone_number', 'national_id')


class UserProfileUpdateSerializer(serializers.ModelSerializer):
    """
    Serializer for updating UserProfile
    Allows updating user fields as well
    """
    first_name = serializers.CharField(source='user.first_name', required=False, allow_blank=True)
    last_name = serializers.CharField(source='user.last_name', required=False, allow_blank=True)
    email = serializers.EmailField(source='user.email', required=False)
    
    class Meta:
        model = UserProfile
        fields = ('phone_number', 'national_id', 'first_name', 'last_name', 'email')
    
    def update(self, instance, validated_data):
        logger.info(f"Updating profile. Validated data: {validated_data}")
        
        # Update UserProfile fields
        if 'phone_number' in validated_data:
            instance.phone_number = validated_data.get('phone_number') or None
        if 'national_id' in validated_data:
            instance.national_id = validated_data.get('national_id') or None
        
        # Update User fields
        # Because of source='user.first_name', validated_data will have 'user' key
        user_data = validated_data.pop('user', {})
        logger.info(f"User data extracted: {user_data}")
        
        user = instance.user
        user_updated = False
        
        # Update user fields if provided
        if user_data:
            if 'first_name' in user_data:
                old_first_name = user.first_name
                user.first_name = user_data['first_name'] or ''
                logger.info(f"Updating first_name from '{old_first_name}' to '{user.first_name}'")
                user_updated = True
            if 'last_name' in user_data:
                old_last_name = user.last_name
                user.last_name = user_data['last_name'] or ''
                logger.info(f"Updating last_name from '{old_last_name}' to '{user.last_name}'")
                user_updated = True
            if 'email' in user_data:
                old_email = user.email
                user.email = user_data['email']
                logger.info(f"Updating email from '{old_email}' to '{user.email}'")
                user_updated = True
            
            # Save user if any fields were updated
            if user_updated:
                user.save()
                logger.info(f"User saved. New values: first_name='{user.first_name}', last_name='{user.last_name}', email='{user.email}'")
        
        # Save profile
        instance.save()
        return instance


class UserRegistrationSerializer(serializers.Serializer):
    """
    Serializer for user registration
    """
    username = serializers.CharField(max_length=150, required=True)
    email = serializers.EmailField(required=True)
    password = serializers.CharField(write_only=True, required=True, min_length=6)
    first_name = serializers.CharField(max_length=30, required=False, allow_blank=True)
    last_name = serializers.CharField(max_length=30, required=False, allow_blank=True)
    role = serializers.ChoiceField(choices=UserProfile.ROLE_CHOICES, default=UserProfile.ROLE_CITIZEN)
    phone_number = serializers.CharField(max_length=20, required=False, allow_blank=True)
    national_id = serializers.CharField(max_length=20, required=False, allow_blank=True)
    
    def validate_username(self, value):
        if User.objects.filter(username=value).exists():
            raise serializers.ValidationError("اسم المستخدم موجود بالفعل")
        return value
    
    def validate_email(self, value):
        if User.objects.filter(email=value).exists():
            raise serializers.ValidationError("البريد الإلكتروني موجود بالفعل")
        return value
    
    def validate_national_id(self, value):
        if value and UserProfile.objects.filter(national_id=value).exists():
            raise serializers.ValidationError("الرقم الوطني موجود بالفعل")
        return value
    
    def create(self, validated_data):
        # Create User
        user = User.objects.create_user(
            username=validated_data['username'],
            email=validated_data['email'],
            password=validated_data['password'],
            first_name=validated_data.get('first_name', ''),
            last_name=validated_data.get('last_name', ''),
        )
        
        # Get or Update UserProfile (it's automatically created by a signal in models.py)
        profile, _ = UserProfile.objects.get_or_create(user=user)
        profile.role = validated_data.get('role', UserProfile.ROLE_CITIZEN)
        profile.phone_number = validated_data.get('phone_number') or None
        profile.national_id = validated_data.get('national_id') or None
        profile.save()
        
        return {
            'user': UserSerializer(user).data,
            'profile': UserProfileSerializer(profile).data,
        }


class CustomTokenObtainPairSerializer(TokenObtainPairSerializer):
    """
    Custom JWT serializer that supports login by phone number or username.
    
    Resolution strategy:
    1. Try username + password directly via super().validate()
    2. If that fails, look up by phone_number and retry with the resolved username
    3. Provide clear Arabic error messages for each failure case
    """
    def validate(self, attrs):
        raw_input = attrs.get(self.username_field, '')
        password = attrs.get('password', '')

        logger.info(f"Login attempt for: {raw_input}")

        # ── Strategy 1: Try the input as-is (direct username match) ──
        try:
            result = super().validate(attrs)
            logger.info(f"Login success via direct username: {raw_input}")
            return result
        except Exception as direct_error:
            logger.info(f"Direct username login failed: {direct_error}")

        # ── Strategy 2: Resolve by phone number and retry ──
        phone_user = User.objects.filter(profile__phone_number=raw_input).first()
        if phone_user:
            logger.info(f"Found user by phone {raw_input} -> username: {phone_user.username}")
            
            # Check account status first for clear error messages
            if not phone_user.is_active:
                raise serializers.ValidationError(
                    {'detail': 'الحساب غير نشط. تواصل مع الدعم الفني.'},
                    code='account_inactive'
                )
            
            # Retry authentication with the resolved username
            attrs[self.username_field] = phone_user.username
            try:
                result = super().validate(attrs)
                logger.info(f"Login success via phone resolution: {raw_input} -> {phone_user.username}")
                return result
            except Exception:
                logger.info(f"Password incorrect for phone-resolved user: {phone_user.username}")
                raise serializers.ValidationError(
                    {'detail': 'كلمة المرور غير صحيحة.'},
                    code='wrong_password'
                )

        # ── No user found at all ──
        # Check if a user exists with this username but password was wrong
        direct_user = User.objects.filter(username=raw_input).first()
        if direct_user:
            if not direct_user.is_active:
                raise serializers.ValidationError(
                    {'detail': 'الحساب غير نشط. تواصل مع الدعم الفني.'},
                    code='account_inactive'
                )
            raise serializers.ValidationError(
                {'detail': 'كلمة المرور غير صحيحة.'},
                code='wrong_password'
            )

        # Truly no user found
        raise serializers.ValidationError(
            {'detail': 'لا يوجد حساب بهذا الرقم. قم بإنشاء حساب جديد.'},
            code='no_account'
        )

    @classmethod
    def get_token(cls, user):
        token = super().get_token(user)
        try:
            profile = user.profile
            token['role'] = profile.role
            token['is_active'] = profile.is_active
        except:
            token['role'] = 'citizen'
            
        token['is_superuser'] = user.is_superuser
        token['username'] = user.username
        return token
