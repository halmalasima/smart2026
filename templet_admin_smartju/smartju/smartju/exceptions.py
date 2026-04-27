"""
Custom exception handler for REST API
Provides consistent error response format for Flutter integration
"""
from rest_framework.views import exception_handler
from rest_framework import status
from rest_framework.response import Response
from django.core.exceptions import ValidationError
from django.db import IntegrityError


def custom_exception_handler(exc, context):
    """
    Custom exception handler that returns consistent error format
    """
    # Call REST framework's default exception handler first
    response = exception_handler(exc, context)
    
    # Custom format for errors
    if response is not None:
        custom_response_data = {
            'success': False,
            'error': {
                'code': response.status_code,
                'message': 'An error occurred',
                'details': {}
            },
            'data': None
        }
        
        # Handle different error types
        if hasattr(response, 'data'):
            error_data = response.data
            
            # Handle validation errors
            if isinstance(error_data, dict):
                if 'detail' in error_data:
                    # Single error message
                    custom_response_data['error']['message'] = str(error_data['detail'])
                else:
                    # Field validation errors
                    custom_response_data['error']['message'] = 'Validation error'
                    custom_response_data['error']['details'] = error_data
            elif isinstance(error_data, list):
                # List of errors
                custom_response_data['error']['message'] = error_data[0] if error_data else 'An error occurred'
                custom_response_data['error']['details'] = {'errors': error_data}
        
        response.data = custom_response_data
    
    # Handle Django validation errors
    elif isinstance(exc, ValidationError):
        response = Response(
            {
                'success': False,
                'error': {
                    'code': status.HTTP_400_BAD_REQUEST,
                    'message': 'Validation error',
                    'details': exc.message_dict if hasattr(exc, 'message_dict') else {'errors': str(exc)}
                },
                'data': None
            },
            status=status.HTTP_400_BAD_REQUEST
        )
    
    # Handle database integrity errors
    elif isinstance(exc, IntegrityError):
        response = Response(
            {
                'success': False,
                'error': {
                    'code': status.HTTP_400_BAD_REQUEST,
                    'message': 'Database integrity error',
                    'details': {'error': str(exc)}
                },
                'data': None
            },
            status=status.HTTP_400_BAD_REQUEST
        )
    
    return response

