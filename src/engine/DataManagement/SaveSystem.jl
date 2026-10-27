module SaveSystemModule
    using JSON3
    using Dates
    using SHA
    import ...JulGame

    export SaveStore, SaveStatus,
           write_save, read_save, validate_save, delete_save, list_slots,
           JsonNode, write_node_save, read_node_save,
           json_null, json_bool, json_int, json_float, json_str, json_arr, json_obj,
           node_get, node_int, node_float, node_bool, node_string, node_items

  const SAVE_FORMAT = "julgame-save-v1"

  @enum SaveStatus begin
      SaveOk
      SaveRestoredFromBackup
      SaveNotFound
      SaveCorrupt
      SaveTampered
      SaveVersionUnsupported
      SaveError
  end

  mutable struct SaveStore
      directory::String
      secret_key::Union{String, Nothing}
      version::Int
      max_backups::Int
      migrations::Dict{Int, Function}
  end

  function SaveStore(;
      directory::String,
      secret_key::Union{String, Nothing} = nothing,
      version::Int = 1,
      max_backups::Int = 3,
      migrations::Dict{Int, Function} = Dict{Int, Function}(),
  )
      mkpath(directory)
      return SaveStore(directory, secret_key, version, max_backups, migrations)
  end

  function _slot_path(store::SaveStore, slot::String)
      return joinpath(store.directory, "$(slot).json")
  end

  function _backup_path(store::SaveStore, slot::String, index::Int)
      return joinpath(store.directory, "$(slot).$(index).json")
  end

  function _tmp_path(store::SaveStore, slot::String)
      return joinpath(store.directory, "$(slot).json.tmp")
  end

  # Keys are written sorted. A Dict's iteration order depends on insertion order, so a payload that is
  # read back and re-serialized could otherwise produce different bytes and fail its own checksum.
  function _sorted_json(value)::String
      if value isa AbstractDict
          entries = [JSON3.write(string(k)) * ":" * _sorted_json(v) for (k, v) in sort!(collect(pairs(value)); by = kv -> string(first(kv)))]
          return "{" * join(entries, ",") * "}"
      elseif value isa AbstractVector
          return "[" * join((_sorted_json(item) for item in value), ",") * "]"
      end
      return JSON3.write(value)
  end

  _payload_json(payload::Dict{String, Any}) = _sorted_json(payload)

  # Saves written before keys were sorted were signed over the Dict's own iteration order.
  _payload_json_candidates(payload::Dict{String, Any}) = unique!([_payload_json(payload), JSON3.write(payload)])

  function _checksum(payload_json::String)
      return bytes2hex(sha256(payload_json))
  end

  function _hmac(payload_json::String, secret_key::String)
      return bytes2hex(hmac_sha256(Vector{UInt8}(secret_key), payload_json))
  end

  function _canonical_payload(payload::Dict{String, Any})
      normalized = _normalize_json_value(payload)
      payload_json = _payload_json(normalized)
      return payload_json, JSON3.read(payload_json)
  end

  function _build_envelope(store::SaveStore, payload::Dict{String, Any})
      payload_json, canonical_payload = _canonical_payload(payload)
      envelope = Dict{String, Any}(
          "format" => SAVE_FORMAT,
          "version" => store.version,
          "timestamp" => string(Dates.now()),
          "checksum" => _checksum(payload_json),
          "payload" => canonical_payload,
      )
      if store.secret_key !== nothing
          envelope["hmac"] = _hmac(payload_json, store.secret_key)
      end
      return envelope
  end

  function _normalize_json_value(value)
      if value isa JSON3.Object
          result = Dict{String, Any}()
          for (key, nested) in pairs(value)
              result[string(key)] = _normalize_json_value(nested)
          end
          return result
      elseif value isa AbstractVector
          return [_normalize_json_value(item) for item in value]
      else
          return value
      end
  end

  function _dict_without_validation(data)
      result = Dict{String, Any}()
      for (key, value) in pairs(data)
          string_key = string(key)
          if string_key != "hmac" && string_key != "checksum"
              result[string_key] = _normalize_json_value(value)
          end
      end
      return result
  end

  function _extract_payload_dict(envelope)
      if haskey(envelope, "payload")
          payload = envelope["payload"]
          return _normalize_json_value(payload)
      end
      # Legacy flat envelope: everything except integrity metadata.
      return _dict_without_validation(envelope)
  end

  function _verify_envelope(store::SaveStore, envelope)::Symbol
      if !haskey(envelope, "payload")
          return :corrupt
      end

      payload = _extract_payload_dict(envelope)
      candidates = _payload_json_candidates(payload)

      legacy_integrity = false
      if haskey(envelope, "checksum")
          if !any(json -> envelope["checksum"] == _checksum(json), candidates)
              # Saves written before canonical payload round-trip used a checksum
              # that no longer matches after envelope JSON serialization.
              file_version = Int(get(envelope, "version", 1))
              if file_version <= 1
                  legacy_integrity = true
              else
                  return :tampered
              end
          end
      else
          return :corrupt
      end

      if store.secret_key !== nothing && !legacy_integrity
          if !haskey(envelope, "hmac")
              return :tampered
          end
          if !any(json -> envelope["hmac"] == _hmac(json, store.secret_key), candidates)
              return :tampered
          end
      end

      file_version = Int(get(envelope, "version", 0))
      if file_version > store.version
          return :version_unsupported
      end

      return :ok
  end

  function _apply_migrations(store::SaveStore, payload::Dict{String, Any}, from_version::Int)
      current = from_version
      while current < store.version
          next_version = current + 1
          if haskey(store.migrations, next_version)
              payload = store.migrations[next_version](payload)
          end
          current = next_version
      end
      return payload
  end

  function _read_envelope_file(path::String)
      raw = read(path, String)
      return JSON3.read(raw)
  end

  function _load_payload_from_file(store::SaveStore, path::String)
      envelope = _read_envelope_file(path)
      status = _verify_envelope(store, envelope)
      if status != :ok
          return status, nothing, 0
      end
      file_version = Int(get(envelope, "version", 1))
      payload = _extract_payload_dict(envelope)
      payload = _apply_migrations(store, payload, file_version)
      return :ok, payload, file_version
  end

  function _rotate_backups!(store::SaveStore, slot::String)
      main_path = _slot_path(store, slot)
      !isfile(main_path) && return

      for index in store.max_backups:-1:1
          src = index == 1 ? main_path : _backup_path(store, slot, index - 1)
          dst = _backup_path(store, slot, index)
          if isfile(src)
              cp(src, dst; force = true)
          end
      end
  end

  function _atomic_write_json(path::String, data)
      tmp_path = "$(path).tmp"
      open(tmp_path, "w") do io
          JSON3.write(io, data)
          flush(io)
      end
      mv(tmp_path, path; force = true)
  end

  # JSON3 cannot be compiled by `juliac --trim`, so a trimmed build neither writes nor finds saves.
  function write_save(store::SaveStore, slot::String, payload::Dict{String, Any})::Bool
      JulGame.is_trimmed() && return false
      try
          _rotate_backups!(store, slot)
          envelope = _build_envelope(store, payload)
          _atomic_write_json(_slot_path(store, slot), envelope)
          return true
      catch e
          @warn "Failed to write save slot '$slot': $e"
          return false
      end
  end

  function read_save(store::SaveStore, slot::String)
      JulGame.is_trimmed() && return SaveNotFound, nothing
      main_path = _slot_path(store, slot)
      if isfile(main_path)
          status, payload, _ = _load_payload_from_file(store, main_path)
          if status == :ok && payload !== nothing
              return SaveOk, payload
          end
      else
          return SaveNotFound, nothing
      end

      for index in 1:store.max_backups
          backup_path = _backup_path(store, slot, index)
          !isfile(backup_path) && continue
          status, payload, _ = _load_payload_from_file(store, backup_path)
          if status == :ok && payload !== nothing
              write_save(store, slot, payload)
              return SaveRestoredFromBackup, payload
          end
      end

      if isfile(main_path)
          return SaveCorrupt, nothing
      end
      return SaveNotFound, nothing
  end

  function validate_save(store::SaveStore, slot::String)::SaveStatus
      JulGame.is_trimmed() && return SaveNotFound
      main_path = _slot_path(store, slot)
      if !isfile(main_path)
          for index in 1:store.max_backups
              isfile(_backup_path(store, slot, index)) && return SaveRestoredFromBackup
          end
          return SaveNotFound
      end

      try
          envelope = _read_envelope_file(main_path)
          status = _verify_envelope(store, envelope)
          if status == :ok
              return SaveOk
          elseif status == :tampered
              return SaveTampered
          elseif status == :version_unsupported
              return SaveVersionUnsupported
          else
              return SaveCorrupt
          end
      catch
          return SaveError
      end
  end

  function delete_save(store::SaveStore, slot::String)::Bool
      try
          main_path = _slot_path(store, slot)
          isfile(main_path) && rm(main_path)
          for index in 1:store.max_backups
              backup_path = _backup_path(store, slot, index)
              isfile(backup_path) && rm(backup_path)
          end
          return true
      catch e
          @warn "Failed to delete save slot '$slot': $e"
          return false
      end
  end

  function list_slots(store::SaveStore)::Vector{String}
      !isdir(store.directory) && return String[]
      slots = String[]
      for name in readdir(store.directory)
          if endswith(name, ".json") && !occursin(".json.tmp", name)
              base = replace(name, r"\.json$" => "")
              occursin(r"\.\d+$", base) && continue
              push!(slots, base)
          end
      end
      sort!(unique(slots))
      return slots
  end

  # A concrete JSON tree. Trim cannot call a function on an `Any` dict value, so saves walk this instead of Dict{String,Any}.
  mutable struct JsonNode
      kind::UInt8
      b::Bool
      i::Int64
      f::Float64
      s::String
      a::Vector{JsonNode}
      ks::Vector{String}
      vs::Vector{JsonNode}
  end

  const JSON_NULL = 0x00
  const JSON_BOOL = 0x01
  const JSON_INT = 0x02
  const JSON_FLOAT = 0x03
  const JSON_STRING = 0x04
  const JSON_ARRAY = 0x05
  const JSON_OBJECT = 0x06

  json_null()::JsonNode = JsonNode(JSON_NULL, false, Int64(0), 0.0, "", JsonNode[], String[], JsonNode[])
  json_bool(value::Bool)::JsonNode = JsonNode(JSON_BOOL, value, Int64(0), 0.0, "", JsonNode[], String[], JsonNode[])
  json_int(value::Int64)::JsonNode = JsonNode(JSON_INT, false, value, 0.0, "", JsonNode[], String[], JsonNode[])
  json_float(value::Float64)::JsonNode = JsonNode(JSON_FLOAT, false, Int64(0), value, "", JsonNode[], String[], JsonNode[])
  json_str(value::String)::JsonNode = JsonNode(JSON_STRING, false, Int64(0), 0.0, value, JsonNode[], String[], JsonNode[])
  json_arr(items::Vector{JsonNode})::JsonNode = JsonNode(JSON_ARRAY, false, Int64(0), 0.0, "", items, String[], JsonNode[])
  json_obj(keys::Vector{String}, vals::Vector{JsonNode})::JsonNode = JsonNode(JSON_OBJECT, false, Int64(0), 0.0, "", JsonNode[], keys, vals)

  function node_get(node::JsonNode, key::String)::JsonNode
      node.kind == JSON_OBJECT || return json_null()
      for i in 1:length(node.ks)
          node.ks[i] == key && return node.vs[i]
      end
      return json_null()
  end

  function node_int(node::JsonNode, default::Int64)::Int64
      node.kind == JSON_INT && return node.i
      node.kind == JSON_FLOAT && return Int64(round(node.f))
      return default
  end

  function node_float(node::JsonNode, default::Float64)::Float64
      node.kind == JSON_FLOAT && return node.f
      node.kind == JSON_INT && return Float64(node.i)
      return default
  end

  node_bool(node::JsonNode, default::Bool)::Bool = node.kind == JSON_BOOL ? node.b : default
  node_string(node::JsonNode, default::String)::String = node.kind == JSON_STRING ? node.s : default
  node_items(node::JsonNode)::Vector{JsonNode} = node.kind == JSON_ARRAY ? node.a : JsonNode[]

  function _json_escape(text::String)::String
      out = "\""
      for c in text
          if c == '"'
              out *= "\\\""
          elseif c == '\\'
              out *= "\\\\"
          elseif c == '\n'
              out *= "\\n"
          elseif c == '\r'
              out *= "\\r"
          elseif c == '\t'
              out *= "\\t"
          elseif UInt32(c) < 0x20
              n = UInt32(c)
              hex = "0123456789abcdef"
              out *= "\\u"
              out *= string(hex[Int((n >> 12) & 0x0f) + 1])
              out *= string(hex[Int((n >> 8) & 0x0f) + 1])
              out *= string(hex[Int((n >> 4) & 0x0f) + 1])
              out *= string(hex[Int(n & 0x0f) + 1])
          else
              out *= string(c)
          end
      end
      return out * "\""
  end

  function _sorted_key_order(keys::Vector{String})::Vector{Int}
      order = Int[]
      for i in 1:length(keys)
          push!(order, i)
      end
      i = 2
      while i <= length(order)
          j = i
          while j > 1 && keys[order[j]] < keys[order[j - 1]]
              tmp = order[j]
              order[j] = order[j - 1]
              order[j - 1] = tmp
              j -= 1
          end
          i += 1
      end
      return order
  end

  function _write_node(node::JsonNode)::String
      if node.kind == JSON_NULL
          return "null"
      elseif node.kind == JSON_BOOL
          return node.b ? "true" : "false"
      elseif node.kind == JSON_INT
          return string(node.i)
      elseif node.kind == JSON_FLOAT
          return string(node.f)
      elseif node.kind == JSON_STRING
          return _json_escape(node.s)
      elseif node.kind == JSON_ARRAY
          parts = String[]
          for item in node.a
              push!(parts, _write_node(item))
          end
          return "[" * join(parts, ",") * "]"
      elseif node.kind == JSON_OBJECT
          parts = String[]
          for index in _sorted_key_order(node.ks)
              push!(parts, _json_escape(node.ks[index]) * ":" * _write_node(node.vs[index]))
          end
          return "{" * join(parts, ",") * "}"
      end
      return "null"
  end

  mutable struct _JsonScan
      text::String
      i::Int
  end

  function _json_peek(scan::_JsonScan)::Char
      scan.i > ncodeunits(scan.text) && return Char(0)
      return scan.text[scan.i]
  end

  function _json_skip!(scan::_JsonScan)
      while true
          c = _json_peek(scan)
          (c == ' ' || c == '\n' || c == '\r' || c == '\t') || return
          scan.i = nextind(scan.text, scan.i)
      end
  end

  function _json_bump!(scan::_JsonScan)::Char
      c = _json_peek(scan)
      c == Char(0) && return c
      scan.i = nextind(scan.text, scan.i)
      return c
  end

  function _json_take!(scan::_JsonScan, word::String)::Bool
      i = scan.i
      for c in word
          if i > ncodeunits(scan.text) || scan.text[i] != c
              return false
          end
          i = nextind(scan.text, i)
      end
      scan.i = i
      return true
  end

  function _json_parse_string!(scan::_JsonScan)::String
      _json_bump!(scan)
      out = ""
      while true
          c = _json_bump!(scan)
          c == Char(0) && break
          if c == '"'
              break
          elseif c == '\\'
              esc = _json_bump!(scan)
              if esc == 'n'
                  out *= "\n"
              elseif esc == 'r'
                  out *= "\r"
              elseif esc == 't'
                  out *= "\t"
              elseif esc == 'u'
                  n = UInt32(0)
                  for _ in 1:4
                      h = _json_bump!(scan)
                      n = n << 4
                      if '0' <= h <= '9'
                          n += UInt32(h - '0')
                      elseif 'a' <= h <= 'f'
                          n += UInt32(h - 'a' + 10)
                      elseif 'A' <= h <= 'F'
                          n += UInt32(h - 'A' + 10)
                      end
                  end
                  out *= string(Char(n))
              else
                  out *= string(esc)
              end
          else
              out *= string(c)
          end
      end
      return out
  end

  function _json_parse_number!(scan::_JsonScan)::JsonNode
      start = scan.i
      is_float = false
      while true
          c = _json_peek(scan)
          if c == '.' || c == 'e' || c == 'E'
              is_float = true
          elseif c == '+' || c == '-' || ('0' <= c <= '9')
          else
              break
          end
          _json_bump!(scan)
      end
      text = scan.text[start:prevind(scan.text, scan.i)]
      if is_float
          return json_float(parse(Float64, text))
      end
      return json_int(parse(Int64, text))
  end

  function _json_parse_node!(scan::_JsonScan)::JsonNode
      _json_skip!(scan)
      c = _json_peek(scan)
      if c == '{'
          _json_bump!(scan)
          ks = String[]
          vs = JsonNode[]
          _json_skip!(scan)
          if _json_peek(scan) == '}'
              _json_bump!(scan)
              return json_obj(ks, vs)
          end
          while true
              _json_skip!(scan)
              push!(ks, _json_parse_string!(scan))
              _json_skip!(scan)
              _json_bump!(scan)
              push!(vs, _json_parse_node!(scan))
              _json_skip!(scan)
              sep = _json_peek(scan)
              _json_bump!(scan)
              sep == '}' && break
          end
          return json_obj(ks, vs)
      elseif c == '['
          _json_bump!(scan)
          items = JsonNode[]
          _json_skip!(scan)
          if _json_peek(scan) == ']'
              _json_bump!(scan)
              return json_arr(items)
          end
          while true
              push!(items, _json_parse_node!(scan))
              _json_skip!(scan)
              sep = _json_peek(scan)
              _json_bump!(scan)
              sep == ']' && break
          end
          return json_arr(items)
      elseif c == '"'
          return json_str(_json_parse_string!(scan))
      elseif c == 't'
          _json_take!(scan, "true")
          return json_bool(true)
      elseif c == 'f'
          _json_take!(scan, "false")
          return json_bool(false)
      elseif c == 'n'
          _json_take!(scan, "null")
          return json_null()
      elseif c == Char(0)
          return json_null()
      else
          return _json_parse_number!(scan)
      end
  end

  function _node_hmac(payload_json::String, secret_key::String)::String
      key_bytes = UInt8[]
      for byte in codeunits(secret_key)
          push!(key_bytes, byte)
      end
      return bytes2hex(hmac_sha256(key_bytes, payload_json))
  end

  function _rotate_node_backups!(store::SaveStore, slot::String)
      main_path = _slot_path(store, slot)
      isfile(main_path) || return
      index = store.max_backups
      while index >= 1
          src = index == 1 ? main_path : _backup_path(store, slot, index - 1)
          dst = _backup_path(store, slot, index)
          if isfile(src)
              isfile(dst) && rm(dst)
              cp(src, dst)
          end
          index -= 1
      end
  end

  function _write_node_file(path::String, node::JsonNode)
      tmp_path = path * ".tmp"
      io = open(tmp_path, "w")
      try
          write(io, _write_node(node))
          flush(io)
      finally
          close(io)
      end
      isfile(path) && rm(path)
      mv(tmp_path, path)
  end

  function _envelope_node(store::SaveStore, payload::JsonNode)::JsonNode
      body = _write_node(payload)
      ks = String["format", "version", "timestamp", "checksum", "payload"]
      vs = JsonNode[
          json_str(SAVE_FORMAT),
          json_int(Int64(store.version)),
          json_str(string(floor(Int, time()))),
          json_str(bytes2hex(sha256(body))),
          payload,
      ]
      secret = store.secret_key
      if secret isa String
          push!(ks, "hmac")
          push!(vs, json_str(_node_hmac(body, secret)))
      end
      return json_obj(ks, vs)
  end

  function _verify_node(store::SaveStore, envelope::JsonNode)::Symbol
      envelope.kind == JSON_OBJECT || return :corrupt
      payload = node_get(envelope, "payload")
      payload.kind == JSON_OBJECT || return :corrupt
      checksum = node_string(node_get(envelope, "checksum"), "")
      isempty(checksum) && return :corrupt
      body = _write_node(payload)
      version = node_int(node_get(envelope, "version"), Int64(1))
      legacy = checksum != bytes2hex(sha256(body))
      if legacy && version > 1
          return :tampered
      end
      secret = store.secret_key
      if secret isa String && !legacy
          mac = node_string(node_get(envelope, "hmac"), "")
          mac == _node_hmac(body, secret) || return :tampered
      end
      version > Int64(store.version) && return :version_unsupported
      return :ok
  end

  function _read_node_file(path::String)::JsonNode
      return _json_parse_node!(_JsonScan(read(path, String), 1))
  end

  function write_node_save(store::SaveStore, slot::String, payload::JsonNode)::Bool
      try
          _rotate_node_backups!(store, slot)
          _write_node_file(_slot_path(store, slot), _envelope_node(store, payload))
          return true
      catch e
          @warn "Failed to write save slot '$slot': $e"
          return false
      end
  end

  function read_node_save(store::SaveStore, slot::String)
      main_path = _slot_path(store, slot)
      if isfile(main_path)
          envelope = _read_node_file(main_path)
          if _verify_node(store, envelope) == :ok
              return SaveOk, node_get(envelope, "payload")
          end
      else
          return SaveNotFound, json_null()
      end
      index = 1
      while index <= store.max_backups
          backup_path = _backup_path(store, slot, index)
          if isfile(backup_path)
              envelope = _read_node_file(backup_path)
              if _verify_node(store, envelope) == :ok
                  payload = node_get(envelope, "payload")
                  write_node_save(store, slot, payload)
                  return SaveRestoredFromBackup, payload
              end
          end
          index += 1
      end
      if isfile(main_path)
          return SaveCorrupt, json_null()
      end
      return SaveNotFound, json_null()
  end
end
