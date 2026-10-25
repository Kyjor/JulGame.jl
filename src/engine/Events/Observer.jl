module ObserverModule
    using ..JulGame
    
    ObserverInstance::Union{JulGame.IObserver, Nothing} = nothing
    mutable struct Observer <: JulGame.IObserver
        observers::Vector{ObserverCallback}
        
        function Observer()
            this = new()
            
            this.observers = ObserverCallback[]
            global ObserverInstance = this
            
            return this
        end
    end
    Observer() # Create a new Observer instance

    export add_observer
    function add_observer(observer)
        add_observer(ObserverInstance, observer)
    end

    function add_observer(this::Observer, observer)
        if this === nothing
            @error "ObserverInstance is nothing"
            return
        end
        push!(this.observers, observer)
    end
    
    export remove_observer
    function remove_observer(observer)
        remove_observer(ObserverInstance, observer)
    end
    function remove_observer(this::Observer, observer)
        if this === nothing
            @error "ObserverInstance is nothing"
            return
        end
        filter!(ob -> ob.box.f != observer, this.observers)
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
        for observer in this.observers
            observer(ObserverEvent(event, data))
        end
    end
end