using CImGui
using CImGui.CSyntax
using CImGui.CSyntax.CStatic

"""
ShowFileLocationInput()
"""
function ShowFileLocationInput()
    CImGui.MenuItem("Entity Menu", C_NULL, false, false)
    if CImGui.BeginMenu("New Component")
        if CImGui.MenuItem("Animator")
            currentEntitySelected.addAnimator()
        end
        if CImGui.MenuItem("Collider")
            currentEntitySelected.addCollider()
        end
        if CImGui.MenuItem("Rigidbody")
            currentEntitySelected.addRigidbody()
        end
        if CImGui.MenuItem("SoundSource")
            @info "Replace me"
        end
        if CImGui.MenuItem("Sprite")
            @info "Replace me"
        end
        
        CImGui.EndMenu()
    end
end