# Bevel/Emboss panel (uses TextEffectsHelpers.jl).

function show_bevel_emboss_effect_panel(
    eff::JulGame.EffectsModule.BevelEmbossEffect,
    target,
)
    EM = JulGame.EffectsModule
    STYLE_NAMES = ["Outer bevel", "Inner bevel", "Emboss", "Pillow"]
    _fx_combo_int!(
        "Style##bevel_style",
        () -> Int(eff.style) - 1,
        v -> eff.style = EM.EmbossLayerStyle(v + 1),
        STYLE_NAMES,
        target,
    )
    BLEND_NAMES = ["Normal", "Multiply", "Screen", "Overlay"]
    _fx_combo_int!(
        "Highlight blend##bevel_hblend",
        () -> Int(eff.highlight_blend),
        v -> eff.highlight_blend = EM.BevelEmbossBlendMode(v),
        BLEND_NAMES,
        target,
    )
    _fx_combo_int!(
        "Shadow blend##bevel_sblend",
        () -> Int(eff.shadow_blend),
        v -> eff.shadow_blend = EM.BevelEmbossBlendMode(v),
        BLEND_NAMES,
        target,
    )
    _fx_drag_int!("Size (px)##bevel_sz", () -> eff.size_px, v -> eff.size_px = v, 1, 64, target)
    _fx_input_float!("Soften##bevel_soft", () -> Float64(eff.soften), v -> eff.soften = Float32(v), 0.1f0, 0.5f0, "%.2f", target)
    _fx_drag_int!("Depth##bevel_dep", () -> eff.depth, v -> eff.depth = v, 1, 64, target)
    _fx_input_float!("Angle (deg)##bevel_ang", () -> eff.angle, v -> eff.angle = v, 1.0f0, 5.0f0, "%.1f", target)
    alt = Ref(Float32(eff.altitude))
    @c CImGui.InputFloat("Altitude##bevel_alt", alt, 1.0f0, 5.0f0, "%.1f")
    altc = clamp(alt[], 0.0f0, 90.0f0)
    if Float64(altc) != eff.altitude
        eff.altitude = Float64(altc)
        alt[] = altc
        _fx_dirty!(target)
    end
    _fx_checkbox!("Direction up##bevel_up", () -> eff.direction_up, v -> eff.direction_up = v, target)
    _fx_checkbox!("Gloss enabled##bevel_gloss", () -> eff.gloss_enabled, v -> eff.gloss_enabled = v, target)
    _fx_checkbox!("Gloss antialiased##bevel_glossaa", () -> eff.gloss_antialiased, v -> eff.gloss_antialiased = v, target)
    CImGui.Separator()
    _fx_color4!("Highlight color", () -> eff.highlight_color, v -> eff.highlight_color = v, "##bevel_hcol", target)
    _fx_color4!("Shadow color", () -> eff.shadow_color, v -> eff.shadow_color = v, "##bevel_scol", target)
    _fx_drag_int!("Highlight opacity##bevel_hopa", () -> eff.highlight_opacity, v -> eff.highlight_opacity = v, 0, 255, target)
    _fx_drag_int!("Shadow opacity##bevel_sopa", () -> eff.shadow_opacity, v -> eff.shadow_opacity = v, 0, 255, target)
    _fx_slider_float!("Intensity##bevel_inten", () -> eff.intensity, v -> eff.intensity = v, 0.0f0, 1.0f0, "%.2f", target)
    if CImGui.CollapsingHeader("Advanced##bevel_adv")
        _fx_checkbox!("Contour enabled##bevel_ce", () -> eff.contour_enabled, v -> eff.contour_enabled = v, target)
        _fx_checkbox!("Contour antialiased##bevel_caa", () -> eff.contour_antialiased, v -> eff.contour_antialiased = v, target)
        _fx_drag_int!("Contour range %##bevel_rp", () -> eff.range_pct, v -> eff.range_pct = v, 1, 100, target)
        _fx_checkbox!("Texture enabled##bevel_tex", () -> eff.texture_enabled, v -> eff.texture_enabled = v, target)
        _fx_checkbox!("Texture tile##bevel_txtile", () -> eff.texture_tile, v -> eff.texture_tile = v, target)
        _fx_checkbox!("Texture invert##bevel_tinv", () -> eff.texture_invert, v -> eff.texture_invert = v, target)
        if CImGui.Button("Reset gloss & contour LUTs (linear)##bevel_resetlut")
            eff.gloss_lut = EM.identity_emboss_lut()
            eff.contour_lut = EM.identity_emboss_lut()
            _fx_dirty!(target)
        end
        CImGui.TextWrapped(
            "Live TextBox only; not saved to scripts or scene JSON.",
        )
    end
end
