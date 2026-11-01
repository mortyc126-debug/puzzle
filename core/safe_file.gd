class_name SafeFile
extends RefCounted

## Надёжные сохранения. Телефон может выключиться или выгрузить игру прямо во время записи —
## тогда обычный файл остаётся обрезанным, и весь прогресс пропадает. Поэтому:
## 1. данные пишутся во временный файл <путь>.tmp;
## 2. прошлое сохранение переименовывается в <путь>.bak;
## 3. временный файл переименовывается в основной.
## Если основной файл не читается, загружается .tmp (если он дописан до конца) или .bak —
## теряется максимум последнее изменение.

const BACKUP_SUFFIX = ".bak"
const TEMP_SUFFIX = ".tmp"

static func save_var(path: String, data) -> bool:
	var temp_path = path + TEMP_SUFFIX
	var file = FileAccess.open(temp_path, FileAccess.WRITE)
	if file == null:
		push_warning("Не удалось записать " + temp_path)
		return false
	file.store_var(data)
	var error = file.get_error()
	file.close()
	if error != OK:
		push_warning("Ошибка записи %s: %d" % [temp_path, error])
		return false

	if FileAccess.file_exists(path):
		_rename(path, path + BACKUP_SUFFIX)
	return _rename(temp_path, path)

# Первое читаемое сохранение-словарь: основной файл, недописанная подмена, резервная копия.
# Обрезанный файл get_var() не прочитает (вернёт null), поэтому неполные данные не подхватятся.
static func load_dict(path: String) -> Dictionary:
	for candidate in [path, path + TEMP_SUFFIX, path + BACKUP_SUFFIX]:
		if not FileAccess.file_exists(candidate):
			continue
		var file = FileAccess.open(candidate, FileAccess.READ)
		if file == null:
			continue
		var data = file.get_var()
		file.close()
		if data is Dictionary:
			return data
		push_warning("Повреждённое сохранение: " + candidate)
	return {}

static func exists(path: String) -> bool:
	for candidate in [path, path + TEMP_SUFFIX, path + BACKUP_SUFFIX]:
		if FileAccess.file_exists(candidate):
			return true
	return false

static func remove(path: String) -> void:
	for candidate in [path, path + BACKUP_SUFFIX, path + TEMP_SUFFIX]:
		if FileAccess.file_exists(candidate):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(candidate))

static func _rename(from_path: String, to_path: String) -> bool:
	var from_abs = ProjectSettings.globalize_path(from_path)
	var to_abs = ProjectSettings.globalize_path(to_path)
	if FileAccess.file_exists(to_path):
		DirAccess.remove_absolute(to_abs)
	return DirAccess.rename_absolute(from_abs, to_abs) == OK
