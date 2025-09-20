"""
# color

A color is a tuple of 4 floats, representing the red, green, blue, and alpha values of the color.
It also has the hue, saturation, and value values of the color that are calculated from the rgb values.
It also has the hex value of the color that is calculated from the rgb values.
"""
mutable struct Color
    r::Float64
    g::Float64
    b::Float64
    a::Float64

    h::Float64
    s::Float64
    v::Float64

    hex::String
    hexAlpha::String

    function Color(r::Float64, g::Float64, b::Float64, a::Float64 = 1.0)
        this = new()
        this.r = r
        this.g = g
        this.b = b
        this.a = a
        this.h, this.s, this.v = RGBtoHSV(r, g, b)
        this.hex = RGBtoHex(r, g, b)
        this.hexAlpha = RGBtoHexAlpha(r, g, b, a)
        return this
    end

    function Color(h::Float64, s::Float64, v::Float64, a::Float64 = 1.0)
        this = new()
        this.h = h
        this.s = s
        this.v = v
        this.a = a
        this.r, this.g, this.b = HSVtoRGB(h, s, v)
        this.hex = RGBtoHex(this.r, this.g, this.b)
        this.hexAlpha = RGBtoHexAlpha(this.r, this.g, this.b, a)
        return this
    end

    function Color(hex::String, a::Float64 = 1.0)
        this = new()
        this.a = a
        this.hex = hex
        this.r, this.g, this.b = HextoRGB(hex)
        this.h, this.s, this.v = RGBtoHSV(this.r, this.g, this.b)
        this.hexAlpha = RGBtoHexAlpha(this.r, this.g, this.b, a)
        return this
    end

end

# Color conversion functions (moved outside the struct)
function RGBtoHSV(r::Float64, g::Float64, b::Float64)
    # Clamp values to [0, 1]
    r, g, b = clamp(r, 0.0, 1.0), clamp(g, 0.0, 1.0), clamp(b, 0.0, 1.0)
    
    max_val = max(r, g, b)
    min_val = min(r, g, b)
    delta = max_val - min_val
    
    # Value
    v = max_val
    
    # Saturation
    s = max_val == 0.0 ? 0.0 : delta / max_val
    
    # Hue
    h = if delta == 0.0
        0.0
    elseif max_val == r
        60.0 * (((g - b) / delta) % 6.0)
    elseif max_val == g
        60.0 * ((b - r) / delta + 2.0)
    else # max_val == b
        60.0 * ((r - g) / delta + 4.0)
    end
    
    h = h < 0.0 ? h + 360.0 : h
    
    return h, s, v
end

function RGBtoHex(r::Float64, g::Float64, b::Float64)
    # Clamp values to [0, 1] and convert to [0, 255]
    r_int = round(Int, clamp(r, 0.0, 1.0) * 255)
    g_int = round(Int, clamp(g, 0.0, 1.0) * 255)
    b_int = round(Int, clamp(b, 0.0, 1.0) * 255)
    
    return string("#", lpad(string(r_int, base=16), 2, "0"), 
                      lpad(string(g_int, base=16), 2, "0"), 
                      lpad(string(b_int, base=16), 2, "0"))
end

function RGBtoHexAlpha(r::Float64, g::Float64, b::Float64, a::Float64)
    # Clamp values to [0, 1] and convert to [0, 255]
    r_int = round(Int, clamp(r, 0.0, 1.0) * 255)
    g_int = round(Int, clamp(g, 0.0, 1.0) * 255)
    b_int = round(Int, clamp(b, 0.0, 1.0) * 255)
    a_int = round(Int, clamp(a, 0.0, 1.0) * 255)
    
    return string("#", lpad(string(r_int, base=16), 2, "0"), 
                      lpad(string(g_int, base=16), 2, "0"), 
                      lpad(string(b_int, base=16), 2, "0"),
                      lpad(string(a_int, base=16), 2, "0"))
end

function HSVtoRGB(h::Float64, s::Float64, v::Float64)
    # Normalize hue to [0, 360) and clamp s, v to [0, 1]
    h = mod(h, 360.0)
    s = clamp(s, 0.0, 1.0)
    v = clamp(v, 0.0, 1.0)
    
    c = v * s
    x = c * (1.0 - abs(mod(h / 60.0, 2.0) - 1.0))
    m = v - c
    
    r_prime, g_prime, b_prime = if h < 60.0
        c, x, 0.0
    elseif h < 120.0
        x, c, 0.0
    elseif h < 180.0
        0.0, c, x
    elseif h < 240.0
        0.0, x, c
    elseif h < 300.0
        x, 0.0, c
    else
        c, 0.0, x
    end
    
    return r_prime + m, g_prime + m, b_prime + m
end

function HSVtoHex(h::Float64, s::Float64, v::Float64)
    r, g, b = HSVtoRGB(h, s, v)
    return RGBtoHex(r, g, b)
end

function HextoRGB(hex::String)
    # Remove '#' if present and validate length
    hex_clean = startswith(hex, "#") ? hex[2:end] : hex
    
    if length(hex_clean) == 3
        # Short form: #RGB -> #RRGGBB
        hex_clean = string(hex_clean[1], hex_clean[1], hex_clean[2], hex_clean[2], hex_clean[3], hex_clean[3])
    elseif length(hex_clean) != 6
        throw(ArgumentError("Invalid hex color format. Expected #RGB or #RRGGBB, got: $hex"))
    end
    
    r = parse(Int, hex_clean[1:2], base=16) / 255.0
    g = parse(Int, hex_clean[3:4], base=16) / 255.0
    b = parse(Int, hex_clean[5:6], base=16) / 255.0
    
    return r, g, b
end

function HextoHSV(hex::String)
    r, g, b = HextoRGB(hex)
    return RGBtoHSV(r, g, b)
end

# Utility functions for Color
function Base.:(==)(c1::Color, c2::Color)
    return c1.r ≈ c2.r && c1.g ≈ c2.g && c1.b ≈ c2.b && c1.a ≈ c2.a
end

function Base.show(io::IO, c::Color)
    print(io, "Color(r=$(c.r), g=$(c.g), b=$(c.b), a=$(c.a), hex=\"$(c.hex)\")")
end

# Update color values and sync all representations
function update_rgb!(c::Color, r::Float64, g::Float64, b::Float64)
    c.r = clamp(r, 0.0, 1.0)
    c.g = clamp(g, 0.0, 1.0)
    c.b = clamp(b, 0.0, 1.0)
    c.h, c.s, c.v = RGBtoHSV(c.r, c.g, c.b)
    c.hex = RGBtoHex(c.r, c.g, c.b)
    c.hexAlpha = RGBtoHexAlpha(c.r, c.g, c.b, c.a)
end

function update_hsv!(c::Color, h::Float64, s::Float64, v::Float64)
    c.h = mod(h, 360.0)
    c.s = clamp(s, 0.0, 1.0)
    c.v = clamp(v, 0.0, 1.0)
    c.r, c.g, c.b = HSVtoRGB(c.h, c.s, c.v)
    c.hex = RGBtoHex(c.r, c.g, c.b)
    c.hexAlpha = RGBtoHexAlpha(c.r, c.g, c.b, c.a)
end

function update_alpha!(c::Color, a::Float64)
    c.a = clamp(a, 0.0, 1.0)
    c.hexAlpha = RGBtoHexAlpha(c.r, c.g, c.b, c.a)
end

# Common color constants
const WHITE = Color(1.0, 1.0, 1.0, 1.0)
const BLACK = Color(0.0, 0.0, 0.0, 1.0)
const RED = Color(1.0, 0.0, 0.0, 1.0)
const GREEN = Color(0.0, 1.0, 0.0, 1.0)
const BLUE = Color(0.0, 0.0, 1.0, 1.0)
const YELLOW = Color(1.0, 1.0, 0.0, 1.0)
const CYAN = Color(0.0, 1.0, 1.0, 1.0)
const MAGENTA = Color(1.0, 0.0, 1.0, 1.0)
const TRANSPARENT = Color(0.0, 0.0, 0.0, 0.0)

export Color, WHITE, BLACK, RED, GREEN, BLUE, YELLOW, CYAN, MAGENTA, TRANSPARENT
export update_rgb!, update_hsv!, update_alpha!
export RGBtoHSV, RGBtoHex, RGBtoHexAlpha, HSVtoRGB, HSVtoHex, HextoRGB, HextoHSV