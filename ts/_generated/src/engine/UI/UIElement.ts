export function UI_add_click_event(self: { clickEvents: Array<() => void> }, event: () => void) {
    self.clickEvents.push(event)
}


export function UI_set_color(self: {
        color: [number, number, number, number]
        name?: string
        parent: unknown
        anchor: { current_state: string }
        anchorOffset: { x: number; y: number }
        position: { x: number; y: number }
        size: { x: number; y: number }
        hoverEnterEvents: Array<() => void>
        hoverExitEvents: Array<() => void>
    }, r = 255, g = 255, b = 255, a = 255) {
    self.color = [r%256, g%256, b%256, a%256]
}

export function UI_align_to_anchor(self: {
        color: [number, number, number, number]
        name?: string
        parent: unknown
        anchor: { current_state: string }
        anchorOffset: { x: number; y: number }
        position: { x: number; y: number }
        size: { x: number; y: number }
        hoverEnterEvents: Array<() => void>
        hoverExitEvents: Array<() => void>
    }) {
    if ((globalThis as any).MAIN.scene.camera === null) {
        console.debug("No camera found in scene")
        return
    }

        let size = (globalThis as any).MAIN.scene.camera.size
    let parent_pos = {x: 0, y: 0}
    if (self.parent != null && typeof self.parent === "object") {
        const parent = self.parent as Record<string, any>
        // World sprites expose both size/position (world) and lastRenderedScreen* (screen).
        // Prefer screen rect — Julia branches on IUIElement vs ISprite the same way.
        const isUiElementParent =
            typeof parent.type === "string" &&
            (parent.type === "TextBox" ||
                parent.type === "UIImage" ||
                parent.type === "ScreenButton" ||
                parent.type === "Rectangle")
        if (
            !isUiElementParent &&
            parent.lastRenderedScreenSize != null &&
            parent.lastRenderedScreenPosition != null
        ) {
            size = parent.lastRenderedScreenSize
            parent_pos = parent.lastRenderedScreenPosition
        } else if (isUiElementParent && parent.size != null && parent.position != null) {
            size = parent.size
            parent_pos = parent.position
        } else if ("size" in parent && "position" in parent && parent.lastRenderedScreenPosition == null) {
            size = parent.size
            parent_pos = parent.position
        } else {
            console.debug(`No last rendered screen size or position found for parent of ${self.name}`)
            return
        }
    }

    if (self.anchor.current_state == "center") {
        self.position = {x: parent_pos.x + size.x/2 - self.size.x/2 + self.anchorOffset.x, y: parent_pos.y + size.y/2 - self.size.y/2 + self.anchorOffset.y}  
    } else if (self.anchor.current_state == "top") {
        self.position = {x: parent_pos.x + size.x/2 - self.size.x/2 + self.anchorOffset.x, y: parent_pos.y + self.anchorOffset.y}
    } else if (self.anchor.current_state == "bottom") {
        self.position = {x: parent_pos.x + size.x/2 - self.size.x/2 + self.anchorOffset.x, y: parent_pos.y + size.y - self.size.y + self.anchorOffset.y}
    } else if (self.anchor.current_state == "left") {
        self.position = {x: parent_pos.x + self.anchorOffset.x, y: parent_pos.y + size.y/2 - self.size.y/2 + self.anchorOffset.y}
    } else if (self.anchor.current_state == "right") {
        self.position = {x: parent_pos.x + size.x - self.size.x + self.anchorOffset.x, y: parent_pos.y + size.y/2 - self.size.y/2 + self.anchorOffset.y}
    } else if (self.anchor.current_state == "topLeft") {
        self.position = {x: parent_pos.x + self.anchorOffset.x, y: parent_pos.y + self.anchorOffset.y}
    } else if (self.anchor.current_state == "topRight") {
        self.position = {x: parent_pos.x + size.x - self.size.x + self.anchorOffset.x, y: parent_pos.y + self.anchorOffset.y}
    } else if (self.anchor.current_state == "bottomLeft") {
        self.position = {x: parent_pos.x + self.anchorOffset.x, y: parent_pos.y + size.y - self.size.y + self.anchorOffset.y}
    } else if (self.anchor.current_state == "bottomRight") {
        self.position = {x: parent_pos.x + size.x - self.size.x + self.anchorOffset.x, y: parent_pos.y + size.y - self.size.y + self.anchorOffset.y}
    } else if (self.anchor.current_state == "centerLeft") {
        self.position = {x: parent_pos.x + self.anchorOffset.x, y: parent_pos.y + size.y/2 - self.size.y/2 + self.anchorOffset.y}
    } else if (self.anchor.current_state == "centerRight") {
        self.position = {x: parent_pos.x + size.x - self.size.x + self.anchorOffset.x, y: parent_pos.y + size.y/2 - self.size.y/2 + self.anchorOffset.y}
    } else if (self.anchor.current_state == "centerTop") {
        self.position = {x: parent_pos.x + size.x/2 - self.size.x/2 + self.anchorOffset.x, y: parent_pos.y + self.anchorOffset.y}
    } else if (self.anchor.current_state == "centerBottom") {
        self.position = {x: parent_pos.x + size.x/2 - self.size.x/2 + self.anchorOffset.x, y: parent_pos.y + size.y - self.size.y + self.anchorOffset.y}
    } else if (self.anchor.current_state == "none") {
        //console.debug("No anchor set for textbox $(self.name)")
    } else {
        console.error(`Invalid anchor state: ${self.anchor.current_state}`)
    }
}

export function UI_add_hover_enter_event(self: {
        color: [number, number, number, number]
        name?: string
        parent: unknown
        anchor: { current_state: string }
        anchorOffset: { x: number; y: number }
        position: { x: number; y: number }
        size: { x: number; y: number }
        hoverEnterEvents: Array<() => void>
        hoverExitEvents: Array<() => void>
    }, event) {
    self.hoverEnterEvents.push(event)
}

export function UI_add_hover_exit_event(self: {
        color: [number, number, number, number]
        name?: string
        parent: unknown
        anchor: { current_state: string }
        anchorOffset: { x: number; y: number }
        position: { x: number; y: number }
        size: { x: number; y: number }
        hoverEnterEvents: Array<() => void>
        hoverExitEvents: Array<() => void>
    }, event) {
    self.hoverExitEvents.push(event)
}