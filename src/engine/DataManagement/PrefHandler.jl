module PrefHandlerModule
    using ...JulGame

    export get_pref_path
    """
        get_pref_path(org::String, app::String; file_name::String="", create_dir::Bool=true)

    Get the user-and-app-specific path where files can be written. Wrapper for SDL_GetPrefPath.

    # Arguments
    - `org`: The name of your organization.
    - `app`: The name of your application.
    - `file_name`: The name of the file to create (default: "").
    - `create_dir`: Whether to create the directory if it doesn't exist (default: true).
    # Returns
    -  Returns a UTF-8 string of the user directory in platform-dependent notation. NULL if there's a problem (creating directory failed, etc.).
    """
    function get_pref_path(org::String, app::String; file_name::String="", create_dir::Bool=true)
        path = SDL2.SDL_GetPrefPath(org, app)
        path_str = unsafe_string(path)

        if create_dir && !isempty(path_str)
            try
                mkpath(path_str)
                if !isempty(file_name) && !isfile(joinpath(path_str, file_name))
                    @debug "Creating file: $(joinpath(path_str, file_name))"
                    touch(joinpath(path_str, file_name))
                end
                path_str = joinpath(path_str, file_name)
                @debug "Path: $(path_str)"
            catch e
                @warn "Failed to create preference directory: $e"
            end
        end

        @debug "pref path: $(path_str)"
        return path_str
    end
end
