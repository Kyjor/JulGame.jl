 """
        handle_clipboard_paste()

    Handle Ctrl+V clipboard paste for images in the editor.
    Checks if clipboard contains image data and creates a temporary file for import.
    """
    function handle_clipboard_paste()
        try
            # Try to get image data from platform-specific clipboard
            if Sys.islinux()
                @debug "Linux detected, attempting to get image from X11 clipboard"
                handle_x11_clipboard_image()
            elseif Sys.isapple()
                @debug "macOS detected, attempting to get image from clipboard"
                handle_macos_clipboard_image()
            elseif Sys.iswindows()
                @debug "Windows detected, attempting to get image from clipboard"
                handle_windows_clipboard_image()
            end

            # Only check text clipboard if SDL reports it has text data
            # and avoid errors when clipboard contains binary data
            try
                if SDL2.SDL_HasClipboardText() == SDL2.SDL_TRUE
                    clipboard_text = unsafe_string(SDL2.SDL_GetClipboardText())

                    # Skip if the text looks like an error message from xclip
                    if occursin("xclip: Error:", clipboard_text) || occursin("ProcessFailedException", clipboard_text)
                        @debug "Skipping clipboard text that appears to be an error message"
                        return
                    end

                    @debug "Clipboard text: $(clipboard_text[1:min(100, length(clipboard_text))])"

                    # Check if it's a file path to an image
                    if isfile(clipboard_text) && is_image_file_by_extension(clipboard_text)
                        @debug "Clipboard contains image file path: $(clipboard_text)"
                        add_clipboard_file_to_import_queue(clipboard_text)
                        return
                    end

                    # Check if it's base64 image data (common format: data:image/png;base64,...)
                    if startswith(clipboard_text, "data:image/")
                        @debug "Clipboard contains base64 image data"
                        handle_base64_image_data(clipboard_text)
                        return
                    end
                end
            catch e
                @debug "Error reading text clipboard (likely contains binary data): $(e)"
            end

            # No additional fallback needed - platform-specific functions handle their own cases

        catch e
            @error "Error handling clipboard paste: $(e)"
        end
    end

    """
        handle_x11_clipboard_image()

    Try to get image data from X11 clipboard using xclip command.
    """
    function handle_x11_clipboard_image()
        try
            # Check if xclip is available
            if success(`which xclip`)
                @debug "xclip found, attempting to get image from clipboard"

                # Try to get PNG data from clipboard
                try
                    png_data = read(`xclip -selection clipboard -t image/png -o`)
                    if length(png_data) > 0
                        @debug "Found PNG data in clipboard"
                        # Create temporary file for PNG data
                        temp_file = tempname() * ".png"
                        open(temp_file, "w") do file
                            write(file, png_data)
                        end
                        add_clipboard_file_to_import_queue(temp_file)
                        return
                    end
                catch e
                    @debug "No PNG data in clipboard: $(e)"
                end

                # Try to get JPEG data from clipboard
                try
                    jpeg_data = read(`xclip -selection clipboard -t image/jpeg -o`)
                    if length(jpeg_data) > 0
                        @debug "Found JPEG data in clipboard"
                        # Create temporary file for JPEG data
                        temp_file = tempname() * ".jpg"
                        open(temp_file, "w") do file
                            write(file, jpeg_data)
                        end
                        add_clipboard_file_to_import_queue(temp_file)
                        return
                    end
                catch e
                    @debug "No JPEG data in clipboard: $(e)"
                end

                @debug "No image data found in X11 clipboard"
            else
                @debug "xclip not available, cannot access X11 clipboard"
            end
        catch e
            @warn "Error accessing X11 clipboard: $(e)"
        end
    end

    """
        handle_macos_clipboard_image()

    Try to get image data from macOS clipboard using pbpaste command.
    """
    function handle_macos_clipboard_image()
        try
            # Check if pbpaste is available (should be on all macOS systems)
            if success(`which pbpaste`)
                @debug "pbpaste found, attempting to get image from clipboard"

                # Try to get PNG data from clipboard
                try
                    png_data = read(`pbpaste -pboard general -Prefer png`)
                    if length(png_data) > 0
                        @debug "Found PNG data in clipboard"
                        # Create temporary file for PNG data
                        temp_file = tempname() * ".png"
                        open(temp_file, "w") do file
                            write(file, png_data)
                        end
                        add_clipboard_file_to_import_queue(temp_file)
                        return
                    end
                catch e
                    @debug "No PNG data in clipboard: $(e)"
                end

                # Try to get TIFF data from clipboard (common on macOS)
                try
                    tiff_data = read(`pbpaste -pboard general -Prefer tiff`)
                    if length(tiff_data) > 0
                        @debug "Found TIFF data in clipboard"
                        # Create temporary file for TIFF data
                        temp_file = tempname() * ".tiff"
                        open(temp_file, "w") do file
                            write(file, tiff_data)
                        end
                        add_clipboard_file_to_import_queue(temp_file)
                        return
                    end
                catch e
                    @debug "No TIFF data in clipboard: $(e)"
                end

                # Try to get JPEG data from clipboard
                try
                    jpeg_data = read(`pbpaste -pboard general -Prefer jpeg`)
                    if length(jpeg_data) > 0
                        @debug "Found JPEG data in clipboard"
                        # Create temporary file for JPEG data
                        temp_file = tempname() * ".jpg"
                        open(temp_file, "w") do file
                            write(file, jpeg_data)
                        end
                        add_clipboard_file_to_import_queue(temp_file)
                        return
                    end
                catch e
                    @debug "No JPEG data in clipboard: $(e)"
                end

                @debug "No image data found in macOS clipboard"
            else
                @debug "pbpaste not available, cannot access macOS clipboard"
            end
        catch e
            @warn "Error accessing macOS clipboard: $(e)"
        end
    end

    """
        handle_windows_clipboard_image()

    Try to get image data from Windows clipboard using PowerShell.
    """
    function handle_windows_clipboard_image()
        try
            @debug "Attempting to get image from Windows clipboard using PowerShell"

            # PowerShell script to get image from clipboard and save as PNG
            powershell_script = """
            Add-Type -AssemblyName System.Windows.Forms
            Add-Type -AssemblyName System.Drawing
            \$clipboard = [System.Windows.Forms.Clipboard]::GetImage()
            if (\$clipboard -ne \$null) {
                \$temp_file = [System.IO.Path]::GetTempFileName() + ".png"
                \$clipboard.Save(\$temp_file, [System.Drawing.Imaging.ImageFormat]::Png)
                Write-Output \$temp_file
            }
            """

            try
                # Run PowerShell script
                result = readchomp(`powershell -Command "$powershell_script"`)
                if !isempty(result) && isfile(result)
                    @debug "Found image data in Windows clipboard, saved to: $(result)"
                    add_clipboard_file_to_import_queue(result)
                    return
                end
            catch e
                @debug "No image data in Windows clipboard: $(e)"
            end

            @debug "No image data found in Windows clipboard"
        catch e
            @warn "Error accessing Windows clipboard: $(e)"
        end
    end

    """
        is_image_file_by_extension(filepath::String) -> Bool

    Check if file has an image extension.
    """
    function is_image_file_by_extension(filepath::String)
        ext = lowercase(splitext(filepath)[2])
        return ext in [".png", ".jpg", ".jpeg", ".bmp", ".tga", ".gif", ".webp"]
    end

    """
        add_clipboard_file_to_import_queue(filepath::String)

    Add a clipboard file path to the import queue.
    """
    function add_clipboard_file_to_import_queue(filepath::String)
        dropped_files = "dropped_files"
        if get(JulGame.EditorState, dropped_files, nothing) === nothing
            JulGame.EditorState[dropped_files] = [filepath]
        else
            push!(JulGame.EditorState[dropped_files], filepath)
        end
        @debug "Added clipboard file to import queue: $(basename(filepath))"
    end

    """
        handle_base64_image_data(data::String)

    Handle base64 encoded image data from clipboard.
    Creates a temporary file and adds it to the import queue.
    """
    function handle_base64_image_data(data::String)
        try
            # Parse the data URL format: data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAA...
            if !occursin(";base64,", data)
                @warn "Invalid base64 image data format"
                return
            end

            # Extract MIME type and base64 data
            parts = split(data, ";base64,")
            if length(parts) != 2
                @warn "Invalid base64 image data format"
                return
            end

            mime_part = parts[1]
            base64_data = parts[2]

            # Determine file extension from MIME type
            extension = ".png"  # default
            if occursin("image/jpeg", mime_part) || occursin("image/jpg", mime_part)
                extension = ".jpg"
            elseif occursin("image/png", mime_part)
                extension = ".png"
            elseif occursin("image/gif", mime_part)
                extension = ".gif"
            elseif occursin("image/bmp", mime_part)
                extension = ".bmp"
            elseif occursin("image/webp", mime_part)
                extension = ".webp"
            end

            # Create temporary file
            temp_dir = mktempdir()
            timestamp = Dates.format(Dates.now(), "yyyymmdd_HHMMSS")
            temp_filename = "clipboard_image_$(timestamp)$(extension)"
            temp_filepath = joinpath(temp_dir, temp_filename)

            # Decode base64 and write to file
            image_data = Base64.base64decode(base64_data)
            write(temp_filepath, image_data)

            @debug "Created temporary image file from clipboard: $(temp_filepath)"

            # Add to import queue
            add_clipboard_file_to_import_queue(temp_filepath)

        catch e
            @error "Error processing base64 image data: $(e)"
        end
    end

    function _handle_clipboard_paste(this::Input, evt::SDL2.SDL_Event)
        # Handle Ctrl+V for clipboard paste in editor
        if JulGame.IS_EDITOR && evt.type == SDL2.SDL_KEYDOWN
            if evt.key.keysym.sym == SDL2.LibSDL2.SDLK_v && (evt.key.keysym.mod & SDL2.LibSDL2.KMOD_CTRL) != 0
                @debug "Ctrl+V detected, checking clipboard for image"
                handle_clipboard_paste()
            end
        end
    end

    function _handle_dropped_files(this::Input, evt::SDL2.SDL_Event)
        dropped_files = "dropped_files"
            dropped_texts = "dropped_texts"
            if evt.type == SDL2.SDL_DROPFILE
                @debug "Dropped file: $(unsafe_string(evt.drop.file))"
                if JulGame.IS_EDITOR
                    if get(JulGame.EditorState, dropped_files, nothing) === nothing
                        JulGame.EditorState[dropped_files] = [unsafe_string(evt.drop.file)]
                    else
                        push!(JulGame.EditorState[dropped_files], unsafe_string(evt.drop.file))
                    end
                end
                # TODO: Handle dropped file
                SDL2.SDL_free(evt.drop.file)
            elseif evt.type == SDL2.SDL_DROPTEXT
                @debug "Dropped text: $(unsafe_string(evt.drop.file))"
                if JulGame.IS_EDITOR
                    if get(JulGame.EditorState, dropped_texts, nothing) === nothing
                        JulGame.EditorState[dropped_texts] = [unsafe_string(evt.drop.file)]
                    else
                        push!(JulGame.EditorState[dropped_texts], unsafe_string(evt.drop.file))
                    end
                end
                SDL2.SDL_free(evt.drop.file)
            elseif evt.type == SDL2.SDL_DROPBEGIN
                @debug "Drop begin"
            elseif evt.type == SDL2.SDL_DROPCOMPLETE
                @debug "Drop complete"
            elseif evt.type == SDL2.SDL_CLIPBOARDUPDATE
                @debug "Clipboard update"
            end
    end