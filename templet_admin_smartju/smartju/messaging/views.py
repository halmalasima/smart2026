from rest_framework import viewsets, permissions, status
from rest_framework.decorators import action
from rest_framework.response import Response
from django.db.models import Q
from .models import Message
from .serializers import MessageSerializer

class MessageViewSet(viewsets.ModelViewSet):
    """
    ViewSet for Lawyer-Client messaging
    """
    serializer_class = MessageSerializer
    permission_classes = [permissions.IsAuthenticated]

    def get_queryset(self):
        user = self.request.user
        # Users can see messages they sent or received
        return Message.objects.filter(Q(sender=user) | Q(recipient=user))

    def perform_create(self, serializer):
        # Automatically set sender to the current user
        serializer.save(sender=self.request.user)

    @action(detail=False, methods=['get'], url_path='lawsuit/(?P<lawsuit_id>[0-9]+)')
    def by_lawsuit(self, request, lawsuit_id=None):
        """
        Get messages related to a specific lawsuit
        """
        messages = self.get_queryset().filter(lawsuit_id=lawsuit_id)
        serializer = self.get_serializer(messages, many=True)
        return Response(serializer.data)

    @action(detail=True, methods=['post'])
    def mark_read(self, request, pk=None):
        """
        Mark a message as read
        """
        message = self.get_object()
        if message.recipient == request.user:
            message.is_read = True
            message.save()
            return Response({'status': 'message read'})
        return Response({'error': 'Unauthorized'}, status=status.HTTP_403_FORBIDDEN)
