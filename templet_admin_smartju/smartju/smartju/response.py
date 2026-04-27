"""
Helper functions for consistent API responses
"""
from rest_framework.response import Response
from rest_framework import status


def success_response(data=None, message='Success', status_code=status.HTTP_200_OK):
    """
    Return a standardized success response
    """
    return Response({
        'success': True,
        'data': data,
        'message': message,
        'error': None
    }, status=status_code)


def error_response(message='An error occurred', details=None, status_code=status.HTTP_400_BAD_REQUEST):
    """
    Return a standardized error response
    """
    return Response({
        'success': False,
        'data': None,
        'error': {
            'code': status_code,
            'message': message,
            'details': details or {}
        }
    }, status=status_code)

