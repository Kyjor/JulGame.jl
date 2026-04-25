# ImGui panel for in-place editing of `EffectsModule.BevelEmbossEffect` on a TextBox (debounced preview).

function show_bevel_emboss_effect_panel(
    eff::JulGame.EffectsModule.BevelEmbossEffect,
    tb::JulGame.UI.TextBoxModule.TextBox,
)
    EM = JulGame.EffectsModule

    STYLE_NAMES = ["Outer bevel", "Inner bevel", "Emboss", "Pillow"]
    si = Int32(clamp(Int(eff.style) - 1, 0, length(STYLE_NAMES) - 1))
    CImGui.SetNextItemWidth(min(220.0f0, CImGui.GetContentRegionAvail().x))
    if @c CImGui.Combo("Style##bevel_style", &si, STYLE_NAMES, length(STYLE_NAMES))
        eff.style = EM.EmbossLayerStyle(Int(si) + 1)
        mark_text_effect_preview_dirty!(tb.id)
    end

    BLEND_NAMES = ["Normal", "Multiply", "Screen", "Overlay"]
    hbi = Int32(Int(eff.highlight_blend))
    CImGui.SetNextItemWidth(min(220.0f0, CImGui.GetContentRegionAvail().x))
    if @c CImGui.Combo("Highlight blend##bevel_hblend", &hbi, BLEND_NAMES, length(BLEND_NAMES))
        eff.highlight_blend = EM.BevelEmbossBlendMode(Int(hbi))
        mark_text_effect_preview_dirty!(tb.id)
    end
    sbi = Int32(Int(eff.shadow_blend))
    CImGui.SetNextItemWidth(min(220.0f0, CImGui.GetContentRegionAvail().x))
    if @c CImGui.Combo("Shadow blend##bevel_sblend", &sbi, BLEND_NAMES, length(BLEND_NAMES))
        eff.shadow_blend = EM.BevelEmbossBlendMode(Int(sbi))
        mark_text_effect_preview_dirty!(tb.id)
    end

    sz_r = Ref(Int32(clamp(eff.size_px, 1, 64)))
    @c CImGui.DragInt("Size (px)##bevel_sz", sz_r, 1.0f0, 1, 64, "%d", CImGui.ImGuiSliderFlags_None)
    if Int(sz_r[]) != eff.size_px
        eff.size_px = Int(sz_r[])
        mark_text_effect_preview_dirty!(tb.id)
    end

    sf = Ref(Float32(eff.soften))
    @c CImGui.InputFloat("Soften##bevel_soft", sf, 0.1f0, 0.5f0, "%.2f")
    if Float64(sf[]) != Float64(eff.soften)
        eff.soften = sf[]
        mark_text_effect_preview_dirty!(tb.id)
    end

    dep_r = Ref(Int32(clamp(eff.depth, 1, 256)))
    @c CImGui.DragInt("Depth##bevel_dep", dep_r, 1.0f0, 1, 64, "%d", CImGui.ImGuiSliderFlags_None)
    if Int(dep_r[]) != eff.depth
        eff.depth = Int(dep_r[])
        mark_text_effect_preview_dirty!(tb.id)
    end

    ang = Ref(Float32(eff.angle))
    @c CImGui.InputFloat("Angle (deg)##bevel_ang", ang, 1.0f0, 5.0f0, "%.1f")
    if Float64(ang[]) != eff.angle
        eff.angle = Float64(ang[])
        mark_text_effect_preview_dirty!(tb.id)
    end

    alt = Ref(Float32(eff.altitude))
    @c CImGui.InputFloat("Altitude##bevel_alt", alt, 1.0f0, 5.0f0, "%.1f")
    alt_clamped = clamp(alt[], 0.0f0, 90.0f0)
    if Float64(alt_clamped) != eff.altitude
        eff.altitude = Float64(alt_clamped)
        alt[] = alt_clamped
        mark_text_effect_preview_dirty!(tb.id)
    end

    up = eff.direction_up
    @c CImGui.Checkbox("Direction up##bevel_up", &up)
    if up != eff.direction_up
        eff.direction_up = up
        mark_text_effect_preview_dirty!(tb.id)
    end

    ge = eff.gloss_enabled
    @c CImGui.Checkbox("Gloss enabled##bevel_gloss", &ge)
    if ge != eff.gloss_enabled
        eff.gloss_enabled = ge
        mark_text_effect_preview_dirty!(tb.id)
    end
    ga = eff.gloss_antialiased
    @c CImGui.Checkbox("Gloss antialiased##bevel_glossaa", &ga)
    if ga != eff.gloss_antialiased
        eff.gloss_antialiased = ga
        mark_text_effect_preview_dirty!(tb.id)
    end

    CImGui.Separator()
    CImGui.Text("Highlight color")
    hc = edit_color("##bevel_hcol", eff.highlight_color)
    if hc != eff.highlight_color
        eff.highlight_color = hc
        mark_text_effect_preview_dirty!(tb.id)
    end
    CImGui.Text("Shadow color")
    sc = edit_color("##bevel_scol", eff.shadow_color)
    if sc != eff.shadow_color
        eff.shadow_color = sc
        mark_text_effect_preview_dirty!(tb.id)
    end

    ho_r = Ref(Int32(clamp(eff.highlight_opacity, 0, 255)))
    @c CImGui.DragInt("Highlight opacity##bevel_hopa", ho_r, 1.0f0, 0, 255, "%d", CImGui.ImGuiSliderFlags_None)
    if Int(ho_r[]) != eff.highlight_opacity
        eff.highlight_opacity = Int(ho_r[])
        mark_text_effect_preview_dirty!(tb.id)
    end
    so_r = Ref(Int32(clamp(eff.shadow_opacity, 0, 255)))
    @c CImGui.DragInt("Shadow opacity##bevel_sopa", so_r, 1.0f0, 0, 255, "%d", CImGui.ImGuiSliderFlags_None)
    if Int(so_r[]) != eff.shadow_opacity
        eff.shadow_opacity = Int(so_r[])
        mark_text_effect_preview_dirty!(tb.id)
    end

    inten = Ref(Float32(eff.intensity))
    inten_prev = inten[]
    @c CImGui.SliderFloat("Intensity##bevel_inten", inten, 0.0f0, 1.0f0, "%.2f")
    if inten[] != inten_prev
        eff.intensity = Float64(inten[])
        mark_text_effect_preview_dirty!(tb.id)
    end

    if CImGui.CollapsingHeader("Advanced##bevel_adv")
        ce = eff.contour_enabled
        @c CImGui.Checkbox("Contour enabled##bevel_ce", &ce)
        if ce != eff.contour_enabled
            eff.contour_enabled = ce
            mark_text_effect_preview_dirty!(tb.id)
        end
        caa = eff.contour_antialiased
        @c CImGui.Checkbox("Contour antialiased##bevel_caa", &caa)
        if caa != eff.contour_antialiased
            eff.contour_antialiased = caa
            mark_text_effect_preview_dirty!(tb.id)
        end
        rp_r = Ref(Int32(clamp(eff.range_pct, 1, 100)))
        @c CImGui.DragInt("Contour range %##bevel_rp", rp_r, 1.0f0, 1, 100, "%d", CImGui.ImGuiSliderFlags_None)
        if Int(rp_r[]) != eff.range_pct
            eff.range_pct = Int(rp_r[])
            mark_text_effect_preview_dirty!(tb.id)
        end

        te = eff.texture_enabled
        @c CImGui.Checkbox("Texture enabled##bevel_tex", &te)
        if te != eff.texture_enabled
            eff.texture_enabled = te
            mark_text_effect_preview_dirty!(tb.id)
        end
        tt = eff.texture_tile
        @c CImGui.Checkbox("Texture tile##bevel_txtile", &tt)
        if tt != eff.texture_tile
            eff.texture_tile = tt
            mark_text_effect_preview_dirty!(tb.id)
        end
        ti = eff.texture_invert
        @c CImGui.Checkbox("Texture invert##bevel_tinv", &ti)
        if ti != eff.texture_invert
            eff.texture_invert = ti
            mark_text_effect_preview_dirty!(tb.id)
        end

        if CImGui.Button("Reset gloss & contour LUTs (linear)##bevel_resetlut")
            eff.gloss_lut = EM.identity_emboss_lut()
            eff.contour_lut = EM.identity_emboss_lut()
            mark_text_effect_preview_dirty!(tb.id)
        end
        CImGui.TextWrapped(
            "Edits here update the live TextBox only; they are not written to scripts or scene JSON.",
        )
    end
end
