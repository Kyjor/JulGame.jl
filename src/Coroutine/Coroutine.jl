module CoroutineModule
    using ..JulGame

    export Coroutine
    mutable struct Coroutine
        condition::Condition
        task::Task

        function Coroutine(condition::Union{Condition, Nothing} = nothing)
            this = new()

            if condition !== nothing
                this.condition = condition
            end

            return this
        end
    end

    function start_coroutine(this::Coroutine, func, params...)
        this.task = @task func(params...)
        schedule(this.task)

        push!(JulGame.Coroutines, this)
        this.condition = isdefined(this, :condition) ? Condition() : JulGame.main_loop().coroutine_condition

        return this
    end

    function start_coroutine(func, params...)
        this = Coroutine(JulGame.main_loop().coroutine_condition)
        this.task = @task func(params...)
        schedule(this.task)

        push!(JulGame.Coroutines, this)

        return this
    end

    function wait_for_coroutine(this::Coroutine)
        wait(this.condition)
    end

    function wait_for_coroutine()
        wait(JulGame.main_loop().coroutine_condition)
    end
end
