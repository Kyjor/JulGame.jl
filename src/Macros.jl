macro event(expr)
    esc(:(()->($expr)))
end

macro datatype(expr) 
    esc(:($(Symbol(expr))) )
end