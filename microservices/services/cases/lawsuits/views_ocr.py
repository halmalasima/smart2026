import logging
from rest_framework.views import APIView
from rest_framework.response import Response
from rest_framework.permissions import IsAuthenticated
from rest_framework.parsers import MultiPartParser, FormParser
from rest_framework import status
import pytesseract
from PIL import Image
import io

logger = logging.getLogger(__name__)

class ExtractTextView(APIView):
    """
    API view to extract text from an uploaded image using OCR (Tesseract).
    """
    parser_classes = (MultiPartParser, FormParser)
    permission_classes = [AllowAny]

    def get(self, request):
        return Response({"status": "ok", "message": "OCR endpoint is reachable. Use POST to extract text."}, status=200)

    def post(self, request, *args, **kwargs):
        image_file = request.FILES.get('file') or request.FILES.get('image')
        if not image_file:
            return Response({"error": "No image provided. Use 'file' or 'image' key."}, status=400)
        
        try:
            # Read image
            image_bytes = image_file.read()
            img = Image.open(io.BytesIO(image_bytes))
            
            # Use Arabic and English for better recognition, especially for Yemeni legal documents
            extracted_text = pytesseract.image_to_string(img, lang='ara+eng')
            
            if not extracted_text.strip():
                return Response(
                    {'text': '', 'message': 'لم يتم العثور على نص واضح في الصورة'},
                    status=status.HTTP_200_OK
                )
                
            return Response(
                {'text': extracted_text.strip(), 'message': 'تم استخراج النص بنجاح'},
                status=status.HTTP_200_OK
            )
            
        except Exception as e:
            logger.error(f"OCR Error: {str(e)}")
            return Response(
                {'error': f'حدث خطأ أثناء معالجة الصورة: {str(e)}'},
                status=status.HTTP_500_INTERNAL_SERVER_ERROR
            )
