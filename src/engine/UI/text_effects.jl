module TextEffectsModule
    using ..UI.JulGame
    using ..UI.JulGame.Math
    import ..UI
    export TextEffect, BevelEffect, InnerGlowEffect, OuterGlowEffect, GradientEffect, StrokeEffect, DropShadowEffect, TextureFillEffect, RGBA

    """
        RGBA

    Lightweight color tuple helper for effect parameters.
    """
    const RGBA = NTuple{4, Int}

    abstract type TextEffect end

    mutable struct BevelEffect <: TextEffect
        depth::Int
        angle::Float64
        highlight_color::RGBA
        shadow_color::RGBA
        intensity::Float64
        function BevelEffect(; depth::Int=2, angle::Real=135, highlight_color::RGBA=(255,255,255,128), shadow_color::RGBA=(0,0,0,128), intensity::Real=1.0)
            new(Math.TypeConversions.safe_int32_convert(depth), float(angle), highlight_color, shadow_color, float(intensity))
        end
    end

    mutable struct InnerGlowEffect <: TextEffect
        radius::Int
        color::RGBA
        blur::Float64
        intensity::Float64
        function InnerGlowEffect(; radius::Int=4, color::RGBA=(255,255,255,128), blur::Real=0.6, intensity::Real=1.0)
            new(Math.TypeConversions.safe_int32_convert(radius), color, float(blur), float(intensity))
        end
    end

    mutable struct OuterGlowEffect <: TextEffect
        radius::Int
        color::RGBA
        blur::Float64
        function OuterGlowEffect(; radius::Int=6, color::RGBA=(255,255,255,180), blur::Real=0.7)
            new(Math.TypeConversions.safe_int32_convert(radius), color, float(blur))
        end
    end

    mutable struct GradientStop
        position::Float64
        color::RGBA
    end

    @enum GradientType begin
        LinearGradient = 1
        RadialGradient = 2
    end

    mutable struct GradientEffect <: TextEffect
        gradientType::GradientType
        stops::Vector{GradientStop}
        angle::Float64
        function GradientEffect(; gradientType::GradientType=LinearGradient, stops::Vector{GradientStop}=GradientStop[], angle::Real=90)
            new(gradientType, stops, float(angle))
        end
    end

    mutable struct StrokeEffect <: TextEffect
        width::Int
        color::RGBA
        quality::Int
        function StrokeEffect(; width::Int=2, color::RGBA=(0,0,0,255), quality::Int=8)
            new(Math.TypeConversions.safe_int32_convert(width), color, Math.TypeConversions.safe_int32_convert(quality))
        end
    end

    mutable struct DropShadowEffect <: TextEffect
        distance::Float64
        angle::Float64
        blur_radius::Int
        color::RGBA
        opacity::Int
        function DropShadowEffect(; distance::Real=3, angle::Real=135, blur_radius::Int=6, color::RGBA=(0,0,0,255), opacity::Int=180)
            new(float(distance), float(angle), Math.TypeConversions.safe_int32_convert(blur_radius), color, Math.TypeConversions.safe_int32_convert(opacity))
        end
    end

    @enum TextureBlendMode begin
        TextureBlendMod = 1
        TextureBlendMul = 2
        TextureBlendAdd = 3
    end

    mutable struct TextureFillEffect <: TextEffect
        texturePath::String
        tile::Bool
        blendMode::TextureBlendMode
        opacity::Int
        function TextureFillEffect(; texturePath::String="", tile::Bool=true, blendMode::TextureBlendMode=TextureBlendMod, opacity::Int=255)
            new(texturePath, tile, blendMode, Math.TypeConversions.safe_int32_convert(opacity))
        end
    end
end


