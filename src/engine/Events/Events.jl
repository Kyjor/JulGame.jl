module EventsModule
    using ..JulGame
    include("Observer.jl")
    export ObserverModule, add_observer, remove_observer, notify_observer
end