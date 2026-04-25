# Shared ImGui helpers for Text effects inspector (single selection, debounced preview).

function _fx_dirty!(tb::JulGame.UI.TextBoxModule.TextBox)
    # Keep debounce for heavy drag paths, but also refresh immediately so edits feel live.
    mark_text_effect_preview_dirty!(tb.id)
    JulGame.UI.request_effects_refresh!(tb)
end

function _fx_drag_int!(label::String, getv::Function, setv!::Function, lo::Int, hi::Int, tb::JulGame.UI.TextBoxModule.TextBox)
    cur = getv()
    r = Ref(Int32(clamp(cur, lo, hi)))
    @c CImGui.DragInt(label, r, 1.0f0, lo, hi, "%d", CImGui.ImGuiSliderFlags_None)
    v = Int(r[])
    if v != cur
        setv!(v)
        _fx_dirty!(tb)
    end
end

function _fx_input_float!(label::String, getv::Function, setv!::Function, step::Float32, step2::Float32, fmt::String, tb::JulGame.UI.TextBoxModule.TextBox)
    cur = Float32(getv())
    r = Ref(cur)
    @c CImGui.InputFloat(label, r, step, step2, fmt)
    v = Float64(r[])
    if v != Float64(cur)
        setv!(v)
        _fx_dirty!(tb)
    end
end

function _fx_slider_float!(label::String, getv::Function, setv!::Function, lo::Float32, hi::Float32, fmt::String, tb::JulGame.UI.TextBoxModule.TextBox)
    r = Ref(Float32(getv()))
    prev = r[]
    @c CImGui.SliderFloat(label, r, lo, hi, fmt)
    if r[] != prev
        setv!(Float64(r[]))
        _fx_dirty!(tb)
    end
end

function _fx_combo_int!(label::String, get_idx0::Function, set_idx0!::Function, items::Vector{String}, tb::JulGame.UI.TextBoxModule.TextBox)
    si = Int32(clamp(get_idx0(), 0, length(items) - 1))
    CImGui.SetNextItemWidth(min(220.0f0, CImGui.GetContentRegionAvail().x))
    if @c CImGui.Combo(label, &si, items, length(items))
        set_idx0!(Int(si))
        _fx_dirty!(tb)
    end
end

function _fx_checkbox!(label::String, getv::Function, setv!::Function, tb::JulGame.UI.TextBoxModule.TextBox)
    orig = getv()
    v = orig
    @c CImGui.Checkbox(label, &v)
    if v != orig
        setv!(v)
        _fx_dirty!(tb)
    end
end

function _fx_color4!(label_text::String, getv::Function, setv!::Function, imgui_label::String, tb::JulGame.UI.TextBoxModule.TextBox)
    if label_text != ""
        CImGui.Text(label_text)
    end
    c = edit_color(imgui_label, getv())
    if c != getv()
        setv!(c)
        _fx_dirty!(tb)
    end
end
