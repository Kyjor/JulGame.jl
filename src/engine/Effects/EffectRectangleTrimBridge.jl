# Typed access for Rectangle effect targets. Loaded from `JulGame` after `UI` (Effects/EffectRenderer
# are included before `UI`, so `Rectangle` cannot be named in `effect_renderer.jl` during load).

@inline function _trim_effect_rect_target_color(target::EffectsModule.RectangleTarget)::NTuple{4, Int}
    r = getfield(target, :rectangle)::UI.RectangleModule.Rectangle
    return getfield(r, :color)::NTuple{4, Int}
end

function _trim_effect_rect_target_to_surface(target::EffectsModule.RectangleTarget)::Ptr{SDL2.SDL_Surface}
    r = getfield(target, :rectangle)::UI.RectangleModule.Rectangle
    return EffectRendererModule._render_rectangle_to_surface_core(r)
end

function _trim_effect_rect_target_from_surface!(
    target::EffectsModule.RectangleTarget,
    surface::Ptr{SDL2.SDL_Surface},
)::EffectsModule.RectangleTarget
    r = getfield(target, :rectangle)::UI.RectangleModule.Rectangle
    et = getfield(r, :effectTexture)::Union{Ptr{SDL2.SDL_Texture}, Ptr{Nothing}}
    if et !== C_NULL
        SDL2.SDL_DestroyTexture(et)
    end
    nt = SDL2.SDL_CreateTextureFromSurface(Renderer, surface)
    setfield!(r, :effectTexture, nt)
    if nt == C_NULL
        @error("from_surface: Failed to create texture from surface: $(unsafe_string(SDL2.SDL_GetError()))")
    else
        SDL2.SDL_SetTextureBlendMode(nt, SDL2.SDL_BLENDMODE_BLEND)
        w = Ref{Cint}(0)
        h = Ref{Cint}(0)
        SDL2.SDL_QueryTexture(nt, C_NULL, C_NULL, w, h)
        @debug "from_surface: Created effect texture $(w[])x$(h[]) for rectangle"
    end
    return target
end

function _trim_effect_image_target_to_surface(target::EffectsModule.ImageTarget)::Ptr{SDL2.SDL_Surface}
    img = getfield(target, :image)::UI.UIImageModule.UIImage
    surf = getfield(img, :surface)::Union{Ptr{Nothing}, Ptr{SDL2.LibSDL2.SDL_Surface}}
    if surf != C_NULL
        return surf::Ptr{SDL2.LibSDL2.SDL_Surface}
    end
    tex = getfield(img, :texture)::Union{Ptr{Nothing}, Ptr{SDL2.LibSDL2.SDL_Texture}}
    if tex != C_NULL
        return EffectRendererModule.texture_to_surface(tex::Ptr{SDL2.SDL_Texture})
    end
    @error("UIImage has no surface or texture for effects processing")
    return C_NULL
end

function _trim_effect_image_target_from_surface!(
    target::EffectsModule.ImageTarget,
    surface::Ptr{SDL2.SDL_Surface},
)::EffectsModule.ImageTarget
    img = getfield(target, :image)::UI.UIImageModule.UIImage
    nt = SDL2.SDL_CreateTextureFromSurface(JulGame.Renderer, surface)
    setfield!(img, :effectTexture, nt)
    return target
end
