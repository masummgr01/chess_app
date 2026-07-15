from django.contrib import admin
from .models import Game, Move

@admin.register(Game)
class GameAdmin(admin.ModelAdmin):
    list_display = ('id', 'white_player', 'black_player', 'status', 'created_at')
    list_filter = ('status',)
    search_fields = ('white_player__username', 'black_player__username')

@admin.register(Move)
class MoveAdmin(admin.ModelAdmin):
    list_display = ('id', 'game', 'move_san', 'timestamp')
    list_filter = ('game',)
