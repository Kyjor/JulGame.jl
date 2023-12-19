function Lerp(a::Number, b::Number, t::Number)
    if t < 0.0
        t = 0.0
    elseif t > 1.0
        t = 1.0
    end
    
    res = a + t * (b - a)
end

# Smooth lerp function with quadratic easing-in-out
function SmoothLerp(start::Number, stop::Number, t::Number)
    t = clamp(t, 0.0, 1.0)  # Ensure t is within the range [0, 1]
    t = 0.5 - 0.5 * cos(pi * t)  # Apply quadratic easing-in-out
    return (1.0 - t) * start + t * stop
end
