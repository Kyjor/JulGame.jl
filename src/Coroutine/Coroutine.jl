module CoroutineModule
    using ..JulGame

    export Coroutine
    mutable struct Coroutine
        condition::Union{Nothing, Base.Condition}
        task::Union{Nothing, Task}

        function Coroutine(condition = nothing)
            return new(condition, nothing)
        end
    end

    function start_coroutine(this::Coroutine, func, params...)
        this.task = @task func(params...)
        schedule(this.task)

        push!(JulGame.Coroutines, this)
        this.condition = this.condition === nothing ? MAIN.coroutine_condition : Base.Condition()

        return this
    end

    function start_coroutine(func, params...)
        this = Coroutine(MAIN.coroutine_condition)
        this.task = @task func(params...)
        schedule(this.task)

        push!(JulGame.Coroutines, this)

        return this
    end

    function wait_for_coroutine(this::Coroutine)
        wait(this.condition)
    end

    function wait_for_coroutine()
        wait(MAIN.coroutine_condition)
    end
end
