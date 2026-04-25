# Shared ImGui helpers for effects inspector (single selection, debounced preview).

function _fx_dirty!(target)
    # Debounce helper currently only tracks TextBox IDs.
    if target isa JulGame.UI.TextBoxModule.TextBox
        mark_text_effect_preview_dirty!(target.id)
    end
    # Generic refresh path for any target that supports effects.
    JulGame.apply_effects!(target, target.effects)
end

function _fx_drag_int!(label::String, getv::Function, setv!::Function, lo::Int, hi::Int, target)
    cur = getv()
    r = Ref(Int32(clamp(cur, lo, hi)))
    @c CImGui.DragInt(label, r, 1.0f0, lo, hi, "%d", CImGui.ImGuiSliderFlags_None)
    v = Int(r[])
    if v != cur
        setv!(v)
        _fx_dirty!(target)
    end
end

function _fx_input_float!(label::String, getv::Function, setv!::Function, step::Float32, step2::Float32, fmt::String, target)
    cur = Float32(getv())
    r = Ref(cur)
    @c CImGui.InputFloat(label, r, step, step2, fmt)
    v = Float64(r[])
    if v != Float64(cur)
        setv!(v)
        _fx_dirty!(target)
    end
end

function _fx_slider_float!(label::String, getv::Function, setv!::Function, lo::Float32, hi::Float32, fmt::String, target)
    r = Ref(Float32(getv()))
    prev = r[]
    @c CImGui.SliderFloat(label, r, lo, hi, fmt)
    if r[] != prev
        setv!(Float64(r[]))
        _fx_dirty!(target)
    end
end

function _fx_combo_int!(label::String, get_idx0::Function, set_idx0!::Function, items::Vector{String}, target)
    si = Int32(clamp(get_idx0(), 0, length(items) - 1))
    CImGui.SetNextItemWidth(min(220.0f0, CImGui.GetContentRegionAvail().x))
    if @c CImGui.Combo(label, &si, items, length(items))
        set_idx0!(Int(si))
        _fx_dirty!(target)
    end
end

function _fx_checkbox!(label::String, getv::Function, setv!::Function, target)
    orig = getv()
    v = orig
    @c CImGui.Checkbox(label, &v)
    if v != orig
        setv!(v)
        _fx_dirty!(target)
    end
end

function _fx_color4!(label_text::String, getv::Function, setv!::Function, imgui_label::String, target)
    if label_text != ""
        CImGui.Text(label_text)
    end
    c = edit_color(imgui_label, getv())
    if c != getv()
        setv!(c)
        _fx_dirty!(target)
    end
end
