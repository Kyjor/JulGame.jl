module EffectsModule
    using SimpleDirectMediaLayer
    const SDL2 = SimpleDirectMediaLayer
    import ...JulGame
    const Math = JulGame.Math
    const Component = JulGame.Component
    
    export Effect, EffectTarget, EffectStyle
    export BevelEffect, BevelEffect1, BevelEmbossEffect, DropShadowEffect, OuterGlowEffect
    export InnerGlowEffect, StrokeEffect, GradientEffect
    export TextureFillEffect, RoughEdgeEffect, InvertEffect, FrayTintEffect, NibbleOverlayEffect
    export SurfaceTarget, TextureTarget, SpriteTarget, RectangleTarget, LineTarget, ImageTarget
    export apply_effects!, apply_style!, create_button_style, create_panel_style, create_text_style, create_nibble_style
    export INHERIT_COLOR, BevelType, GradientStop
    export EmbossLayerStyle, BevelEmbossBlendMode, identity_emboss_lut
    export LAYER_OUTER_BEVEL, LAYER_INNER_BEVEL, LAYER_EMBOSS, LAYER_PILLOW
    export BB_NORMAL, BB_MULTIPLY, BB_SCREEN, BB_OVERLAY
    
    # Special color value to inherit from original
    const INHERIT_COLOR = (-1, -1, -1, -1)
    
    # PSD / Krita layer-style geometry (outer / inner / emboss / pillow)
    @enum EmbossLayerStyle begin
        LAYER_OUTER_BEVEL = 1
        LAYER_INNER_BEVEL = 2
        LAYER_EMBOSS = 3
        LAYER_PILLOW = 4
    end
    
    @enum BevelEmbossBlendMode begin
        BB_NORMAL = 0
        BB_MULTIPLY = 1
        BB_SCREEN = 2
        BB_OVERLAY = 3
    end
    
    function identity_emboss_lut()::Vector{UInt8}
        return UInt8[i for i in 0:255]
    end
    
    # BevelType enum for selecting bevel rendering modes
    @enum BevelType begin
        INNER_BEVEL = 1    # Creates inset/carved appearance
        OUTER_BEVEL = 2   # Creates raised/embossed appearance  
        COMBINED_BEVEL = 3 # Both inner and outer bevels
        EMBOSS_BEVEL = 4   # Krita-style full emboss (maps to LAYER_EMBOSS)
        PILLOW_EMBOSS = 5  # Pillow emboss (maps to LAYER_PILLOW)
    end
    
    # GradientStop struct for multi-stop gradient definitions
    struct GradientStop
        position::Float32  # Position along gradient (0.0 to 1.0)
        color::NTuple{4, UInt8}  # RGBA color
    end
    
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
    
    # New comprehensive bevel effect with advanced features
    mutable struct BevelEffect1 <: Effect
        bevel_type::BevelType
        bevel_depth::Float32      # Depth in pixels (2-5 for subtle effects)
        bevel_width::Float32      # Width of bevel effect region
        light_position::Math.Vector2  # Light position (X, Y coordinates)
        blur_radius::Float32      # Blur radius in pixels (1-3 for soft edges)
        intensity::Float32        # Overall effect strength (0.0-1.0)
        
        # Gradient definitions
        inner_gradient::Vector{GradientStop}  # Inner bevel gradient
        outer_gradient::Vector{GradientStop}  # Outer bevel gradient  
        shadow_gradient::Vector{GradientStop} # Shadow gradient
        
        function BevelEffect1(;
            bevel_type::BevelType = OUTER_BEVEL,
            bevel_depth::Float32 = 3.0f0,
            bevel_width::Float32 = 2.0f0,
            light_position::Math.Vector2 = Math.Vector2(1.0, -1.0),
            blur_radius::Float32 = 2.0f0,
            intensity::Float32 = 0.8f0,
            inner_gradient::Vector{GradientStop} = [GradientStop(0.0f0, (255, 255, 255, 255)), GradientStop(1.0f0, (200, 200, 200, 255))],
            outer_gradient::Vector{GradientStop} = [GradientStop(0.0f0, (255, 255, 255, 255)), GradientStop(1.0f0, (180, 180, 180, 255))],
            shadow_gradient::Vector{GradientStop} = [GradientStop(0.0f0, (100, 100, 100, 255)), GradientStop(1.0f0, (50, 50, 50, 255))]
        )
            new(
                bevel_type, bevel_depth, bevel_width, light_position, blur_radius, intensity,
                inner_gradient, outer_gradient, shadow_gradient
            )
        end
    end
    
    """
    Krita/PSD-style bevel and emboss (height ramp + GIMP bumpmap + optional contour/gloss/texture).
    """
    mutable struct BevelEmbossEffect <: Effect
        style::EmbossLayerStyle
        size_px::Int
        soften::Float32
        depth::Int
        angle::Float64
        altitude::Float64
        direction_up::Bool
        contour_enabled::Bool
        range_pct::Int
        contour_lut::Vector{UInt8}
        contour_antialiased::Bool
        gloss_enabled::Bool
        gloss_lut::Vector{UInt8}
        gloss_antialiased::Bool
        texture_enabled::Bool
        texture_path::String
        texture_tile::Bool
        texture_scale::Int
        texture_phase_h_pct::Int
        texture_phase_v_pct::Int
        texture_align_with_layer::Bool
        texture_depth::Float64
        texture_invert::Bool
        highlight_color::NTuple{4, Int}
        shadow_color::NTuple{4, Int}
        highlight_opacity::Int
        shadow_opacity::Int
        highlight_blend::BevelEmbossBlendMode
        shadow_blend::BevelEmbossBlendMode
        intensity::Float64
        function BevelEmbossEffect(;
            style::EmbossLayerStyle = LAYER_OUTER_BEVEL,
            size_px::Int = 4,
            soften::Float32 = 0.0f0,
            depth::Int = 4,
            angle::Float64 = 135.0,
            altitude::Float64 = 30.0,
            direction_up::Bool = true,
            contour_enabled::Bool = false,
            range_pct::Int = 100,
            contour_lut::Vector{UInt8} = identity_emboss_lut(),
            contour_antialiased::Bool = true,
            gloss_enabled::Bool = false,
            gloss_lut::Vector{UInt8} = identity_emboss_lut(),
            gloss_antialiased::Bool = true,
            texture_enabled::Bool = false,
            texture_path::String = "",
            texture_tile::Bool = true,
            texture_scale::Int = 100,
            texture_phase_h_pct::Int = 0,
            texture_phase_v_pct::Int = 0,
            texture_align_with_layer::Bool = true,
            texture_depth::Float64 = 50.0,
            texture_invert::Bool = false,
            highlight_color::NTuple{4, Int} = (255, 255, 255, 200),
            shadow_color::NTuple{4, Int} = (0, 0, 0, 180),
            highlight_opacity::Int = 255,
            shadow_opacity::Int = 255,
            highlight_blend::BevelEmbossBlendMode = BB_NORMAL,
            shadow_blend::BevelEmbossBlendMode = BB_MULTIPLY,
            intensity::Float64 = 1.0,
        )
            rc = clamp(range_pct, 1, 100)
            new(
                style,
                max(1, Math.TypeConversions.safe_int32_convert(size_px)),
                soften,
                max(1, Math.TypeConversions.safe_int32_convert(depth)),
                angle,
                clamp(altitude, 0.0, 90.0),
                direction_up,
                contour_enabled,
                rc,
                length(contour_lut) == 256 ? contour_lut : identity_emboss_lut(),
                contour_antialiased,
                gloss_enabled,
                length(gloss_lut) == 256 ? gloss_lut : identity_emboss_lut(),
                gloss_antialiased,
                texture_enabled,
                texture_path,
                texture_tile,
                clamp(Math.TypeConversions.safe_int32_convert(texture_scale), 1, 500),
                clamp(Math.TypeConversions.safe_int32_convert(texture_phase_h_pct), 0, 100),
                clamp(Math.TypeConversions.safe_int32_convert(texture_phase_v_pct), 0, 100),
                texture_align_with_layer,
                texture_depth,
                texture_invert,
                highlight_color,
                shadow_color,
                clamp(Math.TypeConversions.safe_int32_convert(highlight_opacity), 0, 255),
                clamp(Math.TypeConversions.safe_int32_convert(shadow_opacity), 0, 255),
                highlight_blend,
                shadow_blend,
                clamp(intensity, 0.0, 1.0),
            )
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
        force_white::Bool
        fade_amount::Float64
        fade_curve::Float64
        function OuterGlowEffect(; radius::Int=6, color::NTuple{4, Int}=(255,255,255,140), blur::Float64=0.7, force_white::Bool=true, fade_amount::Float64=1.0, fade_curve::Float64=1.0)
            new(Math.TypeConversions.safe_int32_convert(radius), color, blur, force_white, fade_amount, fade_curve)
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

    """
    Desaturate + dirt tint + light noise for a worn / frayed look.
    """
    mutable struct FrayTintEffect <: Effect
        desaturate::Float64
        brightness::Float64
        tint::NTuple{4, Int}
        tint_strength::Float64
        noise::Float64
        seed::Int
        function FrayTintEffect(;
            desaturate::Float64 = 0.45,
            brightness::Float64 = 0.88,
            tint::NTuple{4, Int} = (110, 95, 75, 255),
            tint_strength::Float64 = 0.18,
            noise::Float64 = 0.07,
            seed::Int = 12345,
        )
            new(
                clamp(desaturate, 0.0, 1.0),
                clamp(brightness, 0.0, 2.0),
                tint,
                clamp(tint_strength, 0.0, 1.0),
                clamp(noise, 0.0, 1.0),
                Math.TypeConversions.safe_int32_convert(seed),
            )
        end
    end

    """
    Stamp nibble/bite masks onto a sprite so it looks chewed (max 5 bites).
    Stamp masks use alpha only. Interior bites paint black; edge bites punch
    transparent with a 2–4px black rim. Bites are spaced by `min_separation`.
    """
    mutable struct NibbleOverlayEffect <: Effect
        seed::Int
        count::Int
        texture_paths::Vector{String}
        punch_alpha::Bool
        overlay::Bool
        opacity::Int
        threshold::Int
        min_scale::Float64
        max_scale::Float64
        min_separation::Float64  # fraction of min(sprite dim) between bite centers
        rim_min::Int
        rim_max::Int
        function NibbleOverlayEffect(;
            seed::Int = 12345,
            count::Int = 3,
            texture_paths::Vector{String} = String[
                "effect-nibble1-0000.png",
                "effect-nibble2-0000.png",
            ],
            punch_alpha::Bool = false,
            overlay::Bool = false,
            opacity::Int = 255,
            threshold::Int = 40,
            min_scale::Float64 = 0.28,
            max_scale::Float64 = 0.55,
            min_separation::Float64 = 0.38,
            rim_min::Int = 2,
            rim_max::Int = 4,
        )
            new(
                Math.TypeConversions.safe_int32_convert(seed),
                Math.TypeConversions.safe_int32_convert(clamp(count, 1, 5)),
                texture_paths,
                punch_alpha,
                overlay,
                Math.TypeConversions.safe_int32_convert(clamp(opacity, 0, 255)),
                Math.TypeConversions.safe_int32_convert(clamp(threshold, 0, 255)),
                min_scale,
                max_scale,
                max(0.0, min_separation),
                Math.TypeConversions.safe_int32_convert(clamp(rim_min, 1, 16)),
                Math.TypeConversions.safe_int32_convert(clamp(max(rim_min, rim_max), 1, 16)),
            )
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
    
    function create_nibble_style(; seed::Int = 12345, count::Int = 3)
        return EffectStyle("Nibble", [
            NibbleOverlayEffect(; seed = seed, count = count),
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
