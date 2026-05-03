@Base.noinline function _scenebuilder_abstract_dict_as_string_dict(ad::AbstractDict)::Dict{String,Any}
    ad isa Dict{String,Any} && return ad::Dict{String,Any}
    ad isa Dict{Symbol,Any} && return SceneReaderModule._symbol_dict_to_stringkey_tree(ad::Dict{Symbol,Any})
    ad isa JSON3.Object && return SceneReaderModule._json3_object_to_string_dict(ad::JSON3.Object)
    return Dict{String,Any}()
end

@Base.noinline function _scenebuilder_script_entry_dict(script)::Union{Nothing, Dict{String,Any}}
    script isa JSON3.Object && return SceneReaderModule._json3_object_to_string_dict(script::JSON3.Object)
    script isa Dict{String,Any} && return script::Dict{String,Any}
    script isa AbstractDict && return _scenebuilder_abstract_dict_as_string_dict(script::AbstractDict)
    return nothing
end

@Base.noinline function _scenebuilder_script_string_from_dict(d::Dict{String,Any}, k::String, default::String)::String
    v = Base.get(d, k, nothing)
    v === nothing && return default
    v isa String && return v
    v isa Symbol && return String(v)
    v isa Bool && return v ? "true" : "false"
    v isa Int && return string(v)
    v isa Int32 && return string(v)
    v isa Float64 && return string(v)
    return default
end

@Base.noinline function _scenebuilder_script_fields_dict(d::Dict{String,Any})::Dict{String,Any}
    raw = Base.get(d, "fields", nothing)
    raw isa Dict{String,Any} && return raw
    raw isa AbstractDict && return _scenebuilder_abstract_dict_as_string_dict(raw::AbstractDict)
    return Dict{String,Any}()
end

function add_scripts_to_entities(path::String)
    JulGame.juliac_trim_active() && return nothing
    @debug string("Adding scripts to entities")
    @debug string("Path: ", path)
    main_loop = JulGame.current_main()
    entities = main_loop.scene.entities::Vector{Entity}
    @debug string("Entities: ", length(entities))
    loaded_scripts::Set{String} = JulGame.LoadedScripts

    if !JulGame.IS_PACKAGE_COMPILED
        @debug "Package not compiled, skipping dynamic script includes in trim-safe path"
    end

    project_module_value = JulGame.ProjectModule
    project_module_name = project_module_value isa String ? project_module_value : ""
    if !isempty(project_module_name)
        @debug "Loading scripts from project module: $(project_module_name)"
        project_module_symbol = Symbol(project_module_name)
        if isdefined(Main, project_module_symbol)
            project_module = getfield(Main, project_module_symbol)
            if isdefined(project_module, :Scripts)
                JulGame.ScriptModule = getfield(project_module, :Scripts)
            end
        end
    end

    for entity in entities
        scriptCounter = 1
        for script in entity.scripts
            script_dict = _scenebuilder_script_entry_dict(script)
            script_dict === nothing && (scriptCounter += 1; continue)
            script_name = _scenebuilder_script_string_from_dict(script_dict, "name", "")
            isempty(script_name) && (scriptCounter += 1; continue)
            @debug String("Adding script: $(script_name) to entity: $(entity.name)")

            newScript = nothing
            try
                script_module = JulGame.ScriptModule
                script_module isa Module || continue
                module_name = getfield(script_module, Symbol("$(script_name)Module"))
                constructor = Base.invokelatest(getfield, module_name, Symbol(script_name))
                newScript = Base.invokelatest(constructor)
                scriptFields_obj = _scenebuilder_script_fields_dict(script_dict)
                @debug("getting fields for script dict: $(script_name)")
                if newScript !== nothing
                    for key_str in keys(scriptFields_obj)
                        key_symbol = Symbol(key_str)
                        value = Base.get(scriptFields_obj, key_str, nothing)
                        try
                            ftype = fieldtype(typeof(newScript), key_symbol)
                            @debug("type: $(ftype)")
                            if ftype <: EditorExport
                                @debug "Overwriting $(key_symbol) to $(value) using scene file"
                                underlying_type = ftype.parameters[1]
                                Base.invokelatest(setfield!, newScript, key_symbol, EditorExport(convert(underlying_type, value)))
                                continue
                            elseif value === nothing
                                @debug "Value is nothing"
                                continue
                            end
                        catch e
                            @warn string(e)
                        end
                    end
                end
            catch e
                @error sprint(showerror, e)
            end
            if newScript !== nothing
                entity.scripts[scriptCounter] = newScript
            end
            scriptCounter += 1
        end
    end
    return nothing
end
