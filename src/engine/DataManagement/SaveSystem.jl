module SaveSystemModule
    using JSON3
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
end
