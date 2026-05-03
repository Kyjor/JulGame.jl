module HistoryModule
    using ..JulGame
    using Dates

    """
        History(id::String, fieldHistory::Dict{Symbol, Vector{Any}})
        A history of changes to a struct.
        Example:
        id = "123"
        fieldHistory = Dict{Symbol, Vector{Any}}()
        fieldHistory[:transform] = []
    """

    mutable struct FieldHistory
        id::String
        property::Symbol
        oldValue::Any
        newValue::Any
        timestamp::DateTime
    end

    function FieldHistory(id::String, property::Symbol, oldValue::Any, newValue::Any)
        return FieldHistory(id, property, oldValue, newValue, now())
    end

    # Typed runtime stack (avoids `EditorState::Dict{String,Any}` in hot path — helps JuliaC `--trim`).
    const _HISTORY_STACK = FieldHistory[]
    const _HISTORY_STACK_INDEX = Ref{Int}(0)

    # Note: This struct is kept for backward compatibility but is no longer actively used
    mutable struct History <: JulGame.IHistory
        id::String
        fieldHistory::Dict{Symbol, Vector{FieldHistory}}
        minTimeBetweenUpdates::Float64

        function History(id::String, fieldHistoryEntry::FieldHistory)
            this = new()
            
            this.id = id
            this.minTimeBetweenUpdates = 1.0
            this.fieldHistory = Dict{Symbol, Vector{FieldHistory}}(
                fieldHistoryEntry.property => [fieldHistoryEntry]
            )

            return this
        end
    end
    if JulGame.IS_EDITOR
        JulGame.EventsModule.ObserverModule.add_observer((event, data) -> on_notify(event, data))
    end

    function on_notify(event::Symbol, data::Any)
        JulGame.juliac_trim_active() && return nothing
        if event == :updated_transform
            add_field_history(data.id, data.property, data.oldValue, data.newValue)

        end
    end

    function add_field_history(id::String, property::Symbol, oldValue::Any, newValue::Any)
        JulGame.juliac_trim_active() && return nothing
        history_stack = _HISTORY_STACK
        current_index = _HISTORY_STACK_INDEX[]::Int
        #@debug "  Current stack length: $(length(history_stack)), Current index: $(current_index)"
        
        # Check if the last change is the same (deduplicate)
        if current_index > 0
            last_entry = history_stack[current_index]
            #@debug "  Last entry: $(last_entry.id).$(last_entry.property) = $(last_entry.newValue)"
            if last_entry.id == id && last_entry.property == property
                if newValue isa JulGame.Math._Vector3{Float64} && last_entry.newValue isa JulGame.Math._Vector3{Float64}
                    a = last_entry.newValue::JulGame.Math._Vector3{Float64}
                    b = newValue::JulGame.Math._Vector3{Float64}
                    if a.x == b.x && a.y == b.y && a.z == b.z
                        return
                    end
                end
            end
            
            # Check time difference for same property
            if last_entry.id == id && last_entry.property == property
                time_diff = now() - last_entry.timestamp
                time_diff_ms::Int64 = Dates.value(time_diff)
                # @debug "  Time difference: $(time_diff_ms)ms"
                if time_diff_ms < Int64(1000)  # Less than 1 second
                #    @debug "  SKIPPED: Too soon (< 1000ms)"
                    # update the last entry with the new value
                    last_entry.newValue = newValue
                    last_entry.timestamp = now()
                    return
                end
            end
        end
        
        # Truncate future history if we're not at the end
        if current_index < length(history_stack)
            @debug "  TRUNCATING: stack from $(length(history_stack)) to $(current_index)"
            resize!(history_stack, current_index)
        end
        
        # Create new entry with id embedded
        entry = FieldHistory(id, property, oldValue, newValue, now())
        push!(history_stack, entry)
        _HISTORY_STACK_INDEX[] = length(history_stack)
        @debug "  ADDED: Stack length now $(length(history_stack)), Index now $(_HISTORY_STACK_INDEX[])"
        @debug "=== END ADD_FIELD_HISTORY ==="
    end
    
    export undo
    function undo()
        @debug "=== UNDO CALLED ==="
        history_stack = _HISTORY_STACK
        current_index = _HISTORY_STACK_INDEX[]::Int
        @debug "  Stack length: $(length(history_stack)), Current index: $(current_index)"
        
        if current_index < 1
            @debug "  Nothing to undo (index < 1)"
            return
        end
        
        # Get the entry at current index and apply its oldValue
        entry = history_stack[current_index]
        @debug "  Undoing: $(entry.id).$(entry.property)"
        @debug "  From: $(entry.newValue)"
        @debug "  To: $(entry.oldValue)"
        
        apply_history_value(entry.id, entry.property, entry.oldValue)
        _HISTORY_STACK_INDEX[] = current_index - 1
        @debug "  New index: $(_HISTORY_STACK_INDEX[])"
        @debug "=== END UNDO ==="
    end
    
    export redo
    function redo()
        @debug "=== REDO CALLED ==="
        history_stack = _HISTORY_STACK
        current_index = _HISTORY_STACK_INDEX[]::Int
        @debug "  Stack length: $(length(history_stack)), Current index: $(current_index)"
        
        if current_index >= length(history_stack)
            @debug "  Nothing to redo (index >= stack length)"
            return
        end
        
        # Move forward and apply the newValue
        fwd_index = current_index + 1
        _HISTORY_STACK_INDEX[] = fwd_index
        @debug "  New index: $(_HISTORY_STACK_INDEX[])"
        entry = history_stack[fwd_index]
        @debug "  Redoing: $(entry.id).$(entry.property)"
        @debug "  From: $(entry.oldValue)"
        @debug "  To: $(entry.newValue)"
        
        apply_history_value(entry.id, entry.property, entry.newValue)
        @debug "=== END REDO ==="
    end
    
    function apply_history_value(id::String, property::Symbol, value::Any)
        @debug "  Applying value to entity $(id).$(property) = $(value)"
        found = false
        main = JulGame.current_main()
        scene = getfield(main, :scene)::JulGame.SceneModule.Scene
        ents = getfield(scene, :entities)
        for entity in ents
            if entity.id == id
                @debug "  Found entity $(id), setting property"
                setfield!(entity.transform, property, value)
                @debug "  Property set successfully"
                found = true
                break
            end
        end
        if !found
            @warn "  Entity $(id) not found in scene!"
        end
    end
end