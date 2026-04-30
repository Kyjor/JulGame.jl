# The variable x represents the absolute progress of the animation in the bounds of 0 (beginning of the animation) and 1 (end of animation).

# https://easings.net/#easeInSine
function ease_in_sine(x::Float64) :: Float64
    return 1 - cos((x * π) / 2)
end

# https://easings.net/#easeOutSine
function ease_out_sine(x::Float64) :: Float64
    return sin((x * π) / 2)
end

# https://easings.net/#easeInOutSine
function ease_in_out_sine(x::Float64) :: Float64
    return -(cos(π * x) - 1) / 2
end

# https://easings.net/#easeInQuad
function ease_in_quad(x::Float64) :: Float64
    return x ^ 2
end

# https://easings.net/#easeOutQuad
function ease_out_quad(x::Float64) :: Float64
    return 1 - (1 - x) ^ 2
end

# https://easings.net/#easeInOutQuad
function ease_in_out_quad(x::Float64) :: Float64
    return x < 0.5 ? 2 * x ^ 2 : 1 - (-2 * x + 2) ^ 2 / 2
end

# https://easings.net/#easeInCubic
function ease_in_cubic(x::Float64) :: Float64
    return x ^ 3
end

# https://easings.net/#easeOutCubic
function ease_out_cubic(x::Float64) :: Float64
    return 1 - (1 - x) ^ 3
end

# https://easings.net/#easeInOutCubic
function ease_in_out_cubic(x::Float64) :: Float64
    return x < 0.5 ? 4 * x ^ 3 : 1 - (-2 * x + 2) ^ 3 / 2
end

# https://easings.net/#easeInQuart
function ease_in_quart(x::Float64) :: Float64
    return x ^ 4
end

# https://easings.net/#easeOutQuart
function ease_out_quart(x::Float64) :: Float64
    return 1 - (1 - x) ^ 4
end

# https://easings.net/#easeInOutQuart
function ease_in_out_quart(x::Float64) :: Float64
    return x < 0.5 ? 8 * x ^ 4 : 1 - (-2 * x + 2) ^ 4 / 2
end

# https://easings.net/#easeInQuint
function ease_in_quint(x::Float64) :: Float64
    return x ^ 5
end

# https://easings.net/#easeOutQuint
function ease_out_quint(x::Float64) :: Float64
    return 1 - (1 - x) ^ 5
end

# https://easings.net/#easeInOutQuint
function ease_in_out_quint(x::Float64) :: Float64
    return x < 0.5 ? 16 * x ^ 5 : 1 - (-2 * x + 2) ^ 5 / 2
end

# https://easings.net/#easeInExpo
function ease_in_expo(x::Float64) :: Float64
    return x == 0 ? 0 : 2 ^ (10 * x - 10)
end

# https://easings.net/#easeOutExpo
function ease_out_expo(x::Float64) :: Float64
    return x == 1 ? 1 : 1 - 2 ^ (-10 * x)
end

# https://easings.net/#easeInOutExpo
function ease_in_out_expo(x::Float64) :: Float64
    return x == 0 ? 0 : x == 1 ? 1 : x < 0.5 ? 2 ^ (20 * x - 10) / 2 : (2 - 2 ^ (-20 * x + 10)) / 2
end

# https://easings.net/#easeInCirc
function ease_in_circ(x::Float64) :: Float64
    return 1 - sqrt(1 - x ^ 2)
end

# https://easings.net/#easeOutCirc
function ease_out_circ(x::Float64) :: Float64
    return sqrt(1 - (x - 1) ^ 2)
end

# https://easings.net/#easeInOutCirc
function ease_in_out_circ(x::Float64) :: Float64
    return x < 0.5 ? (1 - sqrt(1 - (2 * x) ^ 2)) / 2 : (sqrt(1 - (-2 * x + 2) ^ 2) + 1) / 2
end

# https://easings.net/#easeInBack
function ease_in_back(x::Float64) :: Float64
    c1 = 1.70158
    c3 = c1 + 1
    
    return c3 * x ^ 3 - c1 * x ^ 2
end

################################
# https://easings.net/#easeOutBack
function ease_out_back(x::Float64) :: Float64
    c1 = 1.70158
    c3 = c1 + 1
    
    return 1 + c3 * (x - 1) ^ 3 + c1 * (x - 1) ^ 2
end

# https://easings.net/#easeInOutBack
function ease_in_out_back(x::Float64) :: Float64
    c1 = 1.70158
    c2 = c1 * 1.525
    
    return x < 0.5 ? (2 * x) ^ 2 * ((c2 + 1) * 2 * x - c2) / 2 : ((2 * x - 2) ^ 2 * ((c2 + 1) * (x * 2 - 2) + c2) + 2) / 2
end

# https://easings.net/#easeInElastic
function ease_in_elastic(x::Float64) :: Float64
    c4 = (2 * π) / 3
    
    return x == 0 ? 0 : x == 1 ? 1 : -(2 ^ (10 * x - 10) * sin((x * 10 - 0.75) * c4))
end


# https://easings.net/#easeOutElastic
function ease_out_elastic(x::Float64) :: Float64
    c4 = (2 * π) / 3
    
    return x == 0 ? 0 : x == 1 ? 1 : 2 ^ (-10 * x) * sin((x * 10 - 0.75) * c4) + 1
end

# https://easings.net/#easeInOutElastic
function ease_in_out_elastic(x::Float64) :: Float64
    c5 = (2 * π) / 4.5
    
    return x == 0 ? 0 : x == 1 ? 1 : x < 0.5 ? -(2 ^ (20 * x - 10) * sin((20 * x - 11.125) * c5)) / 2 : 2 ^ (-20 * x + 10) * sin((20 * x - 11.125) * c5) / 2 + 1
end

# https://easings.net/#easeInBounce
function ease_in_bounce(x::Float64) :: Float64
    return 1 - ease_out_bounce(1 - x)
end

# https://easings.net/#easeOutBounce
function ease_out_bounce(x::Float64) :: Float64
    n1 = 7.5625
    d1 = 2.75
    
    if x < 1 / d1
        return n1 * x ^ 2
    elseif x < 2 / d1
        return n1 * (x - 1.5 / d1) ^ 2 + 0.75
    elseif x < 2.5 / d1
        return n1 * (x - 2.25 / d1) ^ 2 + 0.9375
    else
        return n1 * (x - 2.625 / d1) ^ 2 + 0.984375
    end
end

# https://easings.net/#easeInOutBounce
function ease_in_out_bounce(x::Float64) :: Float64
    return x < 0.5 ? (1 - ease_out_bounce(1 - 2 * x)) / 2 : (1 + ease_out_bounce(2 * x - 1)) / 2
end