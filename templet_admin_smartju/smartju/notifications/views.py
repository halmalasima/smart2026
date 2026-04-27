from rest_framework import status
from rest_framework.decorators import api_view, permission_classes
from rest_framework.permissions import IsAuthenticated
from rest_framework.response import Response
from .models import Notification
from .serializers import NotificationSerializer


@api_view(["GET", "HEAD"])
@permission_classes([IsAuthenticated])
def notifications_list(request):
    """List notifications for the current user with pagination."""
    qs = Notification.objects.filter(recipient=request.user)
    unread_count = qs.filter(is_read=False).count()

    # Simple manual pagination
    page = int(request.query_params.get('page', 1))
    page_size = int(request.query_params.get('page_size', 20))
    start = (page - 1) * page_size
    end = start + page_size

    notifications = qs[start:end]
    serializer = NotificationSerializer(notifications, many=True)

    return Response({
        "success": True,
        "data": {
            "results": serializer.data,
            "count": qs.count(),
            "unread_count": unread_count,
        },
    })


@api_view(["POST"])
@permission_classes([IsAuthenticated])
def notifications_mark_all_read(request):
    """Mark all notifications as read for the current user."""
    updated = Notification.objects.filter(
        recipient=request.user, is_read=False
    ).update(is_read=True)
    return Response({"success": True, "updated": updated})


@api_view(["PATCH", "DELETE"])
@permission_classes([IsAuthenticated])
def notifications_detail(request, pk):
    """Mark a single notification as read or delete it."""
    try:
        notification = Notification.objects.get(pk=pk, recipient=request.user)
    except Notification.DoesNotExist:
        return Response(
            {"error": "الإشعار غير موجود"},
            status=status.HTTP_404_NOT_FOUND,
        )

    if request.method == "DELETE":
        notification.delete()
        return Response(status=status.HTTP_204_NO_CONTENT)

    # PATCH — mark as read
    notification.is_read = True
    notification.save(update_fields=["is_read"])
    serializer = NotificationSerializer(notification)
    return Response({"success": True, "data": serializer.data})
