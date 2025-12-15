using CImGui
using CImGui.CSyntax
using CImGui.CSyntax.CStatic
using Dates

# Global editor scale factor (persisted across frames)
const EDITOR_SCALE = Ref(1.0f0)
const EDITOR_SCALE_MIN = 0.5f0
const EDITOR_SCALE_MAX = 2.5f0
const EDITOR_SCALE_STEP = 0.1f0

# Keep a copy of the base style so scaling is stable (non-cumulative).
const _BASE_STYLE_SET = Ref(false)
const _BASE_STYLE = Ref{CImGui.ImGuiStyle}()

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
        
        @cstatic buf="Tools"*"\0"^128 begin
            if CImGui.BeginMenu(buf)
                show_tools_menu(events)
                CImGui.EndMenu()
            end
        end
        
        @cstatic buf="View"*"\0"^128 begin
            if CImGui.BeginMenu(buf)
                show_view_menu()
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
    if CImGui.MenuItem("Play/Pause Scene", "Ctrl+R")
        events["Play-Mode"]()
    end
    if CImGui.MenuItem("Reset Camera", "")
        events["Reset-camera"]()
    end

    if CImGui.BeginMenu("Extras")
        if CImGui.MenuItem("Regenerate Ids")
            events["Regenerate-ids"]()
        end
        CImGui.EndMenu()
    end 
end

function show_tools_menu(events)
    if CImGui.MenuItem("Code Editor", "Ctrl+E")
        events["Open-code-editor"]()
    end
    
    if CImGui.MenuItem("Open Script", "Ctrl+O")
        events["Open-script"]()
    end
end

function show_view_menu()
    # Get the ImGui style pointer
    style = CImGui.GetStyle()
    io = CImGui.GetIO()
    
    if CImGui.BeginMenu("Editor Scale")
        # Show current scale
        CImGui.Text("Current: $(round(Int, EDITOR_SCALE[] * 100))%")
        CImGui.Separator()
        
        # Preset scale options
        scale_presets = [
            (0.75f0, "75%"),
            (1.0f0, "100% (Default)"),
            (1.25f0, "125%"),
            (1.5f0, "150%"),
            (1.75f0, "175%"),
            (2.0f0, "200%"),
        ]
        
        for (scale_value, label) in scale_presets
            is_selected = abs(EDITOR_SCALE[] - scale_value) < 0.01f0
            if CImGui.MenuItem(label, "", is_selected)
                apply_editor_scale(scale_value, style, io)
            end
        end
        
        CImGui.Separator()
        
        # Custom scale slider
        CImGui.Text("Custom Scale:")
        CImGui.SetNextItemWidth(150)
        if @c CImGui.SliderFloat("##scale_slider", &EDITOR_SCALE[], EDITOR_SCALE_MIN, EDITOR_SCALE_MAX, "%.2f")
            apply_editor_scale(EDITOR_SCALE[], style, io)
        end
        
        CImGui.Separator()
        
        # Increase/Decrease buttons
        if CImGui.MenuItem("Increase Scale", "Ctrl++")
            new_scale = min(EDITOR_SCALE[] + EDITOR_SCALE_STEP, EDITOR_SCALE_MAX)
            apply_editor_scale(new_scale, style, io)
        end
        
        if CImGui.MenuItem("Decrease Scale", "Ctrl+-")
            new_scale = max(EDITOR_SCALE[] - EDITOR_SCALE_STEP, EDITOR_SCALE_MIN)
            apply_editor_scale(new_scale, style, io)
        end
        
        CImGui.Separator()
        
        if CImGui.MenuItem("Reset to Default")
            apply_editor_scale(1.0f0, style, io)
        end
        
        CImGui.EndMenu()
    end
    
    CImGui.Separator()
    
    if CImGui.BeginMenu("DPI Info")
        # Read-only diagnostics (useful to confirm whether SDL is reporting HiDPI)
        fb = unsafe_load(io.DisplayFramebufferScale)
        CImGui.Text("DisplayFramebufferScale: $(round(fb.x; digits=2)) x $(round(fb.y; digits=2))")
        CImGui.Text("Window DPI scale: $(round(Float64(CImGui.igGetWindowDpiScale()); digits=2))")
        CImGui.Separator()
        
        if CImGui.MenuItem("Set editor scale = window DPI scale")
            apply_editor_scale(Float32(CImGui.igGetWindowDpiScale()), style, io)
        end

        CImGui.EndMenu()
    end
    
    CImGui.Separator()
    
    # Style options
    if CImGui.BeginMenu("Theme")
        if CImGui.MenuItem("Dark")
            CImGui.StyleColorsDark()
        end
        if CImGui.MenuItem("Light")
            CImGui.StyleColorsLight()
        end
        if CImGui.MenuItem("Classic")
            CImGui.StyleColorsClassic()
        end
        CImGui.EndMenu()
    end
end

"""
    apply_editor_scale(new_scale, style, io)

Apply a new scale factor to the editor UI.

# Arguments
- `new_scale`: The new scale factor (1.0 = 100%)
- `style`: Pointer to ImGuiStyle
- `io`: Pointer to ImGuiIO
"""
function apply_editor_scale(new_scale::Float32, style, io)
    # Clamp to configured limits
    clamped = min(max(new_scale, EDITOR_SCALE_MIN), EDITOR_SCALE_MAX)
    EDITOR_SCALE[] = clamped

    # Capture the base style once so scaling doesn't accumulate across changes.
    if !_BASE_STYLE_SET[]
        _BASE_STYLE[] = unsafe_load(style)
        _BASE_STYLE_SET[] = true
    end

    # Reset to base style, then apply scaling deterministically.
    unsafe_store!(style, _BASE_STYLE[])

    # Scale spacing/paddings/etc (does not inherently scale fonts).
    CImGui.ImGuiStyle_ScaleAllSizes(style, clamped)

    # Scale fonts using FontGlobalScale - this is THE key setting for font scaling!
    font_global_scale_ptr = io.FontGlobalScale
    unsafe_store!(font_global_scale_ptr, clamped)
    
    # Scale mouse cursor
    mouse_cursor_scale_ptr = style.MouseCursorScale
    unsafe_store!(mouse_cursor_scale_ptr, clamped)
end