module Macros
    export @event
    macro event(expr)
        esc(:(()->($expr)))
    end
end