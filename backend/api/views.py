from django.contrib.auth.models import User
from rest_framework import generics
from rest_framework.permissions import AllowAny
from rest_framework.decorators import api_view, permission_classes
from rest_framework.response import Response
from .serializers import UserSerializer

@api_view(['GET'])
@permission_classes([AllowAny])
def api_root(request):
    """
    Health check and welcome message for the API.
    """
    return Response({
        "status": "Backend is running",
        "message": "Welcome to the Chess App API"
    })

class RegisterView(generics.CreateAPIView):
    """
    View to register new users.
    """
    queryset = User.objects.all()
    permission_classes = (AllowAny,)
    serializer_class = UserSerializer
