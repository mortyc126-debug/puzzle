extends Node

## Глобальная шина событий (автозагрузка Events).
## Игра сообщает о том, что произошло, а статистика, достижения и интерфейс подписываются.
## Так новые системы подключаются без правок в game.gd.

signal game_started
signal piece_placed(cell_count: int)
signal lines_cleared(count: int, streak: int, perfect: bool, fill_before: float)
signal game_finished(score: int, used_powerups: bool)
signal powerup_used(powerup_id: String)
signal continue_used
signal theme_changed(theme_id: String)
signal item_unlocked(item_type: String, item_id)
signal achievement_unlocked(achievement_id: String, tier: int)
