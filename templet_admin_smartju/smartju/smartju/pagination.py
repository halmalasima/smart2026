"""
Custom pagination for consistent API responses
"""
from rest_framework.pagination import PageNumberPagination
from rest_framework.response import Response


class StandardResultsSetPagination(PageNumberPagination):
    """
    Standard pagination with consistent format for Flutter
    """
    page_size = 20
    page_size_query_param = 'page_size'
    max_page_size = 100
    
    def get_paginated_response(self, data):
        """
        Return a paginated style Response object with consistent format
        Note: 'data' parameter from parent class contains the list of results
        """
        # Build standard pagination response
        paginated_data = {
            'count': self.page.paginator.count,
            'next': self.get_next_link(),
            'previous': self.get_previous_link(),
            'results': data  # The actual list of results
        }
        
        return Response({
            'success': True,
            'data': paginated_data,  # Wrap in 'data' with standard pagination format
            'pagination': {
                'count': self.page.paginator.count,
                'next': self.get_next_link(),
                'previous': self.get_previous_link(),
                'current_page': self.page.number,
                'total_pages': self.page.paginator.num_pages,
                'page_size': self.page_size,
            },
            'error': None
        })

