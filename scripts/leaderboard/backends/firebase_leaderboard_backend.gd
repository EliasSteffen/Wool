class_name FirebaseLeaderboardBackend
extends LeaderboardBackend

## Firestore leaderboard over plain REST - no SDK, no addon.
##
## Identity comes from Firebase Anonymous Auth; the resulting UID is also the
## document id, which is what lets the security rules enforce one row per
## install and monotonically improving scores.
##
## Auth state lives in its own file rather than sharing LeaderboardManager's
## player.cfg: ConfigFile is load-modify-save, and the two writers straddle
## await points, so a shared file could be clobbered.

const AUTH_PATH: String = "user://firebase_auth.cfg"
const SIGNUP_URL: String = "https://identitytoolkit.googleapis.com/v1/accounts:signUp?key=%s"
const REFRESH_URL: String = "https://securetoken.googleapis.com/v1/token?key=%s"
const FIRESTORE_BASE: String = "https://firestore.googleapis.com/v1/projects/%s/databases/(default)/documents"

## Refresh a little before the hour is up so a long request cannot straddle expiry.
const TOKEN_SKEW_SECONDS: int = 120

var _config: LeaderboardConfig = null
var _client: HttpJsonClient = null
var _uid: String = ""
var _id_token: String = ""
var _refresh_token: String = ""
var _token_expires_unix: int = 0

func initialize(config: LeaderboardConfig) -> LeaderboardResult:
	_config = config
	if _config == null or not _config.is_valid():
		return LeaderboardResult.failure(LeaderboardResult.Code.NOT_CONFIGURED, "missing project_id/api_key")

	_client = HttpJsonClient.new()
	add_child(_client)

	_load_auth()
	return await _ensure_token()

func submit(entry: LeaderboardEntry) -> LeaderboardResult:
	if entry == null:
		return LeaderboardResult.failure(LeaderboardResult.Code.REJECTED, "null entry")

	var auth: LeaderboardResult = await _ensure_token()
	if not auth.ok:
		return auth

	entry.player_id = _uid
	var url: String = "%s/%s/%s" % [_documents_url(), _config.collection, _uid]
	var body: Dictionary = {
		"fields": {
			"name": {"stringValue": entry.player_name},
			"score": {"integerValue": str(entry.score)},
			"duration_ms": {"integerValue": str(entry.duration_ms)},
			"updated_at": {"timestampValue": _to_rfc3339(entry.updated_at_unix)},
		}
	}

	# No updateMask: PATCH replaces the whole field set, matching the rules'
	# hasOnly() check.
	var response: Dictionary = await _client.request_json(
		HTTPClient.METHOD_PATCH, url, _auth_headers(), body
	)

	if response["error"] != OK:
		return _transport_failure(response)

	var code: int = response["code"]
	if code == 200:
		return LeaderboardResult.success()
	if code == 403 or code == 400:
		# Rules said no - almost always "not an improvement". Not retryable.
		return LeaderboardResult.failure(
			LeaderboardResult.Code.REJECTED, _error_text(response)
		)
	if code == 401:
		return LeaderboardResult.failure(LeaderboardResult.Code.AUTH, _error_text(response))

	return LeaderboardResult.failure(
		LeaderboardResult.Code.UNKNOWN, "submit HTTP %d: %s" % [code, _error_text(response)]
	)

func fetch_top(limit: int) -> LeaderboardResult:
	var url: String = "%s:runQuery" % _documents_url()
	var body: Dictionary = {
		"structuredQuery": {
			"from": [{"collectionId": _config.collection}],
			"orderBy": [
				{"field": {"fieldPath": "score"}, "direction": "DESCENDING"},
				{"field": {"fieldPath": "duration_ms"}, "direction": "ASCENDING"},
			],
			"limit": limit,
		}
	}

	var response: Dictionary = await _client.request_json(
		HTTPClient.METHOD_POST, url, _auth_headers(), body
	)

	if response["error"] != OK:
		return _transport_failure(response)

	var code: int = response["code"]
	if code != 200:
		return LeaderboardResult.failure(
			LeaderboardResult.Code.UNKNOWN, "fetch_top HTTP %d: %s" % [code, _error_text(response)]
		)

	var payload: Variant = response["body"]
	if not payload is Array:
		return LeaderboardResult.failure(LeaderboardResult.Code.UNKNOWN, "unexpected runQuery payload")

	var entries: Array[LeaderboardEntry] = []
	for element in payload:
		if not element is Dictionary:
			continue
		# Streaming responses include bare {readTime} elements with no document.
		if not element.has("document"):
			continue
		var entry: LeaderboardEntry = _parse_document(element["document"])
		if entry != null:
			entry.rank = entries.size() + 1
			entries.append(entry)

	return LeaderboardResult.success(entries)

func fetch_player() -> LeaderboardResult:
	if _uid.is_empty():
		var auth: LeaderboardResult = await _ensure_token()
		if not auth.ok:
			return auth

	var url: String = "%s/%s/%s" % [_documents_url(), _config.collection, _uid]
	var response: Dictionary = await _client.request_json(
		HTTPClient.METHOD_GET, url, _auth_headers()
	)

	if response["error"] != OK:
		return _transport_failure(response)

	var code: int = response["code"]
	if code == 404:
		# Never submitted - not an error.
		return LeaderboardResult.success()
	if code != 200:
		return LeaderboardResult.failure(
			LeaderboardResult.Code.UNKNOWN, "fetch_player HTTP %d" % code
		)

	var entry: LeaderboardEntry = _parse_document(response["body"])
	if entry == null:
		return LeaderboardResult.success()

	entry.rank = await _fetch_rank(entry.score, entry.duration_ms)

	var entries: Array[LeaderboardEntry] = [entry]
	return LeaderboardResult.success(entries)

## Rank without downloading the whole collection: count everyone strictly
## better under the ranking rule, then add one.
##
## Two COUNT aggregations rather than one, because "score > mine OR (score ==
## mine AND time < mine)" spans two fields and cannot be expressed as a single
## Firestore filter. Neither count includes the player's own document.
func _fetch_rank(score: int, duration_ms: int) -> int:
	var higher_score: int = await _count_where({
		"fieldFilter": {
			"field": {"fieldPath": "score"},
			"op": "GREATER_THAN",
			"value": {"integerValue": str(score)},
		}
	})
	if higher_score < 0:
		return 0

	var same_but_faster: int = await _count_where({
		"compositeFilter": {
			"op": "AND",
			"filters": [
				{"fieldFilter": {
					"field": {"fieldPath": "score"},
					"op": "EQUAL",
					"value": {"integerValue": str(score)},
				}},
				{"fieldFilter": {
					"field": {"fieldPath": "duration_ms"},
					"op": "LESS_THAN",
					"value": {"integerValue": str(duration_ms)},
				}},
			],
		}
	})
	if same_but_faster < 0:
		return 0

	return higher_score + same_but_faster + 1

## Returns -1 on failure so callers can tell "no rank" from "rank 0".
func _count_where(filter: Dictionary) -> int:
	var url: String = "%s:runAggregationQuery" % _documents_url()
	var body: Dictionary = {
		"structuredAggregationQuery": {
			"structuredQuery": {
				"from": [{"collectionId": _config.collection}],
				"where": filter,
			},
			"aggregations": [{"count": {}, "alias": "n"}],
		}
	}

	var response: Dictionary = await _client.request_json(
		HTTPClient.METHOD_POST, url, _auth_headers(), body
	)

	if response["error"] != OK or response["code"] != 200:
		return -1

	var payload: Variant = response["body"]
	if not payload is Array:
		return -1

	for element in payload:
		if not element is Dictionary or not element.has("result"):
			continue
		var result_block: Variant = (element as Dictionary)["result"]
		if not result_block is Dictionary:
			continue
		var fields: Variant = (result_block as Dictionary).get("aggregateFields", {})
		if fields is Dictionary and (fields as Dictionary).has("n"):
			return _int_field(fields, "n")

	return -1

## Re-PATCHes the stored row with the same score and duration but a new name.
## Depends on the isRename() clause in the security rules - without it the write
## is rejected, because isImprovement() alone never permits an equal score.
func rename(new_name: String) -> LeaderboardResult:
	var existing: LeaderboardResult = await fetch_player()
	if not existing.ok:
		return existing

	# Nothing published yet - the new name applies on the first submit anyway.
	if existing.entries.is_empty():
		return LeaderboardResult.success()

	var entry: LeaderboardEntry = existing.entries[0]
	entry.player_name = new_name
	entry.updated_at_unix = int(Time.get_unix_time_from_system())
	return await submit(entry)

## Equality filter on a single field - Firestore auto-indexes single fields, so
## this needs no extra composite index.
func find_by_name(name: String) -> LeaderboardResult:
	var url: String = "%s:runQuery" % _documents_url()
	var body: Dictionary = {
		"structuredQuery": {
			"from": [{"collectionId": _config.collection}],
			"where": {
				"fieldFilter": {
					"field": {"fieldPath": "name"},
					"op": "EQUAL",
					"value": {"stringValue": name},
				}
			},
			"limit": 2,
		}
	}

	var response: Dictionary = await _client.request_json(
		HTTPClient.METHOD_POST, url, _auth_headers(), body
	)

	if response["error"] != OK:
		return _transport_failure(response)

	if response["code"] != 200:
		return LeaderboardResult.failure(
			LeaderboardResult.Code.UNKNOWN, "find_by_name HTTP %d" % response["code"]
		)

	var payload: Variant = response["body"]
	if not payload is Array:
		return LeaderboardResult.failure(LeaderboardResult.Code.UNKNOWN, "unexpected runQuery payload")

	var matches: Array[LeaderboardEntry] = []
	for element in payload:
		if not element is Dictionary or not element.has("document"):
			continue
		var entry: LeaderboardEntry = _parse_document(element["document"])
		# Our own row does not make the name "taken" for us.
		if entry != null and entry.player_id != _uid:
			matches.append(entry)

	return LeaderboardResult.success(matches)

func get_player_id() -> String:
	return _uid

# === AUTH ===

func _ensure_token() -> LeaderboardResult:
	var now: int = int(Time.get_unix_time_from_system())
	if not _id_token.is_empty() and now < _token_expires_unix - TOKEN_SKEW_SECONDS:
		return LeaderboardResult.success()

	if not _refresh_token.is_empty():
		var refreshed: LeaderboardResult = await _refresh_id_token()
		if refreshed.ok:
			return refreshed
		# Refresh token revoked or the account was cleaned up - fall through to
		# a fresh anonymous sign-up rather than leaving the player stranded.

	return await _sign_up_anonymously()

func _sign_up_anonymously() -> LeaderboardResult:
	var url: String = SIGNUP_URL % _config.api_key
	var response: Dictionary = await _client.request_json(
		HTTPClient.METHOD_POST, url, PackedStringArray(), {"returnSecureToken": true}
	)

	if response["error"] != OK:
		return _transport_failure(response)

	if response["code"] != 200:
		return LeaderboardResult.failure(
			LeaderboardResult.Code.AUTH, "signUp HTTP %d: %s" % [response["code"], _error_text(response)]
		)

	var data: Variant = response["body"]
	if not data is Dictionary:
		return LeaderboardResult.failure(LeaderboardResult.Code.AUTH, "signUp returned no JSON")

	_uid = str(data.get("localId", ""))
	_id_token = str(data.get("idToken", ""))
	_refresh_token = str(data.get("refreshToken", ""))
	_token_expires_unix = int(Time.get_unix_time_from_system()) + int(str(data.get("expiresIn", "3600")))

	if _uid.is_empty() or _id_token.is_empty():
		return LeaderboardResult.failure(LeaderboardResult.Code.AUTH, "signUp response missing fields")

	_save_auth()
	return LeaderboardResult.success()

func _refresh_id_token() -> LeaderboardResult:
	var url: String = REFRESH_URL % _config.api_key
	var headers: PackedStringArray = PackedStringArray(["Content-Type: application/x-www-form-urlencoded"])
	var body: String = "grant_type=refresh_token&refresh_token=%s" % _refresh_token.uri_encode()

	var response: Dictionary = await _client.request_raw(HTTPClient.METHOD_POST, url, headers, body)

	if response["error"] != OK:
		return _transport_failure(response)

	if response["code"] != 200:
		return LeaderboardResult.failure(
			LeaderboardResult.Code.AUTH, "token refresh HTTP %d" % response["code"]
		)

	var data: Variant = response["body"]
	if not data is Dictionary:
		return LeaderboardResult.failure(LeaderboardResult.Code.AUTH, "refresh returned no JSON")

	_id_token = str(data.get("id_token", ""))
	_refresh_token = str(data.get("refresh_token", _refresh_token))
	_uid = str(data.get("user_id", _uid))
	_token_expires_unix = int(Time.get_unix_time_from_system()) + int(str(data.get("expires_in", "3600")))

	if _id_token.is_empty():
		return LeaderboardResult.failure(LeaderboardResult.Code.AUTH, "refresh response missing id_token")

	_save_auth()
	return LeaderboardResult.success()

func _load_auth() -> void:
	var config_file: ConfigFile = ConfigFile.new()
	if config_file.load(AUTH_PATH) != OK:
		return
	_uid = str(config_file.get_value("auth", "uid", ""))
	_refresh_token = str(config_file.get_value("auth", "refresh_token", ""))

func _save_auth() -> void:
	var config_file: ConfigFile = ConfigFile.new()
	config_file.set_value("auth", "uid", _uid)
	config_file.set_value("auth", "refresh_token", _refresh_token)
	config_file.save(AUTH_PATH)

# === HELPERS ===

func _documents_url() -> String:
	return FIRESTORE_BASE % _config.project_id

func _auth_headers() -> PackedStringArray:
	if _id_token.is_empty():
		return PackedStringArray()
	return PackedStringArray(["Authorization: Bearer %s" % _id_token])

func _to_rfc3339(unix_seconds: int) -> String:
	return Time.get_datetime_string_from_unix_time(unix_seconds) + "Z"

## Firestore returns integerValue as a JSON *string*, so every numeric field has
## to go through int() rather than being read directly.
func _parse_document(document: Variant) -> LeaderboardEntry:
	if not document is Dictionary:
		return null
	var doc: Dictionary = document
	if not doc.has("fields"):
		return null

	var fields: Variant = doc["fields"]
	if not fields is Dictionary:
		return null

	var entry: LeaderboardEntry = LeaderboardEntry.new()
	entry.player_id = _uid_from_path(str(doc.get("name", "")))
	entry.player_name = _string_field(fields, "name")
	entry.score = _int_field(fields, "score")
	entry.duration_ms = _int_field(fields, "duration_ms")
	entry.updated_at_unix = _timestamp_field(fields, "updated_at")
	return entry

func _uid_from_path(resource_path: String) -> String:
	var segments: PackedStringArray = resource_path.split("/")
	if segments.is_empty():
		return ""
	return segments[segments.size() - 1]

func _string_field(fields: Dictionary, key: String) -> String:
	if not fields.has(key) or not fields[key] is Dictionary:
		return ""
	return str((fields[key] as Dictionary).get("stringValue", ""))

func _int_field(fields: Dictionary, key: String) -> int:
	if not fields.has(key) or not fields[key] is Dictionary:
		return 0
	return int(str((fields[key] as Dictionary).get("integerValue", "0")))

func _timestamp_field(fields: Dictionary, key: String) -> int:
	if not fields.has(key) or not fields[key] is Dictionary:
		return 0
	var raw: String = str((fields[key] as Dictionary).get("timestampValue", ""))
	if raw.is_empty():
		return 0
	return int(Time.get_unix_time_from_datetime_string(raw))

func _transport_failure(response: Dictionary) -> LeaderboardResult:
	var transport: int = int(response.get("transport", -1))
	if transport == HTTPRequest.RESULT_TIMEOUT:
		return LeaderboardResult.failure(LeaderboardResult.Code.TIMEOUT, "request timed out")
	return LeaderboardResult.failure(
		LeaderboardResult.Code.NETWORK, "transport error %d" % transport
	)

func _error_text(response: Dictionary) -> String:
	var body: Variant = response.get("body")
	if body is Dictionary and (body as Dictionary).has("error"):
		var error_object: Variant = (body as Dictionary)["error"]
		if error_object is Dictionary:
			return str((error_object as Dictionary).get("message", "unknown"))
	return "unknown"
