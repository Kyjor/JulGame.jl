using CImGui
using CImGui.CSyntax
using CImGui.CSyntax.CStatic
using Dates

# Import the get_raw_recents function
using ..Editor: get_raw_recents

"""
    ShowAppMainMenuBar(events)
Create a fullscreen menu bar and populate it.

# Arguments
- `events`: An array of event functions. These are callbacks that are triggered when the user selects a menu item.
"""
function show_main_menu_bar(events, main, recent_paths::Vector)
    if CImGui.BeginMainMenuBar()
        @cstatic buf="File"*"\0"^128 begin
            if CImGui.BeginMenu(buf)
                show_file_menu(events, main, recent_paths)
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
    show_file_menu(events, main)

Show the file menu in the main menu bar.

# Arguments
- `events`: An array of event functions. These are callbacks that are triggered when the user selects a menu item.
"""
function show_file_menu(events, main, recent_paths::Vector)
    if CImGui.MenuItem("New Project", "")
        events["New-project"]()
    end
    if CImGui.MenuItem("Open Project", "")
        events["Select-project"]()
    end
    if main !== nothing && CImGui.MenuItem("New Scene", "")
        events["New-Scene"]()
    end

    # Recents submenu
    if !isempty(recent_paths) && CImGui.BeginMenu("Recents")
        # Get raw recents data with timestamps
        raw_recents = get_raw_recents()
        
        for (i, path) in enumerate(recent_paths)
            # Find the timestamp for this path
            timestamp_info = ""
            for recent in raw_recents
                if recent.path == path
                    # Try to format the timestamp nicely
                    try 
                        dt = Dates.DateTime(recent.timestamp)
                        timestamp_info = Dates.format(dt, "yyyy-mm-dd HH:MM:SS")
                    catch
                        timestamp_info = recent.timestamp
                    end
                    break
                end
            end
            
            # Truncate the path if it's too long
            display_path = length(path) > 60 ? "..." * path[end-57:end] : path
            
            if CImGui.MenuItem(display_path)
                events["Select-recent-project"](path)
            end
            
            # Show tooltip with full path and timestamp on hover
            if CImGui.IsItemHovered()
                CImGui.BeginTooltip()
                CImGui.Text("$(path)")
                if timestamp_info != ""
                    CImGui.Text("Last opened: $(timestamp_info)")
                end
                CImGui.EndTooltip()
            end
        end
        CImGui.EndMenu()
    end
end

function show_scene_menu(events)
    if CImGui.MenuItem("Save", "Ctrl+S")
        events["Save"]()
    end
    if CImGui.MenuItem("Play/Pause Scene", "")
        events["Play-Mode"]()
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