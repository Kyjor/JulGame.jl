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
        property::Symbol
        oldValue::Any
        newValue::Any
        timestamp::DateTime
    end

    function FieldHistory(property::Symbol, oldValue::Any, newValue::Any)
        return FieldHistory(property, oldValue, newValue, now())
    end

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
        # Ensure HistoryData is initialized
        if !haskey(JulGame.EditorState, "HistoryData")
            JulGame.EditorState["HistoryData"] = Dict{String, History}()
        end
        
        fieldHistoryEntry = FieldHistory(property, oldValue, newValue, now())
        history_data = JulGame.EditorState["HistoryData"]
        
        if haskey(history_data, id)
            if haskey(history_data[id].fieldHistory, property)
                # Check if the last element is the same as the new one
                last_field_history = history_data[id].fieldHistory[property][end]
                if last_field_history.newValue == newValue
                    return
                end
                
                # Check if the time difference is greater than the minTimeBetweenUpdates (in milliseconds)
                time_diff = fieldHistoryEntry.timestamp - last_field_history.timestamp
                time_diff_ms = Dates.value(time_diff)  # Convert Millisecond to Int64
                if time_diff_ms < 1000  # Less than 1 second (1000 milliseconds)
                    return
                end
                
                @debug "Time difference: $(time_diff_ms) milliseconds"
                @debug "fh on_notify updated_transform oldValue: $(last_field_history.newValue) newValue: $(newValue)"
                push!(history_data[id].fieldHistory[property], fieldHistoryEntry)
                push!(JulGame.EditorState["HistoryStack"], "$(id)_$(property)")
            else
                history_data[id].fieldHistory[property] = [fieldHistoryEntry]
                push!(JulGame.EditorState["HistoryStack"], "$(id)_$(property)")
            end
        else
            history_data[id] = History(id, fieldHistoryEntry)
            push!(JulGame.EditorState["HistoryStack"], "$(id)_$(property)")
        end
        JulGame.EditorState["HistoryStackIndex"] = length(JulGame.EditorState["HistoryStack"])
    end

    function get_field_history(this::History, property::Symbol)
        return this.fieldHistory[property]
    end

    export undo
    function undo()
        # Implement undo
        history_data = JulGame.EditorState["HistoryData"]
        history_stack = JulGame.EditorState["HistoryStack"]
        if length(history_stack) > 0 && JulGame.EditorState["HistoryStackIndex"] > 1
            history_entry = history_stack[JulGame.EditorState["HistoryStackIndex"] - 1]
            id, property = split(history_entry, "_")

            undo_field_history(string(id), Symbol(property), JulGame.EditorState["HistoryStackIndex"] - 1)
            JulGame.EditorState["HistoryStackIndex"] -= 1
        end
    end

    function undo_field_history(id::String, property::Symbol, history_stack_index::Int)
        history_data = JulGame.EditorState["HistoryData"]
        oldValue = history_data[id].fieldHistory[property][history_stack_index].oldValue
        @info "undo_field_history oldValue: $(oldValue)"
        for entity in MAIN.scene.entities
            if entity.id == id
                setfield!(entity.transform, property, oldValue)
                @info "undo_field_history set property: $(property) to: $(oldValue)"
                break
            end
        end
    end

    export redo
    function redo()
        @info "not implemented"
       # redo_field_history(this, property)
    end
end