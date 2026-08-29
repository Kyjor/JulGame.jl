# Ideally, we still have "hooks" to call into

```
# Configure - Set configurations like window size, rendering backend, etc. before the window is opened.
function jg_configure()
    ## INIT is applied after this. This will set the configuration. All config values will have default values.
    julgame.video.set_resolution(1280, 720)
    julgame.window.set_size(1920, 1080)
    julgame.scene.set("level_1") # load could be a scene file or a scene composition written in code

    ...
end 

# Start - Runs when a scene starts, scene_name will be passed through from julgame
function jg_start(scene_name::Ptr{UInt8}) 
    julgame.globals.set("PlayerName", "P1", "level_1")
    # (variable_name, value, scope (optional)) scope is the name of the scene in which this variable will stay alive. may need to do multiple.
end 

function jg_update()
    if julgame.input.is_button_pressed_this_frame("SPACE")


end

function jg_end()

end


function jg_shutdown()

end
```