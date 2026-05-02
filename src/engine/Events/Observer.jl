module ObserverModule
    using ..JulGame
    
    ObserverInstance::Union{JulGame.IObserver, Nothing} = nothing
    mutable struct Observer <: JulGame.IObserver
        observers::Vector{Function}
        
        function Observer()
            this = new()
            
            this.observers = []
            global ObserverInstance = this
            
            return this
        end
    end
    Observer() # Create a new Observer instance

    @Base.noinline function _observer_invoke_all!(observers::Vector{Function}, event::Symbol, data::Any)::Nothing
        for observer in observers
            observer(event, data)
        end
        return nothing
    end

    export add_observer
    function add_observer(observer::Function)
        add_observer(ObserverInstance, observer)
    end

    function add_observer(this::Observer, observer::Function)
        if this === nothing
            @error "ObserverInstance is nothing"
            return
        end
        push!(this.observers, observer)
    end
    
    export remove_observer
    function remove_observer(observer::Function)
        remove_observer(ObserverInstance, observer)
    end
    function remove_observer(this::Observer, observer::Function)
        if this === nothing
            @error "ObserverInstance is nothing"
            return
        end
        filter!(ob -> ob != observer, this.observers)
    end

    export notify_observer
    function notify_observer(event::Symbol, data::Any=nothing)
        notify_observer(ObserverInstance, event, data)
    end
    
    function notify_observer(this::Observer, event::Symbol, data::Any=nothing)
        if this === nothing
            @error "ObserverInstance is nothing"
            return
        end
        JulGame.juliac_trim_active() && return nothing
        _observer_invoke_all!(this.observers, event, data)
    end
end