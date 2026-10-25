module Macros
    export @event
    macro event(expr)
        esc(:(()->($expr)))
    end

    export @argevent
    macro argevent(args, expr)
        esc(:(($args)->($expr)))
    end

    export @timed_step
    """
        @timed_step label expr

    Evaluates `expr` and prints how long it took. Replaces `@time`, whose reporting is not supported by `juliac --trim`.
    """
    macro timed_step(label, expr)
        quote
            local startTime = time_ns()
            local result = $(esc(expr))
            $(GlobalRef(parentmodule(@__MODULE__), :print_line))(string($(esc(label)), ": ", round((time_ns() - startTime) / 1e9; digits = 4), " seconds"))
            result
        end
    end
end
