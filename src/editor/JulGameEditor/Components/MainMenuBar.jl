using CImGui
using CImGui.CSyntax
using CImGui.CSyntax.CStatic

"""
    ShowAppMainMenuBar(events)
Create a fullscreen menu bar and populate it.

# Arguments
- `events`: An array of event functions. These are callbacks that are triggered when the user selects a menu item.
"""
function show_main_menu_bar(events, main)
    if CImGui.BeginMainMenuBar()
        @cstatic buf="File"*"\0"^128 begin
            if CImGui.BeginMenu(buf)
                ShowMenuFile(events)
                CImGui.EndMenu()
            end
        end

        @cstatic buf="Scene"*"\0"^128 begin
            if main !== nothing && CImGui.BeginMenu(buf)
                show_scene_menu(events)
                CImGui.EndMenu()
            end

        end
        CImGui.EndMainMenuBar()
    end
end

"""
    ShowMenuFile(events)

Show the file menu in the main menu bar.

# Arguments
- `events`: An array of event functions. These are callbacks that are triggered when the user selects a menu item.
"""
function ShowMenuFile(events)
    if CImGui.MenuItem("Open Project", "Ctrl+O")
        events["Select-project"]()
    end
end

function show_scene_menu(events)
    if CImGui.MenuItem("Save", "Ctrl+S")
        events["Save"]()
    end
    if CImGui.MenuItem("Reset Camera", "Ctrl+R")
        events["Reset-camera"]()
    end

    if CImGui.BeginMenu("Extras")
        if CImGui.MenuItem("Regenerate Ids")
            events["Regenerate-ids"]()
        end
        CImGui.EndMenu()
    end 
end