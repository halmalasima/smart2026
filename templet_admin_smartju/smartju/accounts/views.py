from rest_framework import viewsets, status
from rest_framework.decorators import action, api_view, permission_classes
from rest_framework.response import Response
from rest_framework.permissions import IsAuthenticated, IsAdminUser, AllowAny
from django.contrib.auth.models import User
from .models import UserProfile
from .serializers import (
    UserProfileSerializer, UserProfileCreateSerializer, UserProfileUpdateSerializer,
    UserRegistrationSerializer
)
from .permissions import IsJudgeOrAdmin
import logging

logger = logging.getLogger(__name__)


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
