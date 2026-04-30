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

    # Note: This struct is kept for backward compatibility but is no longer actively used
    # History is now stored as a flat array in EditorState["HistoryStack"]
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
    JulGame.EventsModule.ObserverModule.add_observer((event, data) -> on_notify(event, data))

    function on_notify(event::Symbol, data::Any)
        if event == :updated_transform
            add_field_history(data.id, data.property, data.oldValue, data.newValue)

        end
    end

    function add_field_history(id::String, property::Symbol, oldValue::Any, newValue::Any)
        # @debug "=== ADD_FIELD_HISTORY CALLED ==="
        # @debug "  ID: $(id)"
        # @debug "  Property: $(property)"
        # @debug "  Old Value: $(oldValue)"
        # @debug "  New Value: $(newValue)"
        
        # Ensure HistoryStack is initialized
        if !haskey(JulGame.EditorState, "HistoryStack")
            JulGame.EditorState["HistoryStack"] = FieldHistory[]
            @debug "  Initialized new HistoryStack"
        end
        if !haskey(JulGame.EditorState, "HistoryStackIndex")
            JulGame.EditorState["HistoryStackIndex"] = 0
            @debug "  Initialized HistoryStackIndex to 0"
        end
        
        history_stack = JulGame.EditorState["HistoryStack"]
        current_index = JulGame.EditorState["HistoryStackIndex"]
        #@debug "  Current stack length: $(length(history_stack)), Current index: $(current_index)"
        
        # Check if the last change is the same (deduplicate)
        if current_index > 0
            last_entry = history_stack[current_index]
            #@debug "  Last entry: $(last_entry.id).$(last_entry.property) = $(last_entry.newValue)"
            if last_entry.id == id && last_entry.property == property && last_entry.newValue == newValue
                #@debug "  SKIPPED: Duplicate value"
                return
            end
            
            # Check time difference for same property
            if last_entry.id == id && last_entry.property == property
                time_diff = now() - last_entry.timestamp
                time_diff_ms = Dates.value(time_diff)
                # @debug "  Time difference: $(time_diff_ms)ms"
                if time_diff_ms < 1000  # Less than 1 second
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
        JulGame.EditorState["HistoryStackIndex"] = length(history_stack)
        @debug "  ADDED: Stack length now $(length(history_stack)), Index now $(JulGame.EditorState["HistoryStackIndex"])"
        @debug "=== END ADD_FIELD_HISTORY ==="
    end
    
    export undo
    function undo()
        @debug "=== UNDO CALLED ==="
        if !haskey(JulGame.EditorState, "HistoryStack") || !haskey(JulGame.EditorState, "HistoryStackIndex")
            @warn "  History not initialized"
            return
        end
        
        history_stack = JulGame.EditorState["HistoryStack"]
        current_index = JulGame.EditorState["HistoryStackIndex"]
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
        JulGame.EditorState["HistoryStackIndex"] -= 1
        @debug "  New index: $(JulGame.EditorState["HistoryStackIndex"])"
        @debug "=== END UNDO ==="
    end
    
    export redo
    function redo()
        @debug "=== REDO CALLED ==="
        if !haskey(JulGame.EditorState, "HistoryStack") || !haskey(JulGame.EditorState, "HistoryStackIndex")
            @warn "  History not initialized"
            return
        end
        
        history_stack = JulGame.EditorState["HistoryStack"]
        current_index = JulGame.EditorState["HistoryStackIndex"]
        @debug "  Stack length: $(length(history_stack)), Current index: $(current_index)"
        
        if current_index >= length(history_stack)
            @debug "  Nothing to redo (index >= stack length)"
            return
        end
        
        # Move forward and apply the newValue
        JulGame.EditorState["HistoryStackIndex"] += 1
        @debug "  New index: $(JulGame.EditorState["HistoryStackIndex"])"
        entry = history_stack[JulGame.EditorState["HistoryStackIndex"]]
        @debug "  Redoing: $(entry.id).$(entry.property)"
        @debug "  From: $(entry.oldValue)"
        @debug "  To: $(entry.newValue)"
        
        apply_history_value(entry.id, entry.property, entry.newValue)
        @debug "=== END REDO ==="
    end
    
    function apply_history_value(id::String, property::Symbol, value::Any)
        @debug "  Applying value to entity $(id).$(property) = $(value)"
        found = false
        for entity in MAIN.scene.entities
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