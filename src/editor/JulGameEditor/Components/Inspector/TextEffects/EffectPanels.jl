# Dispatch + compact panels for `EffectsModule` types (BevelEmboss lives in BevelEmbossEffectPanel.jl).

function _fx_buf256_from_str(s::String)
    buf = zeros(UInt8, 256)
    u = codeunits(s)
    n = min(length(u), 255)
    for i in 1:n
        buf[i] = u[i]
    end
    return buf
end

function _fx_str_from_buf256(buf::Vector{UInt8})::String
    i = findfirst(iszero, buf)
    lasti = i === nothing ? length(buf) : i - 1
    lasti < 1 && return ""
    return String(buf[1:lasti])
end

function show_effect_panel_for(eff::Any, target)
    EM = JulGame.EffectsModule
    if eff isa EM.BevelEmbossEffect
        show_bevel_emboss_effect_panel(eff, target)
    elseif eff isa EM.DropShadowEffect
        _fx_input_float!("Distance##ds_d", () -> eff.distance, v -> eff.distance = v, 0.5f0, 2.0f0, "%.2f", target)
        _fx_input_float!("Angle##ds_a", () -> eff.angle, v -> eff.angle = v, 1.0f0, 5.0f0, "%.1f", target)
        _fx_drag_int!("Blur radius##ds_br", () -> eff.blur_radius, v -> eff.blur_radius = v, 0, 64, target)
        _fx_color4!("Shadow color", () -> eff.color, v -> eff.color = v, "##ds_col", target)
        _fx_drag_int!("Opacity##ds_op", () -> eff.opacity, v -> eff.opacity = v, 0, 255, target)
    elseif eff isa EM.OuterGlowEffect
        _fx_drag_int!("Radius##og_r", () -> eff.radius, v -> eff.radius = v, 0, 128, target)
        _fx_color4!("Color", () -> eff.color, v -> eff.color = v, "##og_c", target)
        _fx_input_float!("Blur##og_b", () -> eff.blur, v -> eff.blur = v, 0.05f0, 0.2f0, "%.2f", target)
        _fx_checkbox!("Force white##og_fw", () -> eff.force_white, v -> eff.force_white = v, target)
        _fx_input_float!("Fade amount##og_fa", () -> eff.fade_amount, v -> eff.fade_amount = v, 0.05f0, 0.2f0, "%.2f", target)
        _fx_input_float!("Fade curve##og_fc", () -> eff.fade_curve, v -> eff.fade_curve = v, 0.05f0, 0.2f0, "%.2f", target)
    elseif eff isa EM.InnerGlowEffect
        _fx_drag_int!("Radius##ig_r", () -> eff.radius, v -> eff.radius = v, 0, 128, target)
        _fx_color4!("Color", () -> eff.color, v -> eff.color = v, "##ig_c", target)
    elseif eff isa EM.StrokeEffect
        _fx_drag_int!("Width##st_w", () -> eff.width, v -> eff.width = v, 0, 32, target)
        _fx_color4!("Color", () -> eff.color, v -> eff.color = v, "##st_c", target)
    elseif eff isa EM.RoughEdgeEffect
        _fx_drag_int!("Amount##re_a", () -> eff.amount, v -> eff.amount = v, 1, 20, target)
        _fx_drag_int!("Seed##re_s", () -> eff.seed, v -> eff.seed = v, 0, 2_000_000_000, target)
        _fx_checkbox!("Erosion##re_e", () -> eff.erosion, v -> eff.erosion = v, target)
    elseif eff isa EM.InvertEffect
        _fx_checkbox!("Invert red##iv_r", () -> eff.invert_red, v -> eff.invert_red = v, target)
        _fx_checkbox!("Invert green##iv_g", () -> eff.invert_green, v -> eff.invert_green = v, target)
        _fx_checkbox!("Invert blue##iv_b", () -> eff.invert_blue, v -> eff.invert_blue = v, target)
        _fx_checkbox!("Invert alpha##iv_a", () -> eff.invert_alpha, v -> eff.invert_alpha = v, target)
    elseif eff isa EM.BevelEffect
        _fx_drag_int!("Depth##bv_d", () -> eff.depth, v -> eff.depth = v, 1, 32, target)
        _fx_input_float!("Angle##bv_a", () -> eff.angle, v -> eff.angle = v, 1.0f0, 5.0f0, "%.1f", target)
        _fx_slider_float!("Intensity##bv_i", () -> eff.intensity, v -> eff.intensity = v, 0.0f0, 1.0f0, "%.2f", target)
        _fx_color4!("Highlight", () -> eff.highlight_color, v -> eff.highlight_color = v, "##bv_h", target)
        _fx_color4!("Shadow", () -> eff.shadow_color, v -> eff.shadow_color = v, "##bv_s", target)
    elseif eff isa EM.TextureFillEffect
        buf = _fx_buf256_from_str(String(eff.texturePath))
        if CImGui.InputText("Texture (assets/textures/)##tf_p", buf, length(buf))
            eff.texturePath = _fx_str_from_buf256(buf)
            _fx_dirty!(target)
        end
        _fx_checkbox!("Tile##tf_t", () -> eff.tile, v -> eff.tile = v, target)
        _fx_combo_int!(
            "Blend##tf_b",
            () -> clamp(eff.blendMode, 0, 3),
            v -> eff.blendMode = v,
            ["Replace (0)", "Multiply (1)", "Multiply (2)", "Add (3)"],
            target,
        )
        _fx_drag_int!("Opacity##tf_o", () -> eff.opacity, v -> eff.opacity = v, 0, 255, target)
    elseif eff isa EM.GradientEffect
        gtypes = ["LinearGradient", "RadialGradient"]
        idx = findfirst(==(eff.gradientType), gtypes)
        gi = Int32(idx === nothing ? 0 : idx - 1)
        CImGui.SetNextItemWidth(min(220.0f0, CImGui.GetContentRegionAvail().x))
        if @c CImGui.Combo("Type##gr_t", &gi, gtypes, length(gtypes))
            eff.gradientType = gtypes[Int(gi) + 1]
            _fx_dirty!(target)
        end
        _fx_input_float!("Angle (linear)##gr_a", () -> eff.angle, v -> eff.angle = v, 1.0f0, 5.0f0, "%.1f", target)
        if isempty(eff.stops)
            CImGui.TextWrapped("No stops — add at least two for a visible gradient.")
        end
        for i in 1:min(6, length(eff.stops))
            t, rgba = eff.stops[i]
            CImGui.PushID(i)
            tr = Ref(Float32(t))
            @c CImGui.DragFloat("Pos##gr_p", tr, 0.01f0, 0.0f0, 1.0f0, "%.3f")
            nc = edit_color("##gr_c", rgba)
            nt = Float64(tr[])
            if nt != t || nc != rgba
                eff.stops[i] = (nt, nc)
                _fx_dirty!(target)
            end
            CImGui.PopID()
        end
        if length(eff.stops) < 6 && CImGui.Button("Add stop##gr_add")
            push!(eff.stops, (0.5, (128, 128, 128, 255)))
            _fx_dirty!(target)
        end
        if length(eff.stops) > 2 && CImGui.Button("Remove last##gr_rm")
            pop!(eff.stops)
            _fx_dirty!(target)
        end
    elseif eff isa EM.BevelEffect1
        bnames = ["Inner", "Outer", "Combined", "Emboss", "Pillow"]
        _fx_combo_int!(
            "Bevel type##b1_ty",
            () -> Int(eff.bevel_type) - 1,
            v -> eff.bevel_type = EM.BevelType(v + 1),
            bnames,
            target,
        )
        lx = Ref(Float32(eff.light_position.x))
        ly = Ref(Float32(eff.light_position.y))
        @c CImGui.InputFloat("Light X##b1_lx", lx, 0.05f0, 0.2f0, "%.2f")
        @c CImGui.InputFloat("Light Y##b1_ly", ly, 0.05f0, 0.2f0, "%.2f")
        np = JulGame.Math.Vector2(Float64(lx[]), Float64(ly[]))
        if np.x != eff.light_position.x || np.y != eff.light_position.y
            eff.light_position = np
            _fx_dirty!(target)
        end
        rfd = Ref(Float32(eff.bevel_depth))
        @c CImGui.InputFloat("Depth##b1_d", rfd, 0.05f0, 0.2f0, "%.2f")
        if Float64(rfd[]) != Float64(eff.bevel_depth)
            eff.bevel_depth = rfd[]
            _fx_dirty!(target)
        end
        rfw = Ref(Float32(eff.bevel_width))
        @c CImGui.InputFloat("Width##b1_w", rfw, 0.05f0, 0.2f0, "%.2f")
        if Float64(rfw[]) != Float64(eff.bevel_width)
            eff.bevel_width = rfw[]
            _fx_dirty!(target)
        end
        rbl = Ref(Float32(eff.blur_radius))
        @c CImGui.InputFloat("Blur radius##b1_bl", rbl, 0.05f0, 0.2f0, "%.2f")
        if Float64(rbl[]) != Float64(eff.blur_radius)
            eff.blur_radius = rbl[]
            _fx_dirty!(tb)
        end
        _fx_slider_float!("Intensity##b1_i", () -> Float64(eff.intensity), v -> eff.intensity = Float32(v), 0.0f0, 1.0f0, "%.2f", target)
        if CImGui.CollapsingHeader("Gradient endpoints##b1_adv")
            _fx_grad_endpoints!(eff.inner_gradient, "Inner", target)
            _fx_grad_endpoints!(eff.outer_gradient, "Outer", target)
            _fx_grad_endpoints!(eff.shadow_gradient, "Shadow", target)
        end
    else
        CImGui.TextWrapped("No inspector for $(nameof(typeof(eff))) yet.")
    end
end

function _fx_grad_endpoints!(grad::Vector{JulGame.EffectsModule.GradientStop}, title::String, target)
    length(grad) < 2 && return
    CImGui.Text("$title (first / last stop)")
    a = grad[1]
    b = grad[end]
    CImGui.PushID(title)
    ar = Ref(Float32(a.position))
    @c CImGui.DragFloat("Start pos##gp", ar, 0.01f0, 0.0f0, 1.0f0, "%.3f")
    ac = edit_color("##gpc0", Tuple(Int.(a.color)))
    br = Ref(Float32(b.position))
    @c CImGui.DragFloat("End pos##gp2", br, 0.01f0, 0.0f0, 1.0f0, "%.3f")
    bc = edit_color("##gpc1", Tuple(Int.(b.color)))
    CImGui.PopID()
    ap = Float64(ar[])
    bp = Float64(br[])
    ac8 = NTuple{4, UInt8}(Tuple(UInt8.(clamp.(ac, 0, 255))))
    bc8 = NTuple{4, UInt8}(Tuple(UInt8.(clamp.(bc, 0, 255))))
    if ap != Float64(a.position) || ac8 != a.color
        grad[1] = JulGame.EffectsModule.GradientStop(Float32(ap), ac8)
        _fx_dirty!(target)
    end
    if bp != Float64(b.position) || bc8 != b.color
        grad[end] = JulGame.EffectsModule.GradientStop(Float32(bp), bc8)
        _fx_dirty!(target)
    end
end
