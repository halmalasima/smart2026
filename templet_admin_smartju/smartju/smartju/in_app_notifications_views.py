"""
واجهات إشعارات داخل التطبيق — نسخة أولية (قائمة فارغة) حتى يُبنى نموذج إشعارات كامل.
تمنع إرجاع صفحة HTML 404 التي كانت تسبب FormatException في Flutter.
"""

from rest_framework.decorators import api_view, permission_classes
from rest_framework.permissions import IsAuthenticated
from rest_framework.response import Response


@api_view(["GET", "HEAD"])
@permission_classes([IsAuthenticated])
def notifications_list(request):
    return Response(
        {
            "success": True,
            "data": {"results": [], "count": 0},
        }
    )


@api_view(["POST"])
@permission_classes([IsAuthenticated])
def notifications_mark_all_read(request):
    return Response({"success": True})


@api_view(["PATCH", "DELETE"])
@permission_classes([IsAuthenticated])
def notifications_detail(request, pk):
    if request.method == "DELETE":
        return Response(status=204)
    return Response(
        {
            "success": True,
            "data": {"id": str(pk), "is_read": True},
        }
    )
