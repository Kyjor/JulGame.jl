module EffectsModule
    using SimpleDirectMediaLayer
    const SDL2 = SimpleDirectMediaLayer
    import ...JulGame
    const Math = JulGame.Math
    const Component = JulGame.Component
    
    export Effect, EffectTarget, EffectStyle
    export BevelEffect, DropShadowEffect, OuterGlowEffect
    export InnerGlowEffect, StrokeEffect, GradientEffect
    export TextureFillEffect, RoughEdgeEffect, InvertEffect
    export SurfaceTarget, TextureTarget, SpriteTarget, RectangleTarget, LineTarget, ImageTarget, Mesh3DTarget
    export apply_effects!, apply_style!, create_button_style, create_panel_style, create_text_style
    export INHERIT_COLOR
    
    # Special color value to inherit from original
    const INHERIT_COLOR = (-1, -1, -1, -1)
    
    # Abstract types
    abstract type Effect end
    abstract type EffectTarget end
    
    # Effect target types
    mutable struct SurfaceTarget <: EffectTarget
        surface::Ptr{SDL2.SDL_Surface}
        width::Int
        height::Int
        original_color::NTuple{4, Int}
        function SurfaceTarget(surface::Ptr{SDL2.SDL_Surface}, original_color::NTuple{4, Int}=(255, 255, 255, 255))
            if surface == C_NULL
                new(C_NULL, 0, 0, original_color)
            else
                arr = unsafe_wrap(Array, surface, 10; own=false)
                new(surface, arr[1].w, arr[1].h, original_color)
            end
        end
    end
    
    mutable struct TextureTarget <: EffectTarget
        texture::Ptr{SDL2.SDL_Texture}
        width::Int
        height::Int
        function TextureTarget(texture::Ptr{SDL2.SDL_Texture})
            if texture == C_NULL
                new(C_NULL, 0, 0)
            else
                w = Ref{Cint}(0); h = Ref{Cint}(0)
                SDL2.SDL_QueryTexture(texture, C_NULL, C_NULL, w, h)
                new(texture, w[], h[])
            end
        end
    end
    
    mutable struct SpriteTarget <: EffectTarget
        sprite::Any  # InternalSprite
        function SpriteTarget(sprite::Any)
            new(sprite)
        end
    end
    
    mutable struct RectangleTarget <: EffectTarget
        rectangle::Any  # Rectangle
        function RectangleTarget(rectangle::Any)
            new(rectangle)
        end
    end
    
    mutable struct LineTarget <: EffectTarget
        line::Any  # Line
        function LineTarget(line::Any)
            new(line)
        end
    end
    
    mutable struct ImageTarget <: EffectTarget
        image::Any  # UIImage
        function ImageTarget(image::Any)
            new(image)
        end
    end
    
    mutable struct Mesh3DTarget <: EffectTarget
        mesh::Any  # Mesh3D
        function Mesh3DTarget(mesh::Any)
            new(mesh)
        end
    end
    
    #  effect types (extending existing text effects)
    mutable struct BevelEffect <: Effect
        depth::Int
        angle::Float64
        highlight_color::NTuple{4, Int}
        shadow_color::NTuple{4, Int}
        intensity::Float64
        function BevelEffect(; depth::Int=2, angle::Float64=135.0, highlight_color::NTuple{4, Int}=(255,255,255,100), shadow_color::NTuple{4, Int}=(0,0,0,120), intensity::Float64=0.8)
            new(Math.TypeConversions.safe_int32_convert(depth), angle, highlight_color, shadow_color, intensity)
        end
    end
    
    mutable struct DropShadowEffect <: Effect
        distance::Float64
        angle::Float64
        blur_radius::Int
        color::NTuple{4, Int}
        opacity::Int
        function DropShadowEffect(; distance::Float64=3.0, angle::Float64=135.0, blur_radius::Int=6, color::NTuple{4, Int}=(0,0,0,255), opacity::Int=180)
            new(distance, angle, Math.TypeConversions.safe_int32_convert(blur_radius), color, Math.TypeConversions.safe_int32_convert(opacity))
        end
    end
    
    mutable struct OuterGlowEffect <: Effect
        radius::Int
        color::NTuple{4, Int}
        blur::Float64
        function OuterGlowEffect(; radius::Int=6, color::NTuple{4, Int}=(255,255,255,140), blur::Float64=0.7)
            new(Math.TypeConversions.safe_int32_convert(radius), color, blur)
        end
    end
    
    mutable struct InnerGlowEffect <: Effect
        radius::Int
        color::NTuple{4, Int}
        function InnerGlowEffect(; radius::Int=4, color::NTuple{4, Int}=(255,255,255,100))
            new(Math.TypeConversions.safe_int32_convert(radius), color)
        end
    end
    
    mutable struct StrokeEffect <: Effect
        width::Int
        color::NTuple{4, Int}
        function StrokeEffect(; width::Int=2, color::NTuple{4, Int}=(0,0,0,255))
            new(Math.TypeConversions.safe_int32_convert(width), color)
        end
    end
    
    mutable struct GradientEffect <: Effect
        gradientType::String
        stops::Vector{Tuple{Float64, NTuple{4, Int}}}
        angle::Float64
        function GradientEffect(; gradientType::String="LinearGradient", stops::Vector{Tuple{Float64, NTuple{4, Int}}}=[], angle::Float64=0.0)
            new(gradientType, stops, angle)
        end
    end
    
    mutable struct TextureFillEffect <: Effect
        texturePath::String
        tile::Bool
        blendMode::Int
        opacity::Int
        function TextureFillEffect(; texturePath::String="", tile::Bool=true, blendMode::Int=1, opacity::Int=255)
            new(texturePath, tile, blendMode, Math.TypeConversions.safe_int32_convert(opacity))
        end
    end
    
    mutable struct RoughEdgeEffect <: Effect
        amount::Int
        seed::Int
        erosion::Bool
        function RoughEdgeEffect(; amount::Int=3, seed::Int=12345, erosion::Bool=true)
            new(Math.TypeConversions.safe_int32_convert(amount), Math.TypeConversions.safe_int32_convert(seed), erosion)
        end
    end
    
    mutable struct InvertEffect <: Effect
        invert_red::Bool
        invert_green::Bool
        invert_blue::Bool
        invert_alpha::Bool
        function InvertEffect(; invert_red::Bool=true, invert_green::Bool=true, invert_blue::Bool=true, invert_alpha::Bool=false)
            new(invert_red, invert_green, invert_blue, invert_alpha)
        end
    end
    
    # Effect style for reusable combinations
    mutable struct EffectStyle
        name::String
        effects::Vector{Effect}
        function EffectStyle(name::String, effects::Vector{Effect})
            new(name, effects)
        end
    end
    
    # Predefined effect styles
    function create_button_style()
        return EffectStyle("Button", [
            BevelEffect(depth=2, angle=135, highlight_color=(255,255,255,100), shadow_color=(0,0,0,120)),
            DropShadowEffect(distance=3, angle=135, blur_radius=4, color=(0,0,0,128))
        ])
    end
    
    function create_panel_style()
        return EffectStyle("Panel", [
            OuterGlowEffect(radius=8, color=(100,100,120,140), blur=0.7),
            DropShadowEffect(distance=5, angle=135, blur_radius=6, color=(0,0,0,100))
        ])
    end
    
    function create_text_style()
        return EffectStyle("Text", [
            StrokeEffect(width=2, color=(0,0,0,255)),
            OuterGlowEffect(radius=4, color=(100,100,120,100), blur=0.5)
        ])
    end
    
    function create_highlight_style()
        return EffectStyle("Highlight", [
            OuterGlowEffect(radius=12, color=(255,255,0,150), blur=1.0)
        ])
    end
    
    function create_distressed_style()
        return EffectStyle("Distressed", [
            RoughEdgeEffect(amount=4, seed=123, erosion=true),
            StrokeEffect(width=1, color=(100,100,100,200))
        ])
    end
    
    # Main API functions
    function apply_effects!(target::EffectTarget, effects::Vector{Effect})
        # This will be implemented in effect_renderer.jl
        error("apply_effects! not implemented yet")
    end
    
    function apply_style!(target::EffectTarget, style::EffectStyle)
        return apply_effects!(target, style.effects)
    end
end
