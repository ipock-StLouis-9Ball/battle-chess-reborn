class_name GameEnums
extends RefCounted

## Global Enums for Duel of Kings: Animated Chess

enum PieceType {
	NONE = 0,
	PAWN = 1,
	KNIGHT = 2,
	BISHOP = 3,
	ROOK = 4,
	QUEEN = 5,
	KING = 6,
}

enum PieceColor {
	WHITE = 0,
	BLACK = 1,
}

enum GameState {
	BOOT = 0,
	MAIN_MENU = 1,
	MATCH_INIT = 2,
	BOARD_TURN = 3,
	DUEL_COMBAT = 4,
	PAUSED = 5,
	GAME_OVER = 6,
}

enum GameMode {
	VS_AI = 0,
	LOCAL_PASS_AND_PLAY = 1,
	FAST_RESOLUTION = 2, ## Instant auto-battle calculation instead of interactive arena
}

enum AIDifficulty {
	EASY = 0,
	MEDIUM = 1,
	HARD = 2,
	MASTER = 3,
}

enum FighterState {
	IDLE = 0,
	RUN = 1,
	ATTACK_LIGHT = 2,
	ATTACK_HEAVY = 3,
	DODGE = 4,
	SPECIAL = 5,
	HURT = 6,
	STUNNED = 7,
	VICTORY = 8,
	DEFEAT = 9,
}

enum PlatformType {
	PC_STEAM = 0,
	ANDROID_SAMSUNG = 1,
	GENERIC_MOBILE = 2,
	STEAM_DECK = 3,
	WEB = 4,
	UNKNOWN = 5,
}

enum GraphicsPreset {
	LOW = 0,
	MEDIUM = 1,
	HIGH = 2,
	ULTRA = 3,
}

enum TargetFPS {
	FPS_30 = 30,
	FPS_60 = 60,
	FPS_90 = 90,
	FPS_120 = 120,
	UNLIMITED = 0,
}

enum InputScheme {
	KEYBOARD_MOUSE = 0,
	GAMEPAD = 1,
	TOUCH = 2,
}
