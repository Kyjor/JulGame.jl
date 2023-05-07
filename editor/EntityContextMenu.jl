using CImGui
using CImGui.CSyntax
using CImGui.CSyntax.CStatic

"""
ShowEntityContextMenu()
Create a fullscreen menu bar and populate it.
"""
function ShowEntityContextMenu()
    CImGui.MenuItem("Entity Menu", C_NULL, false, false)
    if CImGui.BeginMenu("New Component")
        CImGui.MenuItem("Animator")
        CImGui.MenuItem("Collider")
        CImGui.MenuItem("Rigidbody")
        CImGui.MenuItem("SoundSource")
        CImGui.MenuItem("Sprite")
        CImGui.MenuItem("Transform")
        CImGui.EndMenu()
    end
end