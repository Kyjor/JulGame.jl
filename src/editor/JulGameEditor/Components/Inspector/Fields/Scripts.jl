function display_script_field_input(script, field)
    ftype = typeof(getproperty(script, field))
    if ftype == String
        buf = "$(getproperty(script, field))"*"\0"^(64)
        CImGui.InputText("$(field)", buf, length(buf))
        currentTextInTextBox = ""
        for characterIndex = eachindex(buf)
            if Int32(buf[characterIndex]) == 0 
                if characterIndex != 1
                    currentTextInTextBox = String(SubString(buf, 1, characterIndex-1))
                end
                break
            end
        end
        setproperty!(script, field, currentTextInTextBox)
    elseif ftype == Float64 || ftype == Float32
        x = ftype(getproperty(script, field))
        x = Cfloat(x)
        @c CImGui.InputFloat("$(field)", &x, 1)
        setproperty!(script, field, ftype(x))
    elseif ftype <: Int64 || ftype <: Int32 || ftype <: Int16 || ftype <: Int8
        x = ftype(getproperty(script, field))
        x = convert(Int32, x)
        @c CImGui.InputInt("$(field)", &x, 1)
        x = convert(ftype, x)
        setproperty!(script, field, x)
    elseif ftype == Bool
        x = getproperty(script, field)
        @c CImGui.Checkbox("$(field)", &x)
        setproperty!(script, field, x)
    end
end

function init_undefined_field(script, field)
    ftype = typeof(getproperty(script, field))
    if ftype == String
        setproperty!(script, field, "")
    elseif ftype <: Number
        setproperty!(script, field, 0)
    elseif ftype == Bool
        setproperty!(script, field, false)
    end
end

"""
    open_file_in_editor(file_path::String)

Opens a file in the user's preferred editor. Falls back to system default if no preference is set.
Supports configuration via config.julgame file with "PreferredEditor" setting.

Supported editors:
- "vscode" - Visual Studio Code
- "sublime" - Sublime Text  
- "atom" - Atom Editor
- "vim" - Vim/NeoVim
- "emacs" - Emacs
- "nano" - Nano
- "system" - Use system default file association
- "custom" - Use custom command from "CustomEditorCommand" config
"""
function open_file_in_editor(file_path::String)
    # Get editor preference from config
    editor_preference = get_editor_preference()
    
    try
        if editor_preference == "vscode"
            open_in_vscode(file_path)
        elseif editor_preference == "sublime"
            open_in_sublime(file_path)
        elseif editor_preference == "atom"
            open_in_atom(file_path)
        elseif editor_preference == "vim"
            open_in_vim(file_path)
        elseif editor_preference == "emacs"
            open_in_emacs(file_path)
        elseif editor_preference == "nano"
            open_in_nano(file_path)
        elseif editor_preference == "custom"
            open_in_custom_editor(file_path)
        else
            # Default: use system file association
            open_with_system_default(file_path)
        end
    catch e
        @warn "Failed to open file with preferred editor ($editor_preference): $e"
        @info "Falling back to system default"
        try
            open_with_system_default(file_path)
        catch fallback_error
            @error "Failed to open file with system default: $fallback_error"
        end
    end
end

function get_editor_preference()
    # Try to read from project config first
    try
        config_path = joinpath(JulGame.BasePath, "config.julgame")
        if isfile(config_path)
            config = Dict{String, String}()
            open(config_path, "r") do file
                for line in eachline(file)
                    if contains(line, "=")
                        key, value = split(line, "=", limit=2)
                        config[strip(key)] = strip(value)
                    end
                end
            end
            return get(config, "PreferredEditor", "system")
        end
    catch e
        @debug "Could not read editor preference from config: $e"
    end
    
    return "system"  # Default fallback
end

function open_with_system_default(file_path::String)
    if Sys.iswindows()
        run(`cmd /c start "" "$file_path"`)
    elseif Sys.isapple()
        run(`open "$file_path"`)
    else  # Linux and other Unix-like systems
        run(`xdg-open "$file_path"`)
    end
end

function open_in_vscode(file_path::String)
    # Try VSCode URL scheme first (works if VSCode is running)
    try
        SDL2.SDL_OpenURL("vscode://file/$(file_path)")
        return
    catch
        # Fall back to command line
        if Sys.iswindows()
            run(`code "$file_path"`)
        else
            run(`code "$file_path"`)
        end
    end
end

function open_in_sublime(file_path::String)
    if Sys.iswindows()
        run(`subl "$file_path"`)
    elseif Sys.isapple()
        run(`subl "$file_path"`)
    else
        run(`subl "$file_path"`)
    end
end

function open_in_atom(file_path::String)
    run(`atom "$file_path"`)
end

function open_in_vim(file_path::String)
    if Sys.iswindows()
        # Open in new terminal window
        run(`cmd /c start cmd /k "vim \"$file_path\""`)
    else
        # Try to detect terminal and open vim
        terminals = ["gnome-terminal", "konsole", "xterm", "alacritty", "kitty"]
        for terminal in terminals
            try
                if terminal == "gnome-terminal"
                    run(`$terminal -- vim "$file_path"`)
                elseif terminal == "konsole"
                    run(`$terminal -e vim "$file_path"`)
                else
                    run(`$terminal -e vim "$file_path"`)
                end
                return
            catch
                continue
            end
        end
        # Fallback: try vim in current terminal (won't work in GUI context)
        run(`vim "$file_path"`)
    end
end

function open_in_emacs(file_path::String)
    run(`emacs "$file_path"`)
end

function open_in_nano(file_path::String)
    if Sys.iswindows()
        run(`cmd /c start cmd /k "nano \"$file_path\""`)
    else
        terminals = ["gnome-terminal", "konsole", "xterm"]
        for terminal in terminals
            try
                run(`$terminal -e nano "$file_path"`)
                return
            catch
                continue
            end
        end
        run(`nano "$file_path"`)
    end
end

function open_in_custom_editor(file_path::String)
    # Get custom command from config
    try
        config_path = joinpath(JulGame.BasePath, "config.julgame")
        if isfile(config_path)
            config = Dict{String, String}()
            open(config_path, "r") do file
                for line in eachline(file)
                    if contains(line, "=")
                        key, value = split(line, "=", limit=2)
                        config[strip(key)] = strip(value)
                    end
                end
            end
            
            custom_command = get(config, "CustomEditorCommand", "")
            if !isempty(custom_command)
                # Replace {file} placeholder with actual file path
                command = replace(custom_command, "{file}" => file_path)
                run(`$command`)
                return
            end
        end
    catch e
        @error "Failed to execute custom editor command: $e"
    end
    
    throw(ErrorException("No custom editor command configured"))
end


function create_new_script(name)
    path = joinpath(JulGame.BasePath, "scripts", "$(name).jl")
    touch(joinpath(path))
    file = open(path, "w")
        println(file, newScriptContent(name))
    close(file)

    open_file_in_editor(path)
end

function show_script_editor(entity, newScriptText)
    if CImGui.TreeNode("Scripts")
        show_custom_field_mapping(entity, :scripts, :path, entity.scripts)
        # text = text_input_single_line("Name", newScriptText) 
        # CImGui.SameLine()
        # if CImGui.Button("Create New Script")
        #     create_new_script(text)
        #     include(joinpath(JulGame.BasePath, "scripts", "$(text).jl"))
        #     newScript = Base.invokelatest(eval, Symbol(text))
        #     newScript = Base.invokelatest(newScript)
        #     newScript.parent = entity
        #     push!(entity.scripts, newScript)
        # end
        
        # script = display_files(joinpath(JulGame.BasePath, "scripts"), "scripts", "Add Script")
        # if script != ""
        #     @debug("Adding script: $(script) to: $(entity.name)")
        #     Base.include(JulGame.ScriptModule, joinpath(JulGame.BasePath, "scripts", "$(script).jl"))
        #     module_name = getfield(JulGame.ScriptModule, Symbol("$(script)Module"))
        #     constructor = Base.invokelatest(getfield, module_name, Symbol(script)) 
        #     newScript = Base.invokelatest(constructor)
        #     newScript.parent = entity
        #     # TODO: Get this working
        #     # if JulGame.IS_EDITOR_PLAY_MODE 
        #     #     JulGame.initialize(newScript)
        #     # end
        #     push!(entity.scripts, newScript)
        # end

        # for i = eachindex(entity.scripts)
        #     scriptName = split("$(typeof(entity.scripts[i]))", ".")[end]
        #     if CImGui.TreeNode("$(i): $(scriptName)")
        #         if CImGui.Button("Open Script")
        #             path = joinpath(JulGame.BasePath, "scripts", "$(scriptName).jl")
        #             open_file_in_editor(path)
        #         end

        #         if CImGui.Button("Reload $scriptName:$(i)")
        #             Base.include(JulGame.ScriptModule, joinpath(JulGame.BasePath, "scripts", "$(scriptName).jl"))
        #             module_name = getfield(JulGame.ScriptModule, Symbol("$(scriptName)Module"))
        #             constructor = Base.invokelatest(getfield, module_name, Symbol(scriptName)) 
        #             entity.scripts[i] = Base.invokelatest(constructor)
        #             entity.scripts[i].parent = entity
        #         end

        #         for field in fieldnames(typeof(entity.scripts[i]))
        #             if field == :parent || !(fieldtype(typeof(entity.scripts[i]), field) <: EditorExport)
        #                 continue
        #             end
        #             if isdefined(entity.scripts[i], Symbol(field)) 
        #                 display_script_field_input(entity.scripts[i], field)
        #             else 
        #                 init_undefined_field(entity.scripts[i], field)
        #             end
        #         end

        #         CImGui.TreePop()
        #     end
        # end
        CImGui.TreePop()
    end
end