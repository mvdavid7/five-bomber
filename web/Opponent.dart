library oponent;

enum OpponentState { Setup, Ready, Turn }

class FiveBomberOpponent {
  OpponentState state = OpponentState.Setup;

  FiveBomberOpponent() {
  }
}