macro event(expr)
    esc(:(()->($expr)))
end