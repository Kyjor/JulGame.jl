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
        # @info "=== ADD_FIELD_HISTORY CALLED ==="
        # @info "  ID: $(id)"
        # @info "  Property: $(property)"
        # @info "  Old Value: $(oldValue)"
        # @info "  New Value: $(newValue)"
        
        # Ensure HistoryStack is initialized
        if !haskey(JulGame.EditorState, "HistoryStack")
            JulGame.EditorState["HistoryStack"] = FieldHistory[]
            @info "  Initialized new HistoryStack"
        end
        if !haskey(JulGame.EditorState, "HistoryStackIndex")
            JulGame.EditorState["HistoryStackIndex"] = 0
            @info "  Initialized HistoryStackIndex to 0"
        end
        
        history_stack = JulGame.EditorState["HistoryStack"]
        current_index = JulGame.EditorState["HistoryStackIndex"]
        #@info "  Current stack length: $(length(history_stack)), Current index: $(current_index)"
        
        # Check if the last change is the same (deduplicate)
        if current_index > 0
            last_entry = history_stack[current_index]
            #@info "  Last entry: $(last_entry.id).$(last_entry.property) = $(last_entry.newValue)"
            if last_entry.id == id && last_entry.property == property && last_entry.newValue == newValue
                #@info "  SKIPPED: Duplicate value"
                return
            end
            
            # Check time difference for same property
            if last_entry.id == id && last_entry.property == property
                time_diff = now() - last_entry.timestamp
                time_diff_ms = Dates.value(time_diff)
                # @info "  Time difference: $(time_diff_ms)ms"
                if time_diff_ms < 1000  # Less than 1 second
                #    @info "  SKIPPED: Too soon (< 1000ms)"
                    # update the last entry with the new value
                    last_entry.newValue = newValue
                    last_entry.timestamp = now()
                    return
                end
            end
        end
        
        # Truncate future history if we're not at the end
        if current_index < length(history_stack)
            @info "  TRUNCATING: stack from $(length(history_stack)) to $(current_index)"
            resize!(history_stack, current_index)
        end
        
        # Create new entry with id embedded
        entry = FieldHistory(id, property, oldValue, newValue, now())
        push!(history_stack, entry)
        JulGame.EditorState["HistoryStackIndex"] = length(history_stack)
        @info "  ADDED: Stack length now $(length(history_stack)), Index now $(JulGame.EditorState["HistoryStackIndex"])"
        @info "=== END ADD_FIELD_HISTORY ==="
    end
    
    export undo
    function undo()
        @info "=== UNDO CALLED ==="
        if !haskey(JulGame.EditorState, "HistoryStack") || !haskey(JulGame.EditorState, "HistoryStackIndex")
            @warn "  History not initialized"
            return
        end
        
        history_stack = JulGame.EditorState["HistoryStack"]
        current_index = JulGame.EditorState["HistoryStackIndex"]
        @info "  Stack length: $(length(history_stack)), Current index: $(current_index)"
        
        if current_index < 1
            @info "  Nothing to undo (index < 1)"
            return
        end
        
        # Get the entry at current index and apply its oldValue
        entry = history_stack[current_index]
        @info "  Undoing: $(entry.id).$(entry.property)"
        @info "  From: $(entry.newValue)"
        @info "  To: $(entry.oldValue)"
        
        apply_history_value(entry.id, entry.property, entry.oldValue)
        JulGame.EditorState["HistoryStackIndex"] -= 1
        @info "  New index: $(JulGame.EditorState["HistoryStackIndex"])"
        @info "=== END UNDO ==="
    end
    
    export redo
    function redo()
        @info "=== REDO CALLED ==="
        if !haskey(JulGame.EditorState, "HistoryStack") || !haskey(JulGame.EditorState, "HistoryStackIndex")
            @warn "  History not initialized"
            return
        end
        
        history_stack = JulGame.EditorState["HistoryStack"]
        current_index = JulGame.EditorState["HistoryStackIndex"]
        @info "  Stack length: $(length(history_stack)), Current index: $(current_index)"
        
        if current_index >= length(history_stack)
            @info "  Nothing to redo (index >= stack length)"
            return
        end
        
        # Move forward and apply the newValue
        JulGame.EditorState["HistoryStackIndex"] += 1
        @info "  New index: $(JulGame.EditorState["HistoryStackIndex"])"
        entry = history_stack[JulGame.EditorState["HistoryStackIndex"]]
        @info "  Redoing: $(entry.id).$(entry.property)"
        @info "  From: $(entry.oldValue)"
        @info "  To: $(entry.newValue)"
        
        apply_history_value(entry.id, entry.property, entry.newValue)
        @info "=== END REDO ==="
    end
    
    function apply_history_value(id::String, property::Symbol, value::Any)
        @info "  Applying value to entity $(id).$(property) = $(value)"
        found = false
        for entity in MAIN.scene.entities
            if entity.id == id
                @info "  Found entity $(id), setting property"
                setfield!(entity.transform, property, value)
                @info "  Property set successfully"
                found = true
                break
            end
        end
        if !found
            @warn "  Entity $(id) not found in scene!"
        end
    end
end