# Debounced TextBox effect preview: recomputes the effect texture once after edits settle (editor UX).

const TEXT_EFFECT_PREVIEW_DEBOUNCE_MS = UInt32(1000)

mutable struct _TextEffectPending
    fire_at_ms::UInt32
    tb_id::String
end

const _text_effect_pending = Ref{Union{Nothing,_TextEffectPending}}(nothing)

function mark_text_effect_preview_dirty!(textbox_id::String)
    now_ms = UInt32(SDL2.SDL_GetTicks())
    _text_effect_pending[] = _TextEffectPending(now_ms + TEXT_EFFECT_PREVIEW_DEBOUNCE_MS, textbox_id)
end

function _find_textbox_by_id(main::JulGame.MainLoopModule.MainLoop, id::String)
    for el in main.scene.uiElements
        if el isa JulGame.UI.TextBoxModule.TextBox && el.id == id
            return el
        end
    end
    return nothing
end

function tick_text_effect_preview_debounce!(main::Union{JulGame.MainLoopModule.MainLoop, Nothing})
    p = _text_effect_pending[]
    p === nothing && return
    now_ms = UInt32(SDL2.SDL_GetTicks())
    if now_ms < p.fire_at_ms
        return
    end
    _text_effect_pending[] = nothing
    main === nothing && return
    tb = _find_textbox_by_id(main, p.tb_id)
    tb === nothing && return
    JulGame.UI.request_effects_refresh!(tb)
end
