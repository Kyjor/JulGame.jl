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
