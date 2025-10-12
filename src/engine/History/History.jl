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
            @info "fh on_notify updated_transform oldValue: $(data.oldValue) newValue: $(data.newValue)"
            add_field_history(data.id, data.property, data.oldValue, data.newValue)

        end
    end

    function add_field_history(id::String, property::Symbol, oldValue::Any, newValue::Any)
        fieldHistoryEntry = FieldHistory(property, oldValue, newValue, now())
        if haskey(JulGame.EditorState["HistoryData"], id)
            if haskey(JulGame.EditorState["HistoryData"][id].fieldHistory, property)
                #check if the last element is the same as the new one
                if JulGame.EditorState["HistoryData"][id].fieldHistory[property][end].newValue == newValue
                    return
                end
                # check if the time difference is greater than the minTimeBetweenUpdates
                @info "Time difference: $(fieldHistoryEntry.timestamp - JulGame.EditorState["HistoryData"][id].fieldHistory[property][end].timestamp)"
                if fieldHistoryEntry.timestamp - JulGame.EditorState["HistoryData"][id].fieldHistory[property][end].timestamp < 1.0
                    return
                end
            else
                JulGame.EditorState["HistoryData"][id].fieldHistory[property] = [fieldHistoryEntry]
            end
        else
            JulGame.EditorState["HistoryData"][id] = History(id, fieldHistoryEntry)
        end
    end

    function get_field_history(this::History, property::Symbol)
        return this.fieldHistory[property]
    end
end