export {}
import { joinpath, unsafe_string } from "../../../../src/engine/core/juliaHelpers";
import { vecAdd, vecSub, vecMul, vecDiv, vecNeg } from "../../../../src/engine/core/vectorOps";


    // using ..UI.JulGame
    // using ..UI.(globalThis as any).JulGame.Math
    // import ..UI
    // using (globalThis as any).JulGame.EffectsModule
    // using (globalThis as any).JulGame.EffectRendererModule
    // using (globalThis as any).JulGame.EffectCacheModule

    
    
    
    
    
    let DEFAULT_FONT = "Default"
    
    // Helper to map (globalThis as any).JulGame.SCALE_QUALITY ("0","1","2") to SDL scale mode
    function get_scale_mode_from_quality() {
        return (globalThis as any).JulGameSdl.glue_SDL_ScaleModeBest
        // TODO: Add text scaling option?
        let q = try
            String((globalThis as any).JulGame.SCALE_QUALITY)
        catch
            "2"
        }
        let val = try
            parse(Int, q)
        catch
            2
        }
        if (val == 0) {
            return (globalThis as any).JulGameSdl.glue_SDL_ScaleModeNearest
        } else if (val == 2) {
            return (globalThis as any).JulGameSdl.glue_SDL_ScaleModeBest
        } else {
            return (globalThis as any).JulGameSdl.glue_SDL_ScaleModeLinear
        }
    }
    class TextBox extends UI.UIElement {
        font: any | null
        fontPath: string
        fontSize: number
        isConstructed: boolean
        maxLineWidth: number
        renderText: any | null
        text: string
        textTexture: any | null
        wrapWords: boolean
        isDynamic: boolean
        //  effects support
        effects: any[]  // Will hold Effect objects
        effectTexture: any | null
        needsEffectUpdate: boolean
        effectCacheKey: string  // Content hash for caching

        function TextBox(text: string; 
            id: string=(globalThis as any).JulGame.generate_uuid(), 
            name: string = "TextBox", 
            anchor: string = "none",
            anchorOffset = {x: 0, y: 0}, 
            isWorldEntity: boolean=false, 
            layer: number=0,
            position = {x: 0, y: 0}, 
            clickEvents: Function[] = [],
            hoverEnterEvents: Function[] = [],
            hoverExitEvents: Function[] = [],
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
            setfield(this, "text", text)
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
            this.effects = []
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

    function UI_render(self: TextBox) {
        if (!self.isActive || (globalThis as any).JulGame.IS_CHANGING_SCENE) {
            return
        }
        
        // Only apply effects if they're pending and renderer is available
        // This should be rare after initial setup due to caching
        if (!isempty(self.effects) && self.needsEffectUpdate) {

        }
        
        // Use effect texture if available, otherwise use regular texture
        console.debug("Render select") name=self.name has_effects=!isempty(self.effects) effect_tex=self.effectTexture text_tex=self.textTexture needsUpdate=self.needsEffectUpdate
        
        // Force effect texture usage when effects exist
        if (!isempty(self.effects)) {
            if (self.effectTexture != null) {
                console.debug("Using effect texture") name=self.name

            } else {
                console.debug("Effects exist but no effect texture - forcing update") name=self.name
                self.needsEffectUpdate = true

                if (self.effectTexture != null) {
                    console.debug("Using effect texture after forced update") name=self.name

                } else {
                    console.debug("No effect texture available, // using regular texture") name=self.name
                    texture_to_render = self.textTexture
                }
            }
        } else if (self.textTexture != null) {
            console.debug("Using regular texture") name=self.name
            texture_to_render = self.textTexture
        } else {
            console.debug("No texture to render") name=self.name
            return  // No texture to render
        }
        console.debug("Rendering texture") name=self.name ptr=texture_to_render size= [self.size.x,self.size.y] position= [self.position.x,self.position.y]
        if (!self.isWorldEntity) {
            UI.align_to_anchor(self)
        }

        if ((globalThis as any).JulGame.IS_DEBUG) {
            let rgba = { r: 0, g: 0, b: 0, a: 255 }
            (globalThis as any).JulGameSdl.glue_SDL_GetRenderDrawColor((globalThis as any).JulGame.Renderer, rgba.r, rgba.g, rgba.b, rgba.a);
            (globalThis as any).JulGameSdl.glue_SDL_SetRenderDrawColor(0, 255, 0, 255);
            (globalThis as any).JulGameSdl.glue_SDL_RenderDrawLines((globalThis as any).JulGame.Renderer, [;
                (globalThis as any).JulGameSdl.glue_SDL_Point(self.position.x, self.position.y),;
                (globalThis as any).JulGameSdl.glue_SDL_Point(self.position.x + self.size.x, self.position.y),;
                (globalThis as any).JulGameSdl.glue_SDL_Point(self.position.x + self.size.x, self.position.y + self.size.y),;
                (globalThis as any).JulGameSdl.glue_SDL_Point(self.position.x, self.position.y + self.size.y),;
                (globalThis as any).JulGameSdl.glue_SDL_Point(self.position.x, self.position.y)], 5);
            (globalThis as any).JulGameSdl.glue_SDL_SetRenderDrawColor((globalThis as any).JulGame.Renderer, rgba.r, rgba.g, rgba.b, rgba.a);
        }

        let camera = MAIN.scene.camera;
        
        (globalThis as any).JulGameSdl.glue_SDL_SetTextureScaleMode(texture_to_render, get_scale_mode_from_quality())
        // Handle world coordinates for world entities, similar to Sprite component
        if (self.isWorldEntity && camera !== null) {
            let S = (globalThis as any).JulGame.pixels_per_world_unit(camera)
            let posX = vecMul(vecSub(self.position.x, vecAdd(camera.position.x, camera.offset.x)), S)
            let posY = vecMul(vecSub(self.position.y, vecAdd(camera.position.y, camera.offset.y)), S)
            @assert (globalThis as any).JulGameSdl.glue_SDL_RenderCopyF(
                (globalThis as any).JulGame.Renderer, 
                texture_to_render, 
                null, 
                (globalThis as any).JulGameSdl.glue_SDL_FRect(
                    Float32(posX), 
                    Float32(posY), 
                    Float32(self.size.x * camera.zoom), 
                    Float32(self.size.y * camera.zoom)
                )
            ) == 0 "error rendering textbox text: $(unsafe_string((globalThis as any).JulGameSdl.glue_SDL_GetError()))"
        } else {
            // Render with screen-space positioning (traditional UI)
            let adjusted_position = {x: 0, y: 0}
            if (self.originalSize != self.size && self.anchor.current_state == "none") {
                adjusted_position = {x: self.position.x - (self.size.x - self.originalSize.x)/2, y: self.position.y - (self.size.y - self.originalSize.y)/2}
                // console.debug("difference in size: $(self.size.x - self.originalSize.x), $(self.size.y - self.originalSize.y)")
                // console.debug("adjusted position: $(adjusted_position.x), $(adjusted_position.y)")
            } else {
                adjusted_position = self.position
            }
            @assert (globalThis as any).JulGameSdl.glue_SDL_RenderCopyF(
                (globalThis as any).JulGame.Renderer, 
                texture_to_render, 
                null, 
                (globalThis as any).JulGameSdl.glue_SDL_FRect(
                    Float32(adjusted_position.x), 
                    Float32(adjusted_position.y), 
                    Float32(self.size.x), 
                    Float32(self.size.y)
                )
            ) == 0 "error rendering textbox text: $(unsafe_string((globalThis as any).JulGameSdl.glue_SDL_GetError()))"
        }
    }

    function UI_load_font(self: TextBox, fontPath: string) {
        // Calculate the true font size based on window resolution
        //trueFontSize = get_true_font_size(self.fontSize)
        let trueFontSize = self.fontSize

        // If the font is already loaded, clean it up
        if (self.font != null) {
            console.debug("closing font")
            //console.log(self.font)
            SDL2.TTF_CloseFont(self.font)
            self.font = null
        }
        free_text_resources(self)

        
        self.font = load_font_sdl(fontPath, trueFontSize)
        if (self.font == null) {
            error("Failed to load font, $(unsafe_string((globalThis as any).JulGameSdl.glue_SDL_GetError())), loading default font")
            self.fontPath = DEFAULT_FONT
            self.font = CallSDLFunction(SDL2.TTF_OpenFontRW, (globalThis as any).JulGameSdl.glue_SDL_RWFromConstMem(pointer((globalThis as any).JulGame.BUILT_IN_ASSETS["Font"]), (globalThis as any).JulGame.BUILT_IN_ASSETS["Font"].length), 1, fontSize)
        }
        if (fontPath != "Default") {
            self.fontPath = fontPath
        }

        // prevents segfault when text is empty
        if (self.text == "") {
            self.text = " "
        }

        // Use high-quality font rendering with or without effects
        self.renderText = CallSDLFunction(SDL2.TTF_RenderUTF8_Blended, self.font, self.text, (globalThis as any).JulGameSdl.glue_SDL_Color(self.color[0], self.color[1], self.color[2], self.color[3]))
        if (self.renderText == null) {
            error("Failed to render text for textbox $(self.name)")
            return
        }
        let surface = unsafe_wrap(Array, self.renderText, 10; own = false)
        self.size = {x: surface[0].w, y: surface[0].h}
        self.originalSize = self.size
        self.textTexture = CallSDLFunction((globalThis as any).JulGameSdl.glue_SDL_CreateTextureFromSurface, (globalThis as any).JulGame.Renderer, self.renderText)

        if (!self.isWorldEntity) {
            UI.align_to_anchor(self)
        }
    }

    function UI_initialize(self: TextBox) {
        // Ensure font is properly scaled for the current window size
        UI.handle_window_resize(self)
        // Only center screen-space UI, not world entities
        if (!self.isWorldEntity) {
            UI.align_to_anchor(self)
        }
    }

    function UI_add_click_event(self: TextBox, event) {
        self.clickEvents.push(event)
    }

    function load_font_sdl(fontPath: string, fontSize: number) {
        if (haskey((globalThis as any).JulGame.FONT_CACHE, get_comma_separated_path(fontPath)) || fontPath == "Default" || fontPath == "") {
            if (fontPath == "Default" || fontPath == "") {
                let raw_data = (globalThis as any).JulGame.BUILT_IN_ASSETS["Font"]
                console.debug("loading default font")
            } else {
                raw_data = (globalThis as any).JulGame.FONT_CACHE[get_comma_separated_path(fontPath)]
                console.debug("loading font from cache")
            }
            let rw = (globalThis as any).JulGameSdl.glue_SDL_RWFromConstMem(pointer(raw_data), raw_data.length)
            if (rw != null) {
                console.debug("loading font from cache")
                console.debug("comma separated path: ", get_comma_separated_path(fontPath))
                return CallSDLFunction(SDL2.TTF_OpenFontRW, rw, 1, fontSize)
            }
        }
        console.debug(`Loading font from disk, there are ${(globalThis as any).JulGame.FONT_CACHE.length} fonts in cache`)
        
        let basePath = joinpath((globalThis as any).JulGame.BasePath, "assets", "fonts")
        return CallSDLFunction(SDL2.TTF_OpenFont, joinpath(basePath, fontPath), fontSize)
    }

    function get_comma_separated_path(path: string) {
        // Normalize the path to use forward slashes
        let normalized_path = path.replace(/\\/g, '/')
        
        // Split the path into components
        let parts = normalized_path.split('/')
        
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
    function UI_rerender_text(self: TextBox) {
        if ((globalThis as any).JulGame.IS_CHANGING_SCENE) {
            return
        }
        free_text_resources(self)

        if (self.text == "") {
            self.text = " "
        }

        // Check if we need to wrap text
        let color = (globalThis as any).JulGameSdl.glue_SDL_Color(self.color[0], self.color[1], self.color[2], self.color[3])
        self.renderText = if self.maxLineWidth > 0 && self.font != null && self.text != ""
            SDL2.TTF_RenderUTF8_Blended_Wrapped(self.font, self.wrapWords ? self.text : wrap_text(self.text, self.font, self.maxLineWidth, self.wrapWords), color, self.maxLineWidth)
        } else if (self.font != null && self.text != "") {
            self.renderText = SDL2.TTF_RenderUTF8_Blended(self.font, self.text, color)
        } else {
            null
        }
        if (this.renderText == null) {
            console.debug(`Failed to render text for textbox ${this.name}`)
            return
        }
        let surface = unsafe_wrap(Array, this.renderText, 10; own = false)
        this.size = {x: surface[0].w, y: surface[0].h}
        this.originalSize = {x: this.size.x, y: this.size.y}
        this.textTexture = (globalThis as any).JulGameSdl.glue_SDL_CreateTextureFromSurface((globalThis as any).JulGame.Renderer, this.renderText)

        if (!this.isWorldEntity) {
            UI.align_to_anchor(this)
        }
        
        // Update effects if needed
        if (!isempty(this.effects)) {

        }
    }

    function free_text_resources(self: TextBox) {
        if (self.renderText != null) {
            (globalThis as any).JulGameSdl.glue_SDL_FreeSurface(self.renderText)
            self.renderText = null
        }
        
        // DON'T destroy effect textures - they are managed by the cache
        // Just clear the reference
        if (self.effectTexture != null) {
            console.debug(`Clearing effect texture reference for ${self.name}`)
            self.effectTexture = null
        }
        
        // Handle regular text texture
        console.debug(`Destroying text texture for ${self.name}`);
        (globalThis as any).JulGameSdl.glue_SDL_DestroyTexture(self.textTexture)
        self.textTexture = null
    }

    // Helper function to manually wrap text at character boundaries
    function wrap_text(text: string, font, maxWidth: number, wrapWords: boolean) {
        if (maxWidth <= 0 || isempty(text)) {
            return text
        }

        let lines = []
        let current_line = ""
        let current_width = 0
        
        // If wrapping at word boundaries
        if (wrapWords) {
            let words = text.trim().split(/\s+/)
            for (const word of words) {
                w, h = Ref{Cint}(0), Ref{Cint}(0)
                let word_with_space = word * " "
                SDL2.TTF_SizeUTF8(font, word_with_space, w, h)
                
                if (current_width + w > maxWidth && !isempty(current_line)) {
                    lines.push(rstrip(current_line))
                    current_line = word * " "
                    current_width = w
                } else {
                    current_line *= word * " "
                    current_width += w
                }
            }
            
            if (!isempty(current_line)) {
                lines.push(rstrip(current_line))
            }
        } else {
            // Character by character wrapping
            for (const c of text) {
                let char_str = String(c)
                w, h = Ref{Cint}(0), Ref{Cint}(0)
                SDL2.TTF_SizeUTF8(font, char_str, w, h)
                
                if (current_width + w > maxWidth && !isempty(current_line)) {
                    lines.push(current_line)
                    current_line = char_str
                    current_width = w
                } else {
                    current_line *= char_str
                    current_width += w
                }
            }
            
            if (!isempty(current_line)) {
                lines.push(current_line)
            }
        }
        
        return lines.join("\n")
    }

    function UI_set_color(self: TextBox, r: number=255, g: number=255, b: number=255, a: number=255) {
        self.color = [r%256, g%256, b%256, a%256]
        // Invalidate effects cache when color changes
        if (!isempty(self.effects)) {
            self.needsEffectUpdate = true
        }
        UI.rerender_text(self)
    }
    
    function UI_update_font_size(self: TextBox, newSize: number, basePath: string = "") {
        let applied_size = max(1, newSize)
        if (self.fontSize == applied_size && self.font != null) {
            return
        }
        // Store the user-facing base size and force a fresh font/surface rebuild.
        self.fontSize = applied_size

        if (self.font != null) {
            SDL2.TTF_CloseFont(self.font)
            self.font = null
        }
        UI.load_font(self, self.fontPath)
        UI.rerender_text(self)
        if (!isempty(self.effects)) {
            UI.request_effects_refresh(self)
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
        let scale = Math.min(scaleX, scaleY)
        
        // Calculate and return the scaled font size
        return Math.round(baseFontSize * scale)
    }

    function UI_destroy(self: TextBox) {
        if (self.font != null) {
            SDL2.TTF_CloseFont(self.font)
            self.font = null
        }
        
        free_text_resources(self)

        MAIN.scene.uiElements = filter(x -> x !== self, MAIN.scene.uiElements)
    }
    
    // Generate a stable string for effects to use in cache keys
    function serialize_effects(effects: any[]): string
        if (isempty(effects)) {
            return "[]"
        }
        let parts = []
        for (const eff of effects) {
            let T = typeof(eff)
            let fnames = fieldnames(T)
            let vals = []
            for (const f of fnames) {
                // Avoid dumping huge pointers; just tag Ptr fields
                let v = getfield(eff, f)
                if (v isa Ptr) {
                    vals.push([f, "=Ptr"].join(""))
                } else {
                    vals.push([f, "=", v].join(""))
                }
            }
            parts.push([nameof(T), "(", vals.join(","), ")"].join(""))
        }
        return "[" * parts.join(";") * "]"
    }

    // Generate cache key for effects based on content
    function generate_effect_cache_key(self: TextBox): string
        // Include all factors that affect the final rendered result
        let content = [this.text, "|", this.color, "|", this.fontPath, "|", this.fontSize, "|", serialize_effects(this.effects), "|", this.size].join("")
        return String(hash(content))
    }
    
    //  effects API
    function UI_apply_effects(self: TextBox, effects: Vector) {
        self.effects = Any[effect for effect in effects]
        
        // Generate new cache key
        let newCacheKey = generate_effect_cache_key(self)
        console.debug("TextBox.apply_effects!: effects updated") name=self.name key=newCacheKey effects_count=self.effects.length
        
        // Only update if cache key changed
        if (self.effectCacheKey != newCacheKey) {
            self.effectCacheKey = newCacheKey
            self.needsEffectUpdate = true
        } else {
            console.debug("apply_effects!: cache key unchanged; skipping recompute") name=self.name
        }
        
        // Try to apply effects now, but don't fail if renderer isn't ready


    }

    /*
        request_effects_refresh(this)

    Recompute the effect texture after **in-place** edits to effect objects (e.g. inspector sliders).
    `apply_effects!` already bumps the cache key when the `effects` vector is replaced; mutating fields
    inside a `BevelEmbossEffect` does not, so callers that edit effects directly must call this.
    */
    function UI_request_effects_refresh(self: TextBox) {
        if (self.effects.length < 1) { return self }
        self.effectCacheKey = generate_effect_cache_key(self)
        self.needsEffectUpdate = true


    }
    
    function apply_style(self: TextBox, style) {
        return apply_effects(self, style.effects)
    }
    
    // Global effects cache
    const EFFECT_CACHE = Dict{String, Ptr{(globalThis as any).JulGameSdl.glue_SDL_Texture}}()
    const MAX_CACHE_SIZE = 100
    
    // Cache management functions
    function cache_effect_texture(key: string, texture: any) {
        // Simple approach: just store the texture, let GC handle cleanup
        // Don't evict automatically to avoid destroying active textures
        EFFECT_CACHE[key] = texture
        console.debug(`Cached effect texture for key: ${key}`)
    }
    
    function clear_effects_cache() {
        for (key, texture) in EFFECT_CACHE
            if (texture != null) {
                (globalThis as any).JulGameSdl.glue_SDL_DestroyTexture(texture)
            }
        }
        empty(EFFECT_CACHE)
    }

        return snapshot
    }

//= 
 =//

    // Add methods to set and get the maximum line width
    function set_max_line_width(self: TextBox, maxWidth: number) {
        self.maxLineWidth = maxWidth
        UI.rerender_text(self)
    }
    
    function get_max_line_width(self: TextBox) {
        return self.maxLineWidth
    }
    
    // Add method to control word wrapping behavior
    function set_wrap_words(self: TextBox, wrapWords: boolean) {
        self.wrapWords = wrapWords
        UI.rerender_text(self)
    }
    
    function get_wrap_words(self: TextBox) {
        return self.wrapWords
    }
    
    /*
        handle_window_resize(this)

    Handles window resize events by recalculating the font size and reloading the font.
    This ensures text appears at the correct size after window resizing.

    // Arguments
    - `this`: The TextBox object to update
    */
    function UI_handle_window_resize(self: TextBox) {
        if (self.font != null) {
            // Close the current font
            console.debug("closing font from handle_window_resize")
            SDL2.TTF_CloseFont(self.font)
            self.font = null
            // Reload the font with the new scaled size
            UI.load_font(self, joinpath(self.fontPath))
            
            // Rerender the text
            UI.rerender_text(self)
        }
    }

    function UI_duplicate(self: TextBox, id: string = (globalThis as any).JulGame.generate_uuid()) {
        let newTextBox = TextBox(self.text; 
        id=id, 
        let name = self.name, 
        let anchor = self.anchor.current_state,
        let anchorOffset = self.anchorOffset, 
        let isWorldEntity = self.isWorldEntity, 
        let layer = self.layer,
        let position = self.position, 
        let clickEvents = self.clickEvents,
        let hoverEnterEvents = self.hoverEnterEvents,
        let hoverExitEvents = self.hoverExitEvents,
        let isActive = self.isActive,
        let persistentBetweenScenes = self.persistentBetweenScenes,
        let color = self.color, 
        let fontPath = self.fontPath, 
        let fontSize = self.fontSize, 
        let maxLineWidth = self.maxLineWidth, 
        let wrapWords = self.wrapWords,
        let parent = self.parent
    )
        UI.initialize(newTextBox)
        MAIN.scene.uiElements.push(newTextBox)
        return newTextBox
    }
