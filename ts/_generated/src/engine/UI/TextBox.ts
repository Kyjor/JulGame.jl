export {}

    // using ..UI.JulGame
    // using ..UI.(globalThis as any).JulGame.Math
    // import ..UI
    // using (globalThis as any).JulGame.EffectsModule
    // using (globalThis as any).JulGame.EffectRendererModule
    // using (globalThis as any).JulGame.EffectCacheModule

    
    
    
    
    
    let DEFAULT_FONT = "Default"
    
    // Helper to map (globalThis as any).JulGame.SCALE_QUALITY ("0","1","2") to SDL scale mode
    function get_scale_mode_from_quality() {
        return SDL2.SDL_ScaleModeBest
        // TODO: Add text scaling option?
        let q = try
            string((globalThis as any).JulGame.SCALE_QUALITY)
        catch
            "2"
        }
        let val = try
            parse(Int, q)
        catch
            2
        }
        if (val == 0) {
            return SDL2.SDL_ScaleModeNearest
        elseif val == 2
            return SDL2.SDL_ScaleModeBest
        else
            return SDL2.SDL_ScaleModeLinear
        }
    }
    class TextBox extends UI.UIElement {
        font: TTF_Font} | null
        fontPath: string
        fontSize: number
        isConstructed: boolean
        maxLineWidth: number
        renderText: SDL_Surface} | null
        text: string
        textTexture: SDL_Texture} | null
        wrapWords: boolean
        isDynamic: boolean
        //  effects support
        effects: any[]  // Will hold Effect objects
        effectTexture: SDL_Texture} | null
        needsEffectUpdate: boolean
        effectCacheKey: String  // Content hash for caching

        function TextBox(text: string; 
            id: string=(globalThis as any).JulGame.generate_uuid(), 
            name: string = "TextBox", 
            anchor: symbol = :none,
            anchorOffset = {x: 0, y: 0}, 
            isWorldEntity: boolean=false, 
            layer: number=0,
            position = {x: 0, y: 0}, 
            clickEvents: Function[] = Function[],
            hoverEnterEvents: Function[] = Function[],
            hoverExitEvents: Function[] = Function[],
            isActive: boolean=true,
            persistentBetweenScenes: boolean=false,
            color= [255, 255, 255, 255], 
            fontPath: string = "FiraCode-Regular.ttf", 
            fontSize: number = 16, 
            maxLineWidth: number=0, 
            wrapWords: boolean=true,
            isDynamic: boolean=false,
            parent: UIElement | null | IEntity | ISprite=null
        )

            
            
            this.isConstructed = false
            this.anchor = deepcopy(UI.anchor_types)

            this.anchor.current_state = anchor
            this.anchorOffset = anchorOffset

            this.clickEvents = clickEvents
            this.hoverEnterEvents = hoverEnterEvents
            this.hoverExitEvents = hoverExitEvents

            this.font = null
            this.fontPath = fontPath
            this.fontSize = fontSize  // Store the base font size
            this.id = id
            this.layer = layer
            this.name = name
            this.position = position
            setfield(this, :text, text)
            this.isWorldEntity = isWorldEntity
            this.persistentBetweenScenes = persistentBetweenScenes
            this.isActive = isActive
            this.color = color
            this.maxLineWidth = maxLineWidth
            this.wrapWords = wrapWords
            this.isHovered = false
            this.isDynamic = isDynamic
            
            this.textTexture = null
            this.renderText = null
            this.parent = parent
            // Initialize effects
            this.effects = Any[]
            this.effectTexture = null
            this.needsEffectUpdate = false
            this.effectCacheKey = ""
            if (strip(fontPath) == "") {
                console.debug("fontPath is empty, // using default font")
                let fontPath = "Default"
            }

            // Load the font with the true font size (scaled for current window size)
            UI.load_font(this, fontPath)
            this.isConstructed = true

        }
    }

    function UI_render(this: TextBox) {
        if (!this.isActive || (globalThis as any).JulGame.IS_CHANGING_SCENE) {
            return
        }
        
        // Only apply effects if they're pending and renderer is available
        // This should be rare after initial setup due to caching
        if (!isempty(this.effects) && this.needsEffectUpdate) {
            update_effects(this)
        }
        
        // Use effect texture if available, otherwise use regular texture
        console.debug("Render select") name=this.name has_effects=!isempty(this.effects) effect_tex=this.effectTexture text_tex=this.textTexture needsUpdate=this.needsEffectUpdate
        
        // Force effect texture usage when effects exist
        if (!isempty(this.effects)) {
            if (this.effectTexture != null) {
                console.debug("Using effect texture") name=this.name
                let texture_to_render = this.effectTexture
            else
                console.debug("Effects exist but no effect texture - forcing update") name=this.name
                this.needsEffectUpdate = true
                update_effects(this)
                if (this.effectTexture != null) {
                    console.debug("Using effect texture after forced update") name=this.name
                    texture_to_render = this.effectTexture
                else
                    console.debug("No effect texture available, // using regular texture") name=this.name
                    texture_to_render = this.textTexture
                }
            }
        elseif this.textTexture != null
            console.debug("Using regular texture") name=this.name
            texture_to_render = this.textTexture
        else
            console.debug("No texture to render") name=this.name
            return  // No texture to render
        }
        console.debug("Rendering texture") name=this.name ptr=texture_to_render size= [this.size.x,this.size.y] position= [this.position.x,this.position.y]
        if (!this.isWorldEntity) {
            UI.align_to_anchor(this)
        }

        if ((globalThis as any).JulGame.IS_DEBUG) {

            (globalThis as any).JulGameSdl.glue_SDL_SetRenderDrawColor(0, 255, 0, 255);
            (globalThis as any).JulGameSdl.glue_SDL_RenderDrawLines((globalThis as any).JulGame.Renderer, [
                (globalThis as any).JulGameSdl.glue_SDL_Point(this.position.x, this.position.y), 
                (globalThis as any).JulGameSdl.glue_SDL_Point(this.position.x + this.size.x, this.position.y),
                (globalThis as any).JulGameSdl.glue_SDL_Point(this.position.x + this.size.x, this.position.y + this.size.y), 
                (globalThis as any).JulGameSdl.glue_SDL_Point(this.position.x, this.position.y + this.size.y), 
                (globalThis as any).JulGameSdl.glue_SDL_Point(this.position.x, this.position.y)], 5)
            (globalThis as any).JulGameSdl.glue_SDL_SetRenderDrawColor((globalThis as any).JulGame.Renderer, rgba.r, rgba.g, rgba.b, rgba.a);
        }

        let camera = MAIN.scene.camera
        
        (globalThis as any).JulGameSdl.glue_SDL_SetTextureScaleMode(texture_to_render, get_scale_mode_from_quality())
        // Handle world coordinates for world entities, similar to Sprite component
        if (this.isWorldEntity && camera !== null) {
            let S = (globalThis as any).JulGame.pixels_per_world_unit(camera)
            let posX = (this.position.x - (camera.position.x + camera.offset.x)) * S
            let posY = (this.position.y - (camera.position.y + camera.offset.y)) * S
            @assert (globalThis as any).JulGameSdl.glue_SDL_RenderCopyF(
                (globalThis as any).JulGame.Renderer, 
                texture_to_render, 
                null, 
                Ref((globalThis as any).JulGameSdl.glue_SDL_FRect(
                    Float32(posX), 
                    Float32(posY), 
                    Float32(this.size.x * camera.zoom), 
                    Float32(this.size.y * camera.zoom)
                ))
            ) == 0 "error rendering textbox text: $(unsafe_string((globalThis as any).JulGameSdl.glue_SDL_GetError()))"
        else
            // Render with screen-space positioning (traditional UI)
            let adjusted_position = {x: 0, y: 0}
            if (this.originalSize != this.size && this.anchor.current_state == :none) {
                adjusted_position = Vector2(this.position.x - (this.size.x - this.originalSize.x)/2, this.position.y - (this.size.y - this.originalSize.y)/2)
                // console.debug("difference in size: $(this.size.x - this.originalSize.x), $(this.size.y - this.originalSize.y)")
                // console.debug("adjusted position: $(adjusted_position.x), $(adjusted_position.y)")
            else
                adjusted_position = this.position
            }
            @assert (globalThis as any).JulGameSdl.glue_SDL_RenderCopyF(
                (globalThis as any).JulGame.Renderer, 
                texture_to_render, 
                null, 
                Ref((globalThis as any).JulGameSdl.glue_SDL_FRect(
                    Float32(adjusted_position.x), 
                    Float32(adjusted_position.y), 
                    Float32(this.size.x), 
                    Float32(this.size.y)
                ))
            ) == 0 "error rendering textbox text: $(unsafe_string((globalThis as any).JulGameSdl.glue_SDL_GetError()))"
        }
    }

    function UI_load_font(this: TextBox,  fontPath: string) {
        // Calculate the true font size based on window resolution
        //trueFontSize = get_true_font_size(this.fontSize)
        let trueFontSize = this.fontSize

        // If the font is already loaded, clean it up
        if (this.font != null) {
            console.debug("closing font")
            //console.log(this.font)
            SDL2.TTF_CloseFont(this.font)
            this.font = null
        }
        free_text_resources(this)

        
        this.font = load_font_sdl(fontPath, trueFontSize)
        if (this.font == null) {
            error("Failed to load font, $(unsafe_string((globalThis as any).JulGameSdl.glue_SDL_GetError())), loading default font")
            this.fontPath = DEFAULT_FONT
            this.font = CallSDLFunction(SDL2.TTF_OpenFontRW, (globalThis as any).JulGameSdl.glue_SDL_RWFromConstMem(pointer((globalThis as any).JulGame.BUILT_IN_ASSETS["Font"]), (globalThis as any).JulGame.BUILT_IN_ASSETS["Font"].length), 1, TypeConversions.safe_int32_convert(fontSize))
        }
        if (fontPath != "Default") {
            this.fontPath = fontPath
        }

        // prevents segfault when text is empty
        if (this.text == "") {
            this.text = " "
        }

        // Use high-quality font rendering with or without effects
        this.renderText = CallSDLFunction(SDL2.TTF_RenderUTF8_Blended, this.font, this.text, (globalThis as any).JulGameSdl.glue_SDL_Color(TypeConversions.safe_int32_convert(this.color[0]), TypeConversions.safe_int32_convert(this.color[1]), TypeConversions.safe_int32_convert(this.color[2]), TypeConversions.safe_int32_convert(this.color[3])))
        if (this.renderText == null) {
            error("Failed to render text for textbox $(this.name)")
            return
        }
        let surface = unsafe_wrap(Array, this.renderText, 10; own = false)
        this.size = {x: surface[0].w, y: surface[0].h}
        this.originalSize = this.size
        this.textTexture = CallSDLFunction(SDL2.SDL_CreateTextureFromSurface, (globalThis as any).JulGame.Renderer, this.renderText)

        if (!this.isWorldEntity) {
            UI.align_to_anchor(this)
        }
    }

    function UI_initialize(this: TextBox) {
        // Ensure font is properly scaled for the current window size
        UI.handle_window_resize(this)
        // Only center screen-space UI, not world entities
        if (!this.isWorldEntity) {
            UI.align_to_anchor(this)
        }
    }

    function UI_add_click_event(this: TextBox,  event) {
        this.clickEvents.push(event)
    }

    function load_font_sdl(fontPath: string,  fontSize: number) {
        if (haskey((globalThis as any).JulGame.FONT_CACHE, get_comma_separated_path(fontPath)) || fontPath == "Default" || fontPath == "") {
            if (fontPath == "Default" || fontPath == "") {
                let raw_data = (globalThis as any).JulGame.BUILT_IN_ASSETS["Font"]
                console.debug("loading default font")
            else
                raw_data = (globalThis as any).JulGame.FONT_CACHE[get_comma_separated_path(fontPath)]
                console.debug("loading font from cache")
            }
            let rw = (globalThis as any).JulGameSdl.glue_SDL_RWFromConstMem(pointer(raw_data), raw_data.length)
            if (rw != null) {
                console.debug("loading font from cache")
                console.debug("comma separated path: ", get_comma_separated_path(fontPath))
                return CallSDLFunction(SDL2.TTF_OpenFontRW, rw, 1, TypeConversions.safe_int32_convert(fontSize))
            }
        }
        console.debug("Loading font from disk, there are $((globalThis as any).JulGame.FONT_CACHE.length) fonts in cache")
        
        let basePath = joinpath((globalThis as any).JulGame.BasePath, "assets", "fonts")
        return CallSDLFunction(SDL2.TTF_OpenFont, joinpath(basePath, fontPath), TypeConversions.safe_int32_convert(fontSize))
    }

    function get_comma_separated_path(path: string) {
        // Normalize the path to use forward slashes
        let normalized_path = replace(path, '\\' => '/')
        
        // Split the path into components
        let parts = split(normalized_path, '/')
        
        let result = join(parts[1:}], ",")
    
        return result  
    }

    /*
        rerender_text(this)

    Recreates the font surface and texture. If the TextBox is not a world entity, it centers the text.

    // Arguments
    - `this`: The TextBox object to update.

    // Examples
    */
    function UI_rerender_text(this: TextBox) {
        if ((globalThis as any).JulGame.IS_CHANGING_SCENE) {
            return
        }
        free_text_resources(this)

        if (this.text == "") {
            this.text = " "
        }

        // Check if we need to wrap text
        let color = (globalThis as any).JulGameSdl.glue_SDL_Color(TypeConversions.safe_int32_convert(this.color[0]), TypeConversions.safe_int32_convert(this.color[1]), TypeConversions.safe_int32_convert(this.color[2]), TypeConversions.safe_int32_convert(this.color[3]))
        this.renderText = if this.maxLineWidth > 0 && this.font != null && this.text != ""
            SDL2.TTF_RenderUTF8_Blended_Wrapped(this.font, this.wrapWords ? this.text : wrap_text(this.text, this.font, this.maxLineWidth, this.wrapWords), color, TypeConversions.safe_int32_convert(this.maxLineWidth))
        elseif this.font != null && this.text != ""
            this.renderText = SDL2.TTF_RenderUTF8_Blended(this.font, this.text, color)
        else
            null
        }
        if (this.renderText == null) {
            console.debug("Failed to render text for textbox $(this.name)")
            return
        }
        surface = unsafe_wrap(Array, this.renderText, 10; own = false)
        this.size = {x: surface[0].w, y: surface[0].h}
        this.originalSize = {x: this.size.x, y: this.size.y}
        this.textTexture = (globalThis as any).JulGameSdl.glue_SDL_CreateTextureFromSurface((globalThis as any).JulGame.Renderer, this.renderText)

        if (!this.isWorldEntity) {
            UI.align_to_anchor(this)
        }
        
        // Update effects if needed
        if (!isempty(this.effects)) {
            update_effects(this)
        }
    }

    function free_text_resources(this: TextBox) {
        if (this.renderText != null) {
            (globalThis as any).JulGameSdl.glue_SDL_FreeSurface(this.renderText)
            this.renderText = null
        }
        
        // DON'T destroy effect textures - they are managed by the cache
        // Just clear the reference
        if (this.effectTexture != null) {
            console.debug("Clearing effect texture reference for $(this.name)")
            this.effectTexture = null
        }
        
        // Handle regular text texture
        console.debug("Destroying text texture for $(this.name)")
        (globalThis as any).JulGameSdl.glue_SDL_DestroyTexture(this.textTexture)
        this.textTexture = null
    }

    // Helper function to manually wrap text at character boundaries
    function wrap_text(text: string,  font,  maxWidth: number,  wrapWords: boolean) {
        if (maxWidth <= 0 || isempty(text)) {
            return text
        }

        let lines = String[]
        let current_line = ""
        let current_width = 0
        
        // If wrapping at word boundaries
        if (wrapWords) {
            let words = split(text)
            for (const word of words) {
                w, h = Ref{Cint}(0), Ref{Cint}(0)
                let word_with_space = word * " "
                SDL2.TTF_SizeUTF8(font, word_with_space, w, h)
                
                if (current_width + w[] > maxWidth && !isempty(current_line)) {
                    lines.push(rstrip(current_line))
                    current_line = word * " "
                    current_width = w[]
                else
                    current_line *= word * " "
                    current_width += w[]
                }
            }
            
            if (!isempty(current_line)) {
                lines.push(rstrip(current_line))
            }
        else
            // Character by character wrapping
            for (const c of text) {
                let char_str = string(c)
                w, h = Ref{Cint}(0), Ref{Cint}(0)
                SDL2.TTF_SizeUTF8(font, char_str, w, h)
                
                if (current_width + w[] > maxWidth && !isempty(current_line)) {
                    lines.push(current_line)
                    current_line = char_str
                    current_width = w[]
                else
                    current_line *= char_str
                    current_width += w[]
                }
            }
            
            if (!isempty(current_line)) {
                lines.push(current_line)
            }
        }
        
        return join(lines, "\n")
    }

    function UI_set_color(this: TextBox; r: number=255,  g: number=255,  b: number=255,  a: number=255) {
        this.color = [r%256, g%256, b%256, a%256]
        // Invalidate effects cache when color changes
        if (!isempty(this.effects)) {
            this.needsEffectUpdate = true
        }
        UI.rerender_text(this)
    }
    
    function UI_update_font_size(this: TextBox,  newSize: Int; basePath: string = "") {
        let applied_size = max(1, newSize)
        if (this.fontSize == applied_size && this.font != null) {
            return
        }
        // Store the user-facing base size and force a fresh font/surface rebuild.
        this.fontSize = applied_size

        if (this.font != null) {
            SDL2.TTF_CloseFont(this.font)
            this.font = null
        }
        UI.load_font(this, this.fontPath)
        UI.rerender_text(this)
        if (!isempty(this.effects)) {
            UI.request_effects_refresh(this)
        }
    }

    /*
        get_true_font_size(baseFontSize: number): number

    Calculates the true font size based on the current window size and base resolution.
    This ensures text appears at a consistent size regardless of window resolution.

    // Arguments
    - `baseFontSize: number`: The base font size (designed for the base resolution)

    // Returns
    - `Int`: The scaled font size for the current window resolution
    */
    function get_true_font_size(baseFontSize: number): number
        // Get current window size and base resolution
        let windowSize = (globalThis as any).JulGame.get_window_size()
        let baseResolution = (globalThis as any).JulGame.MAIN.windowManager.baseResolution
        
        // Calculate scaling factors
        let scaleX = windowSize.x / baseResolution.x
        let scaleY = windowSize.y / baseResolution.y
        
        // Use the smaller scaling factor to ensure text fits in both dimensions
        let scale = min(scaleX, scaleY)
        
        // Calculate and return the scaled font size
        return TypeConversions.safe_int32_convert(Math.round(baseFontSize * scale))
    }

    function UI_destroy(this: TextBox) {
        if (this.font != null) {
            SDL2.TTF_CloseFont(this.font)
            this.font = null
        }
        
        free_text_resources(this)

        MAIN.scene.uiElements = filter(x -> x !== this, MAIN.scene.uiElements)
    }
    
    // Generate a stable string for effects to use in cache keys
    function serialize_effects(effects: any[]): string
        if (isempty(effects)) {
            return "[]"
        }
        parts = String[]
        for (const eff of effects) {
            let T = typeof(eff)
            let fnames = fieldnames(T)
            let vals = String[]
            for (const f of fnames) {
                // Avoid dumping huge pointers; just tag Ptr fields
                let v = getfield(eff, f)
                if (v isa Ptr) {
                    vals.push(string(f, "=Ptr"))
                else
                    vals.push(string(f, "=", v))
                }
            }
            parts.push(string(nameof(T), "(", join(vals, ","), ")"))
        }
        return "[" * join(parts, ";") * "]"
    }

    // Generate cache key for effects based on content
    function generate_effect_cache_key(this: TextBox): string
        // Include all factors that affect the final rendered result
        let content = string(
            this.text, "|",
            this.color, "|", 
            this.fontPath, "|",
            this.fontSize, "|",
            serialize_effects(this.effects), "|",
            this.size
        )
        return string(hash(content))
    }
    
    //  effects API
    function UI_apply_effects(this: TextBox,  effects: Vector) {
        this.effects = Any[effect for effect in effects]
        
        // Generate new cache key
        let newCacheKey = generate_effect_cache_key(this)
        console.debug("TextBox.apply_effects!: effects updated") name=this.name key=newCacheKey effects_count=this.effects.length
        
        // Only update if cache key changed
        if (this.effectCacheKey != newCacheKey) {
            this.effectCacheKey = newCacheKey
            this.needsEffectUpdate = true
        else
            console.debug("apply_effects!: cache key unchanged; skipping recompute") name=this.name
        }
        
        // Try to apply effects now, but don't fail if renderer isn't ready
        update_effects(this)

    }

    /*
        request_effects_refresh(this)

    Recompute the effect texture after **in-place** edits to effect objects (e.g. inspector sliders).
    `apply_effects!` already bumps the cache key when the `effects` vector is replaced; mutating fields
    inside a `BevelEmbossEffect` does not, so callers that edit effects directly must call this.
    */
    function UI_request_effects_refresh(this: TextBox) {
        if (isempty(this.effects)) { return this }
        this.effectCacheKey = generate_effect_cache_key(this)
        this.needsEffectUpdate = true
        update_effects(this)

    }
    
    function apply_style(this: TextBox,  style) {
        return apply_effects(this, style.effects)
    }
    
    // Global effects cache
    const EFFECT_CACHE = Dict{String, Ptr{SDL2.SDL_Texture}}()
    const MAX_CACHE_SIZE = 100
    
    // Cache management functions
    function cache_effect_texture(key: string,  texture: SDL_Texture}) {
        // Simple approach: just store the texture, let GC handle cleanup
        // Don't evict automatically to avoid destroying active textures
        EFFECT_CACHE[key] = texture
        console.debug("Cached effect texture for key: $key")
    }
    
    function clear_effects_cache() {
        for (key, texture) in EFFECT_CACHE
            if (texture != null) {
                (globalThis as any).JulGameSdl.glue_SDL_DestroyTexture(texture)
            }
        }
        empty(EFFECT_CACHE)
    }

    function get_effect_cache_snapshot() {
        let snapshot = NamedTuple[]
        for (key, texture) in EFFECT_CACHE
            let width = 0
            let height = 0
            if (texture != null) {
                let w = Ref{Cint}(0)
                let h = Ref{Cint}(0)
                let fmt = Ref{UInt32}(0)
                let access = Ref{Cint}(0)
                if ((globalThis as any).JulGameSdl.glue_SDL_QueryTexture(texture, fmt, access, w, h) == 0) {
                    width = Int(w[])
                    height = Int(h[])
                }
            }
            snapshot.push((
                key = key,
                texture = texture,
                width = width,
                height = height,
                let approxBytes = width * height * 4,
            ))
        }
        return snapshot
    }
    
    function update_effects(this: TextBox) {
        if (isempty(this.effects) || !this.needsEffectUpdate) {
            return
        }
        
        // Check if we have a cached version
        if (haskey(EFFECT_CACHE, this.effectCacheKey)) {
            console.debug("Using cached effect texture", name=this.name, key=this.effectCacheKey)
            // Don't destroy the old texture, just replace the reference
            this.effectTexture = EFFECT_CACHE[this.effectCacheKey]
            
            // Update size from cached texture
            if (this.effectTexture != null) {
                w = Ref{Cint}(0); h = Ref{Cint}(0)
                fmt = Ref{UInt32}(0); access = Ref{Cint}(0)
                (globalThis as any).JulGameSdl.glue_SDL_QueryTexture(this.effectTexture, fmt, access, w, h)
                this.size = {x: w[], y: h[]}
                console.debug("Cached effect texture size updated") name=this.name w=w[] h=h[]
            }
            
            this.needsEffectUpdate = false
            return
        }
        
        console.debug("Computing new effect texture", name=this.name, key=this.effectCacheKey, effects=serialize_effects(this.effects))
        
        // Check if renderer is available
        if ((globalThis as any).JulGame.Renderer == null) {
            console.debug("Renderer not available yet, deferring effects", name=this.name)
            return
        }
        
        // Check if font is available
        if (this.font == null) {
            console.debug("Font not available for effects", name=this.name)
            return
        }
        
        // Create a fresh base surface for effects processing (like the old system does)
        let baseSurface = CallSDLFunction(SDL2.TTF_RenderUTF8_Blended, this.font, this.text, (globalThis as any).JulGameSdl.glue_SDL_Color(TypeConversions.safe_int32_convert(this.color[0]), TypeConversions.safe_int32_convert(this.color[1]), TypeConversions.safe_int32_convert(this.color[2]), TypeConversions.safe_int32_convert(this.color[3])))
        if (baseSurface == null) {
            @error("Failed to create base surface for effects", name=this.name)
            return
        }
        try {
            let arr = unsafe_wrap(Array, baseSurface, 10; own=false)
            console.debug("Base surface created") name=this.name w=arr[0].w h=arr[0].h
        } catch (e) {
            console.debug("Failed to log base surface dims") err=e
        }
        
        // Create target for effects with original color
        let target = EffectsModule.SurfaceTarget(baseSurface, this.color)
        
        // Apply effects
        try {
            result = EffectRendererModule.apply_effects(target, this.effects)
            if (result isa EffectsModule.SurfaceTarget && result.surface != null) {
                // Verify renderer is still valid before creating texture
                if ((globalThis as any).JulGame.Renderer == null) {
                    @error("Renderer became null during effects processing for $(this.name)")
                    (globalThis as any).JulGameSdl.glue_SDL_FreeSurface(result.surface)
                    return
                }
                
                // Convert surface to texture
                // Don't destroy old texture - it might be cached and used by other TextBoxes
                
                // Use CallSDLFunction like the old system for better error handling
                this.effectTexture = CallSDLFunction(SDL2.SDL_CreateTextureFromSurface, (globalThis as any).JulGame.Renderer, result.surface)
                
                if (this.effectTexture != null) {
                    // Update size from the effect texture
                    w = Ref{Cint}(0); h = Ref{Cint}(0)
                    fmt = Ref{UInt32}(0); access = Ref{Cint}(0)
                    (globalThis as any).JulGameSdl.glue_SDL_QueryTexture(this.effectTexture, fmt, access, w, h)
                    this.size = {x: w[], y: h[]}
                    console.debug("Effect texture created") name=this.name tex_ptr=this.effectTexture w=w[] h=h[]
                    // Set scaling mode according to (globalThis as any).JulGame.SCALE_QUALITY
                    (globalThis as any).JulGameSdl.glue_SDL_SetTextureScaleMode(this.effectTexture, get_scale_mode_from_quality())
                    
                    // Cache the result
                    cache_effect_texture(this.effectCacheKey, this.effectTexture)
                    
                    this.needsEffectUpdate = false
                else
                    @error("Failed to create texture from effect surface", name=this.name)
                }
                
                // Clean up the result surface
                if (result.surface != baseSurface) {
                    (globalThis as any).JulGameSdl.glue_SDL_FreeSurface(result.surface)
                }
            else
                @error("Effects application returned invalid result", name=this.name)
            }
            
            // Clean up base surface if it wasn't consumed by effects
            if (baseSurface != null && (!isdefined(result, :surface) || result.surface != baseSurface)) {
                (globalThis as any).JulGameSdl.glue_SDL_FreeSurface(baseSurface)
            }
        } catch (e) {
            @error("Failed to apply effects", name=this.name, err=e)
            Base.show_backtrace(stderr, catch_backtrace())
            // Clean up on error
            if (baseSurface != null) {
                (globalThis as any).JulGameSdl.glue_SDL_FreeSurface(baseSurface)
            }
        }
    }
//= 
 =//

    // Add methods to set and get the maximum line width
    function set_max_line_width(this: TextBox,  maxWidth: number) {
        this.maxLineWidth = TypeConversions.safe_int32_convert(maxWidth)
        UI.rerender_text(this)
    }
    
    function get_max_line_width(this: TextBox) {
        return this.maxLineWidth
    }
    
    // Add method to control word wrapping behavior
    function set_wrap_words(this: TextBox,  wrapWords: boolean) {
        this.wrapWords = wrapWords
        UI.rerender_text(this)
    }
    
    function get_wrap_words(this: TextBox) {
        return this.wrapWords
    }
    
    /*
        handle_window_resize(this)

    Handles window resize events by recalculating the font size and reloading the font.
    This ensures text appears at the correct size after window resizing.

    // Arguments
    - `this`: The TextBox object to update
    */
    function UI_handle_window_resize(this: TextBox) {
        if (this.font != null) {
            // Close the current font
            console.debug("closing font from handle_window_resize")
            SDL2.TTF_CloseFont(this.font)
            this.font = null
            // Reload the font with the new scaled size
            UI.load_font(this, joinpath(this.fontPath))
            
            // Rerender the text
            UI.rerender_text(this)
        }
    }

    function UI_duplicate(this: TextBox,  id: string = (globalThis as any).JulGame.generate_uuid()) {
        let newTextBox = TextBox(this.text; 
        id=id, 
        let name = this.name, 
        let anchor = this.anchor.current_state,
        let anchorOffset = this.anchorOffset, 
        let isWorldEntity = this.isWorldEntity, 
        let layer = this.layer,
        let position = this.position, 
        let clickEvents = this.clickEvents,
        let hoverEnterEvents = this.hoverEnterEvents,
        let hoverExitEvents = this.hoverExitEvents,
        let isActive = this.isActive,
        let persistentBetweenScenes = this.persistentBetweenScenes,
        color=this.color, 
        fontPath=this.fontPath, 
        fontSize=this.fontSize, 
        let maxLineWidth = this.maxLineWidth, 
        wrapWords=this.wrapWords,
        let parent = this.parent
    )
        UI.initialize(newTextBox)
        MAIN.scene.uiElements.push(newTextBox)
        return newTextBox
    }
