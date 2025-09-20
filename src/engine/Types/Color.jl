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
        this.set_hsv()
        this.set_hex()
        return this
    end

    function Color(h::Float64, s::Float64, v::Float64, a::Float64 = 1.0)
        this = new()
        this.h = h
        this.s = s
        this.v = v
        this.a = a
        this.set_rgb()
        this.set_hex()
        return this
    end

    function Color(hex::String, a::Float64 = 1.0)
        this = new()

        this.hex = hex
        this.set_rgb()
        this.set_hsv()

        return this
    end

    function set_rgb(this::Color)
        if isdefined(this, :h) && isdefined(this, :s) && isdefined(this, :v)
            this.r, this.g, this.b = HSVtoRGB(this.h, this.s, this.v)
        elseif isdefined(this, :hex)
            this.r, this.g, this.b = HextoRGB(this.hex)
        end
    end

    function set_hsv(this::Color)
        if isdefined(this, :r) && isdefined(this, :g) && isdefined(this, :b)
            this.h, this.s, this.v = RGBtoHSV(this.r, this.g, this.b)
        elseif isdefined(this, :hex)
            this.h, this.s, this.v = HextoHSV(this.hex)
        end
    end

    function set_hex(this::Color)
        if isdefined(this, :r) && isdefined(this, :g) && isdefined(this, :b)
            this.hex = RGBtoHex(this.r, this.g, this.b)
        elseif isdefined(this, :h) && isdefined(this, :s) && isdefined(this, :v)
            this.hex = HSVtoHex(this.h, this.s, this.v)
        end
    end

    function RGBtoHSV(r::Float64, g::Float64, b::Float64)
    end

    function RGBtoHex(r::Float64, g::Float64, b::Float64)
    end

    function HSVtoRGB(h::Float64, s::Float64, v::Float64)
    end

    function HSVtoHex(h::Float64, s::Float64, v::Float64)
    end

    function HextoRGB(hex::String)
    end

    function HextoHSV(hex::String)
    end
end

export Color