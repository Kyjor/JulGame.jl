"""
# Linear Interpolation
--- Argument list
- `a::Real` from
- `b::Real` to
- `t::Real` Earring
"""
function Lerp(a::Real, b::Real, t::Real)
    # t ∈ [0,1] 
    t = (t < 0.0) ? 0.0 : (t > 1.0) ? 1.0 : t
    
    return a + t * (b - a)
end

"""
# Smooth lerp function with quadratic easing-in-out
--- Argument list
- `start::Real`
- `stop::Real`
- `t::Real` Earring
"""
function SmoothLerp(start::Real, stop::Real, t::Real)
    t = clamp(t, 0.0, 1.0)  # Ensure t ∈ [0, 1]
    t = 0.5 - 0.5 * cos(pi * t)  # Apply quadratic easing-in-out
    return (1.0 - t) * start + t * stop
end
