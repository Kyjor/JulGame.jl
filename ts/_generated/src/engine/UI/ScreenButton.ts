export {}
import { clamp, haskey, joinpath, unsafe_string, unsafe_wrap } from "../../../../src/engine/core/juliaHelpers";


    // using ..UI.JulGame
    // using ..UI.(globalThis as any).JulGame.Math
    // import ..UI

    
    class ScreenButton extends UI.UIElement {
        currentTexture
        buttonDownSprite
        buttonDownSpritePath: string
        buttonDownTexture
        buttonUpSprite
        buttonUpSpritePath: string
        buttonUpTexture
        fontPath: string | null
        fontSize: number
        isInitialized: boolean
        text: string
        textOffset: Vector2
        textSize: Vector2
        textTexture
        textColor: [number, number, number, number]
        crop

        function ScreenButton(clickEvent: Function | null = null; 
            id: string=(globalThis as any).JulGame.generate_uuid(), 
            name: string="Button",
            anchor: string = "none",
            anchorOffset = {x: 0, y: 0}, 
            isWorldEntity: boolean=false, 
            layer: number=0,
            position = {x: 0, y: 0}, 
            buttonUpSpritePath: string="Default", 
            buttonDownSpritePath: string="Default", 
            hoverEnterEvent: Function | null = null,
            hoverExitEvent: Function | null = null,
            isActive: boolean=true,
            persistentBetweenScenes: boolean=false,
            color= [255, 255, 255, 255], 
            textColor= [255, 255, 255, 255],
            fontPath: string | null = null, 
            fontSize: number=24, 
            size={x: 0, y: 0}, 
            text: string="", 
            textOffset={x: 0, y: 0}, 
            parent: UIElement | null | IEntity | ISprite=null,
            rotation: number=0.0,
            crop: null | Vector4=null
        )
            
            
            this.buttonDownSpritePath = buttonDownSpritePath
            this.buttonUpSpritePath = buttonUpSpritePath
            this.buttonDownSprite = load_image_sdl(joinpath((globalThis as any).JulGame.BasePath, "assets", "images"), buttonDownSpritePath)
            this.buttonUpSprite = load_image_sdl(joinpath((globalThis as any).JulGame.BasePath, "assets", "images"), buttonUpSpritePath)
            // TODO: if buttonUp/DownSpritePath is not found, use a default sprite

            this.anchor = deepcopy(UI.anchor_types)
            this.isInitialized = false

            this.anchor.current_state = anchor
            this.anchorOffset = anchorOffset

            this.clickEvents = []
            this.hoverEnterEvents = []
            this.hoverExitEvents = []
            this.currentTexture = null
            this.fontSize = fontSize
            this.id = id
            this.size = size
            this.fontPath = fontPath
            this.name = name
            this.position = position
            this.text = text
            this.textOffset = textOffset
            this.textTexture = null
            this.textSize = {x: 0, y: 0}
            this.persistentBetweenScenes = persistentBetweenScenes
            this.isHovered = false
            this.isActive = isActive
            this.layer = layer
            this.color = color
            this.textColor = textColor
            this.isWorldEntity = isWorldEntity
            this.parent = parent
            this.rotation = rotation
            this.crop = crop
            if (clickEvent !== null) {
                this.clickEvents.push(clickEvent)
            }
            if (hoverEnterEvent !== null) {
                this.hoverEnterEvents.push(hoverEnterEvent)
            }
            if (hoverExitEvent !== null) {
                this.hoverExitEvents.push(hoverExitEvent)
            }

            // If the textOffset is at (0,0), we'll consider it as "should center text"
            // This ensures text is centered by default if no explicit offset is provided
            if (this.textOffset != null && this.textOffset.x === 0 && this.textOffset.y === 0 && this.text != "") {
                // Even though we don't have the text size yet, we'll mark it for centering
                // The actual centering will happen in UI.initialize
                this.textOffset = {x: -1, y: -1}  // Special value to indicate centering is needed
            }

        }
    }

    function UI_render(self: ScreenButton) {
        if (!self.isInitialized) {
            UI.initialize(self)
        }

        if (() {
            self.currentTexture == null || 
            self.currentTexture === null || 
            !self.isActive
        )
            return
        }

        if (self.currentTexture == self.buttonDownTexture && !self.isHovered) {
            self.currentTexture = self.buttonUpTexture
        }

        if (!self.isWorldEntity) {
            UI.align_to_anchor(self)
        }

         // Check and set color if necessary
         let colorRefs = [0, 0, 0]
         let alphaRef = 0;
         (globalThis as any).JulGameSdl.glue_SDL_GetTextureColorMod(self.currentTexture, ...colorRefs);
         (globalThis as any).JulGameSdl.glue_SDL_GetTextureAlphaMod(self.currentTexture, alphaRef)
         if (colorRefs[0] != self.color[0] || colorRefs[1] != self.color[1] || colorRefs[2] != self.color[2] || self.color[3] != alphaRef) {
             UI.set_color(self, r=self.color[0], g=self.color[1], b=self.color[2], a=self.color[3])
         }

        if (!((globalThis as any).JulGameSdl.glue_SDL_RenderCopyExF(
            (globalThis as any).JulGame.Renderer, 
            self.currentTexture, 
            null, 
            (globalThis as any).JulGameSdl.glue_SDL_FRect(self.position.x, self.position.y, self.size.x, self.size.y), 
            self.rotation, 
            null, 
            0))) {
            throw new Error(`error rendering image: ${unsafe_string((globalThis as any).JulGameSdl.glue_SDL_GetError())}`)
        }

        // Render the text if it exists
        if (self.textTexture != null && self.text != "") {
            center_text_on_button(self)
            // Position the text exactly in the center of the button
            let text_x = self.position.x + self.textOffset.x
            let text_y = self.position.y + self.textOffset.y
            
            // Ensure sizes and positions are precise
            let rect = (globalThis as any).JulGameSdl.glue_SDL_FRect(
                Number(text_x),
                Number(text_y),
                Number(self.textSize.x),
                Number(self.textSize.y)
            )
            
            if (!((globalThis as any).JulGameSdl.glue_SDL_RenderCopyF(
                (globalThis as any).JulGame.Renderer, 
                self.textTexture, 
                null, 
                rect
            ))) {
                throw new Error(`error rendering button text: ${unsafe_string((globalThis as any).JulGameSdl.glue_SDL_GetError())}`)
            }
        }
    }

    function UI_initialize(self: ScreenButton) {
        self.buttonDownTexture = CallSDLFunction((globalThis as any).JulGameSdl.glue_SDL_CreateTextureFromSurface, (globalThis as any).JulGame.Renderer, self.buttonDownSprite)
        self.buttonUpTexture = CallSDLFunction((globalThis as any).JulGameSdl.glue_SDL_CreateTextureFromSurface, (globalThis as any).JulGame.Renderer, self.buttonUpSprite)
        self.currentTexture = self.buttonUpTexture

        if (!self.isWorldEntity) {
            UI.align_to_anchor(self)
        }

        // Initialize text if a font path is provided and text is not empty
        if (self.fontPath != null && self.text != "") {
            // Load the font // using the cache
            let font = load_font_sdl(joinpath((globalThis as any).JulGame.BasePath, "assets", "fonts"), self.fontPath, self.fontSize)
            
            if (font != null) {
                // Render the text
                let textSurface = CallSDLFunction(SDL2.TTF_RenderUTF8_Blended, font, self.text, (globalThis as any).JulGameSdl.glue_SDL_Color(self.textColor[0], self.textColor[1], self.textColor[2], self.textColor[3]))
                
                if (textSurface != null) {
                    // Get the size of the rendered text
                    let surface = unsafe_wrap(Array, textSurface, 10, false)
                    let width = Number(surface[0].w)
                    let height = Number(surface[0].h)
                    self.textSize = {x: width, y: height}
                    
                    // Debug the exact text dimensions
                    //console.log("Text dimensions for '$(self.text)': $(width)x$(height)")
                    
                    // Create texture from surface
                    self.textTexture = CallSDLFunction((globalThis as any).JulGameSdl.glue_SDL_CreateTextureFromSurface, (globalThis as any).JulGame.Renderer, textSurface)
                    
                    // Always center the text by default
                    center_text_on_button(self);
                    
                    // Free the surface
                    (globalThis as any).JulGameSdl.glue_SDL_FreeSurface(textSurface)
                }
                
                // Close the font
                SDL2.TTF_CloseFont(font)
            }
        }

        self.isInitialized = true
    }

    /*
    center_text_on_button(button)
    
    Centers the text within the button.
    */
    function center_text_on_button(button: ScreenButton) {
        // Reset any previous offset settings
        if (button.textSize.x == 0 || button.textSize.y == 0) {
            // If text size isn't set yet, just use 0,0 offset
            button.textOffset = {x: 0, y: 0}
            return
        }
        
        // Calculate the position to center the text
        // Make sure we're // using exact calculations with floats
        let button_width = Number(button.size.x)
        let button_height = Number(button.size.y)
        let text_width = Number(button.textSize.x)
        let text_height = Number(button.textSize.y)
        
        // Calculate center position with floating-point precision
        let textX = (button_width - text_width) / 2
        let textY = (button_height - text_height) / 2
        
        // Debug information
        //console.log("Button: $(button.name), Size: $(button_width)x$(button_height), TextSize: $(text_width)x$(text_height)")
        //console.log("Calculated offsets - X: $textX, Y: $textY")
        
        // Update the text offset with precise floating-point coordinates
        button.textOffset = {x: textX, y: textY}
    }

    function UI_load_button_sprite_editor(self: ScreenButton, path: string, up: boolean) {
        let sprite = load_image_sdl(joinpath((globalThis as any).JulGame.BasePath, "assets", "images"), path)
        let texture = CallSDLFunction((globalThis as any).JulGameSdl.glue_SDL_CreateTextureFromSurface, (globalThis as any).JulGame.Renderer, sprite)
        if (up) {
            self.buttonUpSpritePath = path
            self.buttonUpSprite = sprite
            self.buttonUpTexture = texture
        } else {
            self.buttonDownSpritePath = path
            self.buttonDownSprite = sprite
            self.buttonDownTexture = texture
        }

        self.currentTexture = texture
    }

    function UI_set_color(self: ScreenButton, r: number=255, g: number=255, b: number=255, a: number=255) {
        //console.debug("setting color to $(r), $(g), $(b), $(a)")
        self.color = [r%256, g%256, b%256, a%256]
        if (self.buttonDownTexture != null) {
            //console.debug("setting color of button down texture to $(r), $(g), $(b), $(a)")
            (globalThis as any).JulGameSdl.glue_SDL_SetTextureColorMod(self.buttonDownTexture, Number(clamp(self.color[0], 0, 255)), Number(clamp(self.color[1], 0, 255)), Number(clamp(self.color[2], 0, 255)));
            (globalThis as any).JulGameSdl.glue_SDL_SetTextureAlphaMod(self.buttonDownTexture, Number(clamp(self.color[3], 0, 255)));
        }
        if (self.buttonUpTexture != null) {
            //console.debug("setting color of button up texture to $(r), $(g), $(b), $(a)")
            (globalThis as any).JulGameSdl.glue_SDL_SetTextureColorMod(self.buttonUpTexture, Number(clamp(self.color[0], 0, 255)), Number(clamp(self.color[1], 0, 255)), Number(clamp(self.color[2], 0, 255)));
            (globalThis as any).JulGameSdl.glue_SDL_SetTextureAlphaMod(self.buttonUpTexture, Number(clamp(self.color[3], 0, 255)));
        }
    }

    function UI_duplicate(self: ScreenButton, id: string = (globalThis as any).JulGame.generate_uuid()) {
        let newButton = ScreenButton(null; 
        id=id, 
        let name = self.name,
        let anchor = self.anchor.current_state,
        let anchorOffset = self.anchorOffset, 
        let isWorldEntity = self.isWorldEntity, 
        let layer = self.layer,
        let position = self.position, 
        let buttonUpSpritePath = self.buttonUpSpritePath, 
        let buttonDownSpritePath = self.buttonDownSpritePath, 
        let hoverEnterEvent = null,
        let hoverExitEvent = null,
        let isActive = self.isActive,
        let persistentBetweenScenes = self.persistentBetweenScenes,
        let color = self.color, 
        let textColor = self.textColor,
        let fontPath = self.fontPath, 
        let fontSize = self.fontSize, 
        let size = self.size, 
        let text = self.text, 
        let textOffset = self.textOffset, 
        let parent = self.parent,
        let rotation = self.rotation
    )

        newButton.clickEvents = self.clickEvents
        newButton.hoverEnterEvents = self.hoverEnterEvents
        newButton.hoverExitEvents = self.hoverExitEvents
        
        UI.initialize(newButton)
        (globalThis as any).MAIN.scene.uiElements.push(newButton)
        return newButton
    }

    function load_image_sdl(fullPath: string, imagePath: string) {
        if (haskey((globalThis as any).JulGame.IMAGE_CACHE, get_comma_separated_path(imagePath))) {
            let raw_data = (globalThis as any).JulGame.IMAGE_CACHE[get_comma_separated_path(imagePath)]
            let rw = (globalThis as any).JulGameSdl.glue_SDL_RWFromConstMem(pointer(raw_data), raw_data.length)
            if (rw != null) {
                console.debug(`loading image at ${imagePath} from cache`)
                console.debug("comma separated path: ", get_comma_separated_path(imagePath))
                return (globalThis as any).JulGameSdl.glue_IMG_Load_RW(rw, 1)
            }
        }
        console.debug(`Loading image from disk, there are ${(globalThis as any).JulGame.IMAGE_CACHE.length} images in cache`)

        return CallSDLFunction((globalThis as any).JulGameSdl.glue_IMG_Load, joinpath(fullPath, imagePath))
    }

    function get_comma_separated_path(path: string) {
        // Normalize the path to use forward slashes
        let normalized_path = path.replace(/\\/g, '/')
        
        // Split the path into components
        let parts = normalized_path.split('/')
        
        let result = join(parts[1:}], ",")
    
        return result  
    }

    function UI_add_click_event(self: ScreenButton, event) {
        self.clickEvents.push(event)
    }

    function UI_destroy(self: ScreenButton) {
        if (self.buttonDownTexture != null) {
            (globalThis as any).JulGameSdl.glue_SDL_DestroyTexture(self.buttonDownTexture)
        }
        if (self.buttonUpTexture != null) {
            (globalThis as any).JulGameSdl.glue_SDL_DestroyTexture(self.buttonUpTexture)
        }
        if (self.textTexture != null) {
            (globalThis as any).JulGameSdl.glue_SDL_DestroyTexture(self.textTexture)
        }
        self.buttonDownTexture = null
        self.buttonUpTexture = null
        self.textTexture = null
        self.currentTexture = null

        (globalThis as any).MAIN.scene.uiElements = filter(x => x !== self, (globalThis as any).MAIN.scene.uiElements)
    }

    /*
    UI.update_button_text(button, new_text: string)
    
    Updates the button's text and rerenders it.
    
    // Arguments
    - `button`: The button to update
    - `new_text: string`: The new text to display on the button
    
    // Examples
    ```julia
    UI.update_button_text(my_button, "New Text")
    ```
    */
    function UI_update_button_text(self: ScreenButton, new_text: string) {
        if (self.text == new_text) {
            return // No change needed
        }
        
        self.text = new_text
        
        // Clean up previous texture if it exists
        if (self.textTexture != null) {
            (globalThis as any).JulGameSdl.glue_SDL_DestroyTexture(self.textTexture)
            self.textTexture = null
        }
        
        // Skip rendering if text is empty or no font
        if (self.text == "" || self.fontPath == null) {
            return
        }
        
        // Load the font // using the cache
        let font = load_font_sdl(joinpath((globalThis as any).JulGame.BasePath, "assets", "fonts"), self.fontPath, self.fontSize)
        
        if (font != null) {
            // Render the text
            let textSurface = CallSDLFunction(SDL2.TTF_RenderUTF8_Blended, font, self.text, (globalThis as any).JulGameSdl.glue_SDL_Color(255, 255, 255, 255))
            
            if (textSurface != null) {
                // Get the size of the rendered text
                let surface = unsafe_wrap(Array, textSurface, 10, false)
                let width = Number(surface[0].w)
                let height = Number(surface[0].h)
                self.textSize = {x: width, y: height}
                
                // Debug the exact text dimensions
                //console.log("Text dimensions for '$(self.text)': $(width)x$(height)")
                
                // Create texture from surface
                self.textTexture = CallSDLFunction((globalThis as any).JulGameSdl.glue_SDL_CreateTextureFromSurface, (globalThis as any).JulGame.Renderer, textSurface)
                
                // Always center the text on the button
                center_text_on_button(self);
                
                // Free the surface
                (globalThis as any).JulGameSdl.glue_SDL_FreeSurface(textSurface)
            }
            
            // Close the font
            SDL2.TTF_CloseFont(font)
        }
    }

    /*
    load_font_sdl(basePath: string, fontPath: string, fontSize: number)
    
    Loads a font from the specified path, // using the font cache if available.
    
    // Arguments
    - `basePath: string`: The base path to load the font from
    - `fontPath: string`: The path to the font file
    - `fontSize: number`: The size of the font
    
    // Returns
    A pointer to the loaded font
    */
    function load_font_sdl(basePath: string, fontPath: string, fontSize: number) {
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
                console.debug("loading font from cache for button")
                console.debug("comma separated path: ", get_comma_separated_path(fontPath))
                return SDL2.TTF_OpenFontRW(rw, 1, fontSize)
            }
        }
        console.debug(`Loading font from disk for button, there are ${(globalThis as any).JulGame.FONT_CACHE.length} fonts in cache`)
        return CallSDLFunction(SDL2.TTF_OpenFont, joinpath(basePath, fontPath), fontSize)
    }
export { ScreenButton, UI_add_click_event, UI_destroy, UI_duplicate, UI_initialize, UI_load_button_sprite_editor, UI_render, UI_set_color, UI_update_button_text, center_text_on_button, get_comma_separated_path, load_font_sdl, load_image_sdl }
