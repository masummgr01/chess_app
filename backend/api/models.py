from django.db import models
from django.contrib.auth.models import User

class Game(models.Model):
    STATUS_CHOICES = [
        ('active', 'Active'),
        ('completed', 'Completed'),
        ('draw', 'Draw'),
    ]

    white_player = models.ForeignKey(User, on_delete=models.CASCADE, related_name='games_white')
    black_player = models.ForeignKey(User, on_delete=models.CASCADE, related_name='games_black', null=True, blank=True)
    fen = models.CharField(max_length=100, default='rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1')
    status = models.CharField(max_length=20, choices=STATUS_CHOICES, default='active')
    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)

    def __str__(self):
        return f"Game {self.id}: {self.white_player} vs {self.black_player}"

class Move(models.Model):
    game = models.ForeignKey(Game, on_delete=models.CASCADE, related_name='moves')
    move_san = models.CharField(max_length=10) # e.g., "e4", "Nf3"
    before_fen = models.CharField(max_length=100)
    after_fen = models.CharField(max_length=100)
    timestamp = models.DateTimeField(auto_now_add=True)

    def __str__(self):
        return f"Move {self.id} in Game {self.game_id}: {self.move_san}"
