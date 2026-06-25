# Functions meant for end users to call
function get_button_held_down(this::Input, button::String)
    if uppercase(button) in this.buttonsHeldDown
        return true
    end
    return false
end

function get_button_held_down(button::String)
    return get_button_held_down(MAIN.input, button)
end

function get_button_pressed(button::String)
    return get_button_pressed(MAIN.input, button)
end

function get_button_pressed(this::Input, button::String)
    if uppercase(button) in this.buttonsPressedDown
        return true
    end
    return false
end

function get_button_released(button::String)
    return get_button_released(MAIN.input, button)
end

function get_button_released(this::Input, button::String)
    if uppercase(button) in this.buttonsReleased
        return true
    end
    return false
end

function get_mouse_button(this::Input, button::Any)
    if button in this.mouseButtonsHeldDown
        return true
    end
    return false
end

function get_mouse_button(button::Any)
    return get_mouse_button(MAIN.input, button)
end

function get_mouse_button_pressed(this::Input, button::Any)
    if button in this.mouseButtonsPressedDown
        return true
    end
    return false
end

function get_mouse_button_pressed(button::Any)
    return get_mouse_button_pressed(MAIN.input, button)
end

function get_mouse_button_released(this::Input, button::Any)
    if button in this.mouseButtonsReleased
        return true
    end
    return false
end

function get_mouse_button_released(button::Any)
    return get_mouse_button_released(MAIN.input, button)
end

function get_mouse_position(this::Input)
    return this.mousePosition
end

function get_mouse_position()
    return get_mouse_position(MAIN.input)
end

function get_mouse_position_in_world_space(this::Input)
    return this.mousePositionWorld
end

function get_mouse_position_in_world_space()
    return get_mouse_position_in_world_space(MAIN.input)
end