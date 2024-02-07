module UI
    using ..JulGame

    function add_click_event end
    function center_text end
    function destroy end
    function handle_event end
    function initialize end
    function render end
    function set_color end
    function set_parent end
    function set_position end
    function set_vector2_value end
    function update_text end


    include("ScreenButton.jl")
    include("TextBox.jl")
    
    export ScreenButtonModule
    export TextBoxModule
end
