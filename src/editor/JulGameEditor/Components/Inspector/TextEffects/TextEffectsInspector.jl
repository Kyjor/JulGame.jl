# Inspector section: TextBox text effects (Bevel/Emboss v1).

function show_text_effects_inspector(tb::JulGame.UI.TextBoxModule.TextBox)
    if CImGui.CollapsingHeader("Text effects##text_fx_header", CImGui.ImGuiTreeNodeFlags_DefaultOpen)
        CImGui.Indent(4.0f0)
        CImGui.PushStyleVar(CImGui.ImGuiStyleVar_ItemSpacing, CImGui.ImVec2(6, 6))

        ix = findfirst(e -> e isa JulGame.EffectsModule.BevelEmbossEffect, tb.effects)
        if ix === nothing
            CImGui.TextWrapped("No Bevel & Emboss effect on this TextBox. Add one to tune it here (live preview only; does not edit scripts).")
            if CImGui.Button("Add Bevel & Emboss##bevel_add")
                push!(tb.effects, JulGame.EffectsModule.BevelEmbossEffect())
                JulGame.UI.request_effects_refresh!(tb)
            end
        else
            eff = tb.effects[ix]::JulGame.EffectsModule.BevelEmbossEffect
            show_bevel_emboss_effect_panel(eff, tb)
        end

        CImGui.PopStyleVar()
        CImGui.Unindent(4.0f0)
    end
end
