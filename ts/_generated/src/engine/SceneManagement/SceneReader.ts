export {}
import { Camera } from "../Camera/Camera";
import { Transform } from "../Component/Transform";


    // using JSON3
    // using ...AnimatorModule
    // using ...AnimationModule
    // using ...CameraModule
    // using ...ColliderModule
    // using ...CircleColliderModule
    // using ...EntityModule
    // using ...Math
    // using ...RigidbodyModule
    // using ...ShapeModule
    // using ...SoundSourceModule
    // using ...SpriteModule
    // using ...UI.TextBoxModule
    // using ...UI.ScreenButtonModule
    // using ...UI.UIImageModule
    // using ...UI.CanvasModule
    // using ...TransformModule
    // using ...JulGame

    
    /*
        preload_scene(filePath: string)

    Preloads a scene from the specified file path and stores it in the PRELOADED_SCENES cache.
    This allows for faster scene switching as the scene is already loaded in memory.

    // Arguments
    - `filePath: string`: The path to the scene file to preload
    */
    function preload_scene(filePath: string) {
        try {
            if (haskey((globalThis as any).JulGame.PRELOADED_SCENES, basename(filePath))) {
                console.debug(`Scene already preloaded: ${basename(filePath)}`)
                return
            }

            let scene = deserialize_scene(filePath);
            (globalThis as any).JulGame.PRELOADED_SCENES[basename(filePath)] = [entities = scene[0], uiElements = scene[1], camera = scene[2]]
            console.debug(`Preloaded scene: ${basename(filePath)}`)
        } catch (e) {
            console.error(String(e))

        }
    }

    
    function deserialize_scene(filePath) {
        try {
            if (haskey((globalThis as any).JulGame.PRELOADED_SCENES, basename(filePath))) {
                console.debug(`deserialize_scene: Using preloaded scene: ${basename(filePath)}`)
                return (globalThis as any).JulGame.PRELOADED_SCENES[basename(filePath)]
            }

            let json = null
            if (haskey((globalThis as any).JulGame.SCENE_CACHE, basename(filePath))) {
                json = (globalThis as any).JulGame.SCENE_CACHE[basename(filePath)]
                console.debug("// using cached scene")
            } else { 
                let entitiesJson = read(filePath, String)
                json = JSON3.read(entitiesJson)
                console.debug("// using scene from scene file")
            }

            let entities = []
            let uiElements = []
            let res = []
            let childParentDict = Dict()
    
            let entityIdsInCurrentScene = []
            try {
                entityIdsInCurrentScene = [e.id for e in MAIN.scene.entities]
            } catch (e) {
                console.error(String(e))

            }
            for (const entity of json.Entities) {
                if (entity.id in entityIdsInCurrentScene) {
                    console.debug(`Entity with id ${entity.id} already exists in current scene`)
                    continue
                }
                let components = []
    
                for (const component of entity.components) {
                    console.debug(`Deserializing component: ${component.type}`)
                    components.push(deserialize_component(component))
                }
                
                if (haskey(entity, "parent") && entity.parent != "") {
                    childParentDict[String(entity.id)] = entity.parent
                }
                let newEntity = new Entity(get(entity, "name", "New entity"), String(entity.id))
                newEntity.isActive = get(entity, "isActive", true)
                newEntity.scripts = get(entity, "scripts", [])
                newEntity.persistentBetweenScenes = get(entity, "persistentBetweenScenes", false)

                for (const component of components) {
                    if (typeof(component) == Animator) {
                        console.debug(`Adding animator to entity: ${newEntity.name}, path: ${component.path}`)
                        try {
                            (globalThis as any).JulGame.add_animator(newEntity, component)
                        } catch (e) {
                            console.error(`Failed to add animator to entity: ${newEntity.name}, path: ${component.path}, error: ${e}`)

                        }
                        continue
                    } else if (typeof(component) == Collider) {
                        console.debug(`Adding collider to entity: ${newEntity.name}, path: ${component.path}`)
                        try {
                            (globalThis as any).JulGame.add_collider(newEntity, component)
                        } catch (e) {
                            console.error(`Failed to add collider to entity: ${newEntity.name}, path: ${component.path}, error: ${e}`)

                        }
                        continue
                    } else if (typeof(component) == CircleCollider) {
                        console.debug(`Adding circle collider to entity: ${newEntity.name}, path: ${component.path}`)
                        try {
                            (globalThis as any).JulGame.add_circle_collider(newEntity, component)
                        } catch (e) {
                            console.error(`Failed to add circle collider to entity: ${newEntity.name}, path: ${component.path}, error: ${e}`)

                        }
                        continue
                    } else if (typeof(component) == Rigidbody) {
                        console.debug(`Adding rigidbody to entity: ${newEntity.name}, path: ${component.path}`)
                        try {
                            (globalThis as any).JulGame.add_rigidbody(newEntity, component)
                        } catch (e) {
                            console.error(`Failed to add rigidbody to entity: ${newEntity.name}, path: ${component.path}, error: ${e}`)

                        }
                        continue
                    } else if (typeof(component) == Shape) {
                        console.debug(`Adding shape to entity: ${newEntity.name}, path: ${component.path}`);
                        (globalThis as any).JulGame.add_shape(newEntity, component)
                        continue
                    } else if (typeof(component) == SoundSource) {
                        console.debug(`Adding sound source to entity: ${newEntity.name}, path: ${component.path}`)
                        try {
                            (globalThis as any).JulGame.add_sound_source(newEntity, component)
                        } catch (e) {
                            console.error(`Failed to add sound source to entity: ${newEntity.name}, path: ${component.path}, error: ${e}`)

                        }
                        continue
                    } else if (typeof(component) == Sprite) {
                        console.debug(`Adding sprite to entity: ${newEntity.name}, path: ${component.path}`)
                        try {
                            (globalThis as any).JulGame.add_sprite(newEntity, false, component)
                        } catch (e) {
                            console.error(`Failed to add sprite to entity: ${newEntity.name}, path: ${component.path}, error: ${e}`)

                        }
                        continue
                    } else if (typeof(component) == Transform) {
                        console.debug(`Adding transform to entity: ${newEntity.name}, path: ${component.path}`)
                        try {
                            newEntity.transform = component: ITransform 
                            newEntity.transform.parent = newEntity
                        } catch (e) {
                            console.error(`Failed to add transform to entity: ${newEntity.name}, path: ${component.path}, error: ${e}`)

                        }
                        continue 
                    }
                }
                
                entities.push(newEntity)
            }

            for (const entity of entities) {
                if (haskey(childParentDict, String(entity.id))) {
                    let parentId = childParentDict[String(entity.id)]
                    for (const e of entities) {
                        if (String(e.id) == String(parentId)) {
                            entity.parent = e
                        }
                    }
                }
            }
            uiElements = deserialize_ui_elements(json.UIElements, entities)
            let camera = Camera({x: 500, y: 500}, {x: 0, y: 0, z: 0},{x: 0, y: 0}, null)
            if (haskey(json, "Camera")) {
                camera = Camera({x: json.Camera.size.x, y: json.Camera.size.y}, {x: json.Camera.position.x, y: json.Camera.position.y, z: 0.0}, {x: json.Camera.offset.x, y: json.Camera.offset.y}, null)
                camera.backgroundColor = [json.Camera.backgroundColor.r, json.Camera.backgroundColor.g, json.Camera.backgroundColor.b, json.Camera.backgroundColor.a]
                let zraw = get(json.Camera, "zoom", null)
                if (zraw !== null) {
                    camera.zoom = Number(zraw)
                }
            }
             
            res.push(entities)
            res.push(uiElements)
            res.push(camera)
            return res
        } catch (e) {
            console.error(String(e))

            return null
        }
    }

    function deserialize_ui_elements(jsonUIElements, entities) {
        let res = []
        let childParentDict = Dict()
        let default_Vector2 = {x: 0, y: 0}
        for (const uiElement of jsonUIElements) {
            try {
                let newUIElement = null
                if (haskey(uiElement, "parent") && uiElement.parent != "") {
                    childParentDict[String(uiElement.id)] = uiElement.parent
                }
                if (uiElement.type == "Canvas") {
                    // Parse color, default to white if not present or malformed
                    let color_tuple = [255, 255, 255, 100]
                    if (haskey(uiElement, "color") && typeof(uiElement.color) <: Dict && haskey(uiElement.color, "r") && haskey(uiElement.color, "g") && haskey(uiElement.color, "b") && haskey(uiElement.color, "a")) {
                         color_tuple = [uiElement.color.r, uiElement.color.g, uiElement.color.b, uiElement.color.a]
                    }

                    newUIElement = Canvas(
                        let id = String(get(uiElement, "id", (globalThis as any).JulGame.generate_uuid())),
                        let name = get(uiElement, "name", "Canvas"), 
                        let anchor = Symbol(get(uiElement, "anchor", "none")),
                        let anchorOffset = {x: get(uiElement, "anchorOffset", default_Vector2).x, y: get(uiElement, "anchorOffset", default_Vector2).y},
                        let isWorldEntity = get(uiElement, "isWorldEntity", false),
                        let layer = Int(get(uiElement, "layer", 0)),
                        let position = {x: get(uiElement, "position", default_Vector2).x, y: get(uiElement, "position", default_Vector2).y},
                        let size = {x: get(uiElement, "size", default_Vector2).x, y: get(uiElement, "size", default_Vector2).y},
                        let isActive = get(uiElement, "isActive", true),
                        let persistentBetweenScenes = get(uiElement, "persistentBetweenScenes", false),
                        let color = color_tuple,
                        let isVisible = get(uiElement, "isVisible", true),
                        let clipChildren = get(uiElement, "clipChildren", false),
                        let rotation = Number(get(uiElement, "rotation", 0.0))
                    )
                    
                    // Deserialize children if they exist
                    if (haskey(uiElement, "children") && uiElement.children.length > 0) {
                        let children = deserialize_canvas_children(uiElement.children, newUIElement)
                        for (const child of children) {
                            add_child(newUIElement, child)
                        }
                    }
                } else if (uiElement.type == "TextBox") {
                    // Parse color, default to white if not present or malformed
                    color_tuple = [255, 255, 255, 255]
                    if (haskey(uiElement, "color")) {
                        console.debug(`color of ${uiElement.name}: ${uiElement.color}`)
                        color_tuple = [uiElement.color.r, uiElement.color.g, uiElement.color.b, uiElement.color.a]
                    }

                    newUIElement = TextBox(
                        get(uiElement, "text", " ");
                        id = String(get(uiElement, "id", (globalThis as any).JulGame.generate_uuid())),
                        name = get(uiElement, "name", "TextBox"), 
                        anchor = Symbol(get(uiElement, "anchor", "none")),
                        anchorOffset = {x: get(uiElement, "anchorOffset", default_Vector2).x, y: get(uiElement, "anchorOffset", default_Vector2).y},
                        isWorldEntity = get(uiElement, "isWorldEntity", false),
                        layer = Int(get(uiElement, "layer", 0)),
                        position = {x: get(uiElement, "position", default_Vector2).x, y: get(uiElement, "position", default_Vector2).y}, 
                        isActive = get(uiElement, "isActive", true),
                        persistentBetweenScenes = get(uiElement, "persistentBetweenScenes", false),
                        color = color_tuple,
                        let fontPath = get(uiElement, "fontPath", "Default"), 
                        let fontSize = Int(get(uiElement, "fontSize", 20)), // Use fontSize from JSON or default
                        let maxLineWidth = Int(get(uiElement, "maxLineWidth", 0)),
                        let wrapWords = get(uiElement, "wrapWords", true)
                    )
                } else if (uiElement.type == "UIImage") {
                    color = get(uiElement, "color", Dict("4" => 255, "1" => 255, "2" => 255, "3" => 255))
                    color_tuple = (get(color, "1", 255), get(color, "2", 255), get(color, "3", 255), get(color, "4", 255))
                  
                    newUIElement = UIImage(
                        get(uiElement, "path", "Default");
                        id=String(get(uiElement, "id", (globalThis as any).JulGame.generate_uuid())),
                        name=get(uiElement, "name", "Image"),
                        anchor=Symbol(get(uiElement, "anchor", "none")),
                        anchorOffset={x: get(uiElement, "anchorOffset", default_Vector2).x, y: get(uiElement, "anchorOffset", default_Vector2).y},
                        layer=Int(get(uiElement, "layer", 0)),
                        position={x: get(uiElement, "position", default_Vector2).x, y: get(uiElement, "position", default_Vector2).y},
                        isActive=get(uiElement, "isActive", true),
                        persistentBetweenScenes=get(uiElement, "persistentBetweenScenes", false),
                        color=color_tuple,
                        size={x: get(uiElement, "size", default_Vector2).x, y: get(uiElement, "size", default_Vector2).y},
                        let parent = null,
                        rotation=Number(get(uiElement, "rotation", 0.0)),
                        // clickEvents=get(uiElement, "clickEvents", Function[]),
                        // hoverEnterEvents=get(uiElement, "hoverEnterEvents", Function[]),
                        // hoverExitEvents=get(uiElement, "hoverExitEvents", Function[]),
                    )
                } else if (uiElement.type == "Rectangle") {
                    color = get(uiElement, "color", Dict("4" => 255, "1" => 255, "2" => 255, "3" => 255))
                    color_tuple = (get(color, "1", 255), get(color, "2", 255), get(color, "3", 255), get(color, "4", 255))
                    let borderColor = get(uiElement, "borderColor", Dict("4" => 255, "1" => 255, "2" => 255, "3" => 255))
                    let borderColor_tuple = (get(borderColor, "1", 255), get(borderColor, "2", 255), get(borderColor, "3", 255), get(borderColor, "4", 255))
                    newUIElement = (globalThis as any).JulGame.UI.RectangleModule.Rectangle(;
                        id=String(get(uiElement, "id", (globalThis as any).JulGame.generate_uuid())),
                        name=get(uiElement, "name", "Rectangle"),
                        anchor=Symbol(get(uiElement, "anchor", "none")),
                        anchorOffset={x: get(uiElement, "anchorOffset", default_Vector2).x, y: get(uiElement, "anchorOffset", default_Vector2).y},
                        isWorldEntity=get(uiElement, "isWorldEntity", false),
                        layer=Int(get(uiElement, "layer", 0)),
                        position={x: get(uiElement, "position", default_Vector2).x, y: get(uiElement, "position", default_Vector2).y},
                        isActive=get(uiElement, "isActive", true),
                        persistentBetweenScenes=get(uiElement, "persistentBetweenScenes", false),
                        color=color_tuple,
                        let fillMode = get(uiElement, "fillMode", true),
                        let borderRadius = Int(get(uiElement, "borderRadius", 0)),
                        let borderWidth = Int(get(uiElement, "borderWidth", 0)),
                        borderColor=borderColor_tuple,
                        size={x: get(uiElement, "size", default_Vector2).x, y: get(uiElement, "size", default_Vector2).y},
                        parent=null,
                        let forceClickCheck = get(uiElement, "forceClickCheck", false),
                        // clickEvents=get(uiElement, "clickEvents", Function[]),
                        // hoverEnterEvents=get(uiElement, "hoverEnterEvents", Function[]),
                        // hoverExitEvents=get(uiElement, "hoverExitEvents", Function[]),
                    )
                } else {
                    // For text offset, check if it should be centered (if not specified or all zeros)
                    let textOffset = {x: uiElement.textOffset.x, y: uiElement.textOffset.y}
                    if (!haskey(uiElement, "textOffset") || (textOffset.x == 0 && textOffset.y == 0)) {
                        // Use (-1,-1) as a special value to indicate the text should be centered
                        textOffset = {x: -1, y: -1}
                    }
                    
                    newUIElement = ScreenButton(
                        null; // clickEvent - Assuming none from scene file directly
                        id=String(get(uiElement, "id", (globalThis as any).JulGame.generate_uuid())),
                        name=get(uiElement, "name", "Button"),
                        anchor=Symbol(get(uiElement, "anchor", "none")),
                        anchorOffset={x: get(uiElement, "anchorOffset", default_Vector2).x, y: get(uiElement, "anchorOffset", default_Vector2).y},
                        isWorldEntity=get(uiElement, "isWorldEntity", false),
                        layer=Int(get(uiElement, "layer", 0)),
                        position={x: get(uiElement, "position", default_Vector2).x, y: get(uiElement, "position", default_Vector2).y},
                        let buttonUpSpritePath = get(uiElement, "buttonUpSpritePath", "Default"),
                        let buttonDownSpritePath = get(uiElement, "buttonDownSpritePath", "Default"),
                        // hoverEnterEvent=null, // Default
                        // hoverExitEvent=null, // Default
                        isActive=get(uiElement, "isActive", true),
                        persistentBetweenScenes=get(uiElement, "persistentBetweenScenes", false), // Keep the value from JSON if it exists
                        //color=color_tuple,
                        fontPath=get(uiElement, "fontPath", null),
                        fontSize=Int(get(uiElement, "fontSize", 24)),
                        size={x: get(uiElement, "size", default_Vector2).x, y: get(uiElement, "size", default_Vector2).y},
                        let text = get(uiElement, "text", ""),
                        textOffset=textOffset,
                        // parent=null // Default
                    )
                    
                    // Make sure the button is initialized properly - Constructor likely handles this
                }
                newUIElement.persistentBetweenScenes = get(uiElement, "persistentBetweenScenes", false)
                res.push(newUIElement)
            } catch (e) {
                console.error(String(e))

            }
        }

        for (const uiElement of res) {
            if (haskey(childParentDict, String(uiElement.id)) && childParentDict[String(uiElement.id)] != "" && childParentDict[String(uiElement.id)] !== null) {
                parentId, parentType = split(childParentDict[String(uiElement.id)], "::")
                if (parentType == "Entity") {
                    for (const e of entities) {
                        if (String(e.id) == String(parentId)) {
                            uiElement.parent = e
                        }
                    }
                } else {
                    for (const e of res) {
                        if (String(e.id) == String(parentId)) {
                            uiElement.parent = e
                        }
                    }
                }
            }
        }

        return res
    }

    
    function deserialize_component(component) {
        try {
            if (component.type == "Transform") {
                let position = Vector3f(
                    component.position.x,
                    component.position.y,
                    haskey(component.position, "z") ? component.position.z : 0.0,
                )
                let scale = Vector3f(
                    component.scale.x,
                    component.scale.y,
                    haskey(component.scale, "z") ? component.scale.z : 1.0,
                )
                let newComponent = new Transform(position, scale)
            } else if (component.type == "Animator") {
                let newAnimations = []
                for (const animation of component.animations) {
                let newAnimationFrames = Vector{Vector4}()
                for (const animationFrame of animation.frames) {
                    newAnimationFrames.push({x: animationFrame.x, y: animationFrame.y, z: animationFrame.z, t: animationFrame.t})
                    }
                    newAnimations.push(JulGameAnimation(newAnimationFrames, animation.animatedFPS))
                }
                newComponent = Animator(newAnimations)
            } else if (component.type == "Collider") {
                isTrigger: boolean = !haskey(component, "isTrigger") ? false : component.isTrigger
                enabled: boolean = !haskey(component, "enabled") ? true : component.enabled
                isPlatformerCollider: boolean = !haskey(component, "isPlatformerCollider") ? false : component.isPlatformerCollider
                offset = !haskey(component, "offset") ? {x: 0, y: 0} : {x: component.offset.x, y: component.offset.y}
                newComponent = Collider(enabled: boolean, isPlatformerCollider, isTrigger, offset,  {x: component.size.x, y: component.size.y}, component.tag)
            } else if (component.type == "CircleCollider") {
                newComponent = CircleCollider(Number(component.diameter), component.enabled, component.isTrigger, {x: component.offset.x, y: component.offset.y}, component.tag)
            } else if (component.type == "Rigidbody") {
                let mass = !haskey(component, "mass") ? 1.0 : Number(component.mass)
                let useGravity = !haskey(component, "useGravity") ? true : component.useGravity
                newComponent = Rigidbody(mass, useGravity)
            } else if (component.type == "SoundSource") {
                newComponent = SoundSource(component.channel, component.isMusic, component.path, get(component, "playOnStart", false), component.volume)
            } else if (component.type == "Sprite") {
                let color = !haskey(component, "color") || isempty(component.color) ? (255,255,255,255) : (get(component.color, "x", 255), get(component.color, "y", 255), get(component.color, "z", 255), get(component.color, "t", 255))
                let crop = !haskey(component, "crop") || isempty(component.crop) ? {x: 0, y: 0, z: 0, t: 0} : {x: component.crop.x, y: component.crop.y, z: component.crop.z, t: component.crop.t}
                let layer = !haskey(component, "layer") ? 0 : component.layer
                let offset = !haskey(component, "offset") ? {x: 0, y: 0} : {x: component.offset.x, y: component.offset.y}
                position = !haskey(component, "position") ? {x: 0, y: 0} : {x: component.position.x, y: component.position.y}
                let rotation = !haskey(component, "rotation") ? 0.0 : Number(component.rotation)
                let pixelsPerUnit = !haskey(component, "pixelsPerUnit") ? -1 : component.pixelsPerUnit
                let center = !haskey(component, "center") ? {x: 0.5, y: 0.5} : {x: component.center.x, y: component.center.y}
                let anchor = !haskey(component, "anchor") ? "center" : Symbol(component.anchor)
                let isStatic = !haskey(component, "isStatic") ? false : component.isStatic
                newComponent = Sprite(color, crop: null | Vector4, component.isFlipped, component.imagePath, layer: number, offset, position, rotation: number, pixelsPerUnit: number, center, anchor: string, isStatic: boolean)
            } else if (component.type == "Shape") {
                color = !haskey(component, "color") || isempty(component.color) ? Vector3(255,255,255) : Vector3(component.color.x, component.color.y, component.color.z)
                layer = !haskey(component, "layer") ? 0 : component.layer
                let size = !haskey(component, "size") || isempty(component.size) ? {x: 1, y: 1} : {x: component.size.x, y: component.size.y}
                let isFilled = !haskey(component, "isFilled") ? true : component.isFilled
                let isWorldEntity = !haskey(component, "isWorldEntity") ? true : component.isWorldEntity
                offset = !haskey(component, "offset") ? {x: 0, y: 0} : {x: component.offset.x, y: component.offset.y}
                position = !haskey(component, "position") ? {x: 0, y: 0} : {x: component.position.x, y: component.position.y}
                let alpha = !haskey(component, "alpha") ? 255 : component.alpha
                newComponent = Shape(color, isFilled: boolean, isWorldEntity: boolean, layer: number, offset, position, size, alpha: number)
            } else if (component.type == "Mesh3D") {
                let vCamera = vec3d(component.vCamera.x, component.vCamera.y, component.vCamera.z, component.vCamera.w)
                let vLookDir = vec3d(component.vLookDir.x, component.vLookDir.y, component.vLookDir.z, component.vLookDir.w)
                newComponent = Mesh3D()
                newComponent.fNear = get(component, "fNear", 0.1)
                newComponent.fFar = get(component, "fFar", 1000.0)
                newComponent.fFov = get(component, "fFov", 90.0)
                newComponent.fYaw = get(component, "fYaw", 0.0)
                newComponent.fTheta = get(component, "fTheta", 0.0)
                newComponent.fAspectRatio = get(component, "fAspectRatio", 0.0)
                newComponent.vCamera = vCamera
                newComponent.vLookDir = vLookDir
            }
            
            return newComponent
        } catch (e) {
            console.error(String(e))

        }
    }

    /*
    deserialize_canvas_children(jsonChildren, parentCanvas)
    
    Recursively deserializes Canvas children.
    */
    function deserialize_canvas_children(jsonChildren, parentCanvas) {
        let children = []
        let default_Vector2 = {x: 0, y: 0}
        
        for (const child of jsonChildren) {
            try {
                let newChild = null
                if (child.type == "Canvas") {
                    // Parse color, default to white if not present or malformed
                    let color_tuple = [255, 255, 255, 100]
                    if (haskey(child, "color") && typeof(child.color) <: Dict && haskey(child.color, "r") && haskey(child.color, "g") && haskey(child.color, "b") && haskey(child.color, "a")) {
                         color_tuple = [child.color.r, child.color.g, child.color.b, child.color.a]
                    }

                    newChild = Canvas(
                        let id = String(get(child, "id", (globalThis as any).JulGame.generate_uuid())),
                        let name = get(child, "name", "Canvas"), 
                        let anchor = Symbol(get(child, "anchor", "none")),
                        let anchorOffset = {x: get(child, "anchorOffset", default_Vector2).x, y: get(child, "anchorOffset", default_Vector2).y},
                        let isWorldEntity = get(child, "isWorldEntity", false),
                        let layer = Int(get(child, "layer", 0)),
                        let position = {x: get(child, "position", default_Vector2).x, y: get(child, "position", default_Vector2).y},
                        let size = {x: get(child, "size", default_Vector2).x, y: get(child, "size", default_Vector2).y},
                        let isActive = get(child, "isActive", true),
                        let persistentBetweenScenes = get(child, "persistentBetweenScenes", false),
                        let color = color_tuple,
                        let isVisible = get(child, "isVisible", true),
                        let clipChildren = get(child, "clipChildren", false),
                        let rotation = Number(get(child, "rotation", 0.0)),
                        let parent = parentCanvas
                    )
                    
                    // Recursively deserialize children if they exist
                    if (haskey(child, "children") && child.children.length > 0) {
                        let grandChildren = deserialize_canvas_children(child.children, newChild)
                        for (const grandChild of grandChildren) {
                            add_child(newChild, grandChild)
                        }
                    }
                } else if (child.type == "ScreenButton") {
                    // For text offset, check if it should be centered (if not specified or all zeros)
                    let textOffset = {x: child.textOffset.x, y: child.textOffset.y}
                    if (!haskey(child, "textOffset") || (textOffset.x == 0 && textOffset.y == 0)) {
                        // Use (-1,-1) as a special value to indicate the text should be centered
                        textOffset = {x: -1, y: -1}
                    }
                    
                    newChild = ScreenButton(
                        null; // clickEvent - Assuming none from scene file directly
                        id=String(get(child, "id", (globalThis as any).JulGame.generate_uuid())),
                        name=get(child, "name", "Button"),
                        anchor=Symbol(get(child, "anchor", "none")),
                        anchorOffset={x: get(child, "anchorOffset", default_Vector2).x, y: get(child, "anchorOffset", default_Vector2).y},
                        isWorldEntity=get(child, "isWorldEntity", false),
                        layer=Int(get(child, "layer", 0)),
                        position={x: get(child, "position", default_Vector2).x, y: get(child, "position", default_Vector2).y},
                        let buttonUpSpritePath = get(child, "buttonUpSpritePath", "Default"),
                        let buttonDownSpritePath = get(child, "buttonDownSpritePath", "Default"),
                        isActive=get(child, "isActive", true),
                        persistentBetweenScenes=get(child, "persistentBetweenScenes", false),
                        let fontPath = get(child, "fontPath", null),
                        let fontSize = Int(get(child, "fontSize", 24)),
                        size={x: get(child, "size", default_Vector2).x, y: get(child, "size", default_Vector2).y},
                        let text = get(child, "text", ""),
                        textOffset=textOffset,
                        parent = parentCanvas
                    )
                } else {
                    // TextBox
                    // Parse color, default to white if not present or malformed
                    color_tuple = [255, 255, 255, 255]
                    if (haskey(child, "color") && typeof(child.color) <: Dict && haskey(child.color, "r") && haskey(child.color, "g") && haskey(child.color, "b") && haskey(child.color, "a")) {
                         color_tuple = [child.color.r, child.color.g, child.color.b, child.color.a]
                    }

                    newChild = TextBox(
                        get(child, "text", " ");
                        id = String(get(child, "id", (globalThis as any).JulGame.generate_uuid())),
                        name = get(child, "name", "TextBox"), 
                        anchor = Symbol(get(child, "anchor", "none")),
                        anchorOffset = {x: get(child, "anchorOffset", default_Vector2).x, y: get(child, "anchorOffset", default_Vector2).y},
                        isWorldEntity = get(child, "isWorldEntity", false),
                        layer = Int(get(child, "layer", 0)),
                        position = {x: get(child, "position", default_Vector2).x, y: get(child, "position", default_Vector2).y}, 
                        isActive = get(child, "isActive", true),
                        persistentBetweenScenes = get(child, "persistentBetweenScenes", false),
                        color = color_tuple,
                        fontPath = get(child, "fontPath", "Default"), 
                        fontSize = Int(get(child, "fontSize", 20)),
                        let maxLineWidth = Int(get(child, "maxLineWidth", 0)),
                        let wrapWords = get(child, "wrapWords", true),
                        parent = parentCanvas
                    )
                }
                
                if (newChild !== null) {
                    children.push(newChild)
                }
            } catch (e) {
                console.error(String(e))

            }
        }
        
        return children
    }
export { deserialize_canvas_children, deserialize_component, deserialize_scene, deserialize_ui_elements, preload_scene }
