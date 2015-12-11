library oponent;

enum OpponentState { Setup, Ready, Turn, Dead }

class FiveBomberOpponent {
  OpponentState state = OpponentState.Setup;

  FiveBomberOpponent() {
  }
}