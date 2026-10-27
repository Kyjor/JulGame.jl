module SaveSystemModule
    using Dates
    using SHA
    import ...JulGame

    export SaveStore, SaveStatus,
           write_save, read_save, validate_save, delete_save, list_slots

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
              out *= "\\u" * string(UInt32(c); base = 16, pad = 4)
          else
              out *= string(c)
          end
      end
      return out * "\""
  end

  function _json_object(value::Dict{String, Any})::String
      names = String[]
      for key in keys(value)
          push!(names, string(key))
      end
      sort!(names)
      parts = String[]
      for name in names
          push!(parts, _json_escape(name) * ":" * _json_write(value[name]))
      end
      return "{" * join(parts, ",") * "}"
  end

  function _json_array(items::Vector{Any})::String
      parts = String[]
      for item in items
          push!(parts, _json_write(item))
      end
      return "[" * join(parts, ",") * "]"
  end

  function _json_array_of(value::Vector{T}) where {T}
      items = Any[]
      for item in value
          push!(items, item)
      end
      return _json_array(items)
  end

  # Sorted object keys, so a payload re-read and written again keeps the same checksum bytes.
  function _json_write(value)::String
      if value === nothing
          return "null"
      elseif value isa Bool
          return value ? "true" : "false"
      elseif value isa Integer
          return string(Int64(value))
      elseif value isa AbstractFloat
          return string(Float64(value))
      elseif value isa AbstractString
          return _json_escape(String(value))
      elseif value isa Dict{String, Any}
          return _json_object(value)
      elseif value isa Vector{Any}
          return _json_array(value)
      elseif value isa Vector{String}
          return _json_array_of(value)
      elseif value isa Vector{Int64}
          return _json_array_of(value)
      elseif value isa Vector{UInt64}
          return _json_array_of(value)
      elseif value isa Vector{Dict{String, Any}}
          return _json_array_of(value)
      else
          return _json_escape(string(value))
      end
  end

  mutable struct _JsonScan
      text::String
      i::Int
  end

  function _json_peek(scan::_JsonScan)
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

  function _json_bump!(scan::_JsonScan)
      c = _json_peek(scan)
      scan.i = nextind(scan.text, scan.i)
      return c
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
                  hex = ""
                  for _ in 1:4
                      hex *= string(_json_bump!(scan))
                  end
                  out *= string(Char(parse(UInt32, hex; base = 16)))
              else
                  out *= string(esc)
              end
          else
              out *= string(c)
          end
      end
      return out
  end

  function _json_parse_number!(scan::_JsonScan)
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
      return is_float ? parse(Float64, text) : parse(Int64, text)
  end

  function _json_parse!(scan::_JsonScan)
      _json_skip!(scan)
      c = _json_peek(scan)
      if c == '{'
          _json_bump!(scan)
          obj = Dict{String, Any}()
          _json_skip!(scan)
          if _json_peek(scan) == '}'
              _json_bump!(scan)
              return obj
          end
          while true
              _json_skip!(scan)
              key = _json_parse_string!(scan)
              _json_skip!(scan)
              _json_bump!(scan) # colon
              obj[key] = _json_parse!(scan)
              _json_skip!(scan)
              sep = _json_peek(scan)
              _json_bump!(scan)
              sep == '}' && break
          end
          return obj
      elseif c == '['
          _json_bump!(scan)
          arr = Any[]
          _json_skip!(scan)
          if _json_peek(scan) == ']'
              _json_bump!(scan)
              return arr
          end
          while true
              push!(arr, _json_parse!(scan))
              _json_skip!(scan)
              sep = _json_peek(scan)
              _json_bump!(scan)
              sep == ']' && break
          end
          return arr
      elseif c == '"'
          return _json_parse_string!(scan)
      elseif c == 't'
          scan.i += 4
          return true
      elseif c == 'f'
          scan.i += 5
          return false
      elseif c == 'n'
          scan.i += 4
          return nothing
      else
          return _json_parse_number!(scan)
      end
  end

  _json_read(raw::String) = _json_parse!(_JsonScan(raw, 1))

  _payload_json(payload::Dict{String, Any}) = _json_write(payload)

  function _payload_json_candidates(payload::Dict{String, Any})
      return [_payload_json(payload)]
  end

  function _checksum(payload_json::String)
      return bytes2hex(sha256(payload_json))
  end

  function _hmac(payload_json::String, secret_key::String)
      return bytes2hex(hmac_sha256(Vector{UInt8}(secret_key), payload_json))
  end

  function _canonical_payload(payload::Dict{String, Any})
      normalized = _normalize_json_value(payload)
      return _payload_json(normalized), normalized
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
      if value isa AbstractDict
          result = Dict{String, Any}()
          for (key, nested) in pairs(value)
              result[string(key)] = _normalize_json_value(nested)
          end
          return result
      elseif value isa AbstractVector
          result = Any[]
          for item in value
              push!(result, _normalize_json_value(item))
          end
          return result
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
          checksum_ok = false
          for json in candidates
              if envelope["checksum"] == _checksum(json)
                  checksum_ok = true
                  break
              end
          end
          if !checksum_ok
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
          hmac_ok = false
          for json in candidates
              if envelope["hmac"] == _hmac(json, store.secret_key)
                  hmac_ok = true
                  break
              end
          end
          if !hmac_ok
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
      return payload
  end

  function _read_envelope_file(path::String)
      return _json_read(read(path, String))
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
      io = open(tmp_path, "w")
      try
          write(io, _json_write(data))
          flush(io)
      finally
          close(io)
      end
      mv(tmp_path, path; force = true)
  end

  function write_save(store::SaveStore, slot::String, payload::Dict{String, Any})::Bool
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
end
