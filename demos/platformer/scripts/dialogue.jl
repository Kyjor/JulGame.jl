include("../../../src/Macros.jl")
include("../../../src/SceneInstance.jl")
include("../../../src/Math/Vector2f.jl")

mutable struct Dialogue
    currentMessage::String
    currentPositionInMessage::Int64
    isReadingMessage::Bool
    messages::Array{String}
    parent
    timeBetweenCharacters::Float64
    timer::Float64


    function Dialogue(messages::Array{String}, timeBetweenCharacters::Float64)
        this = new()
        
        this.currentMessage = messages[1]
        this.currentPositionInMessage = 1
        this.isReadingMessage = true
        this.timeBetweenCharacters = timeBetweenCharacters
        this.timer = 0.0

        return this
    end
end

function Base.getproperty(this::Dialogue, s::Symbol)
    if s == :initialize
        function()
        end
    elseif s == :update
        function(deltaTime)
            this.timer = this.timer + deltaTime
            if !this.isReadingMessage || this.timer < this.timeBetweenCharacters
                return
            end
            #if at end, set isReadingMessage to false
            if this.currentPositionInMessage == length(this.currentMessage)
                this.isReadingMessage = false
                return
            end
            # add next character to text box 
            SceneInstance.textBoxes[1].updateText(string(SceneInstance.textBoxes[1].text == " " ? "" : SceneInstance.textBoxes[1].text, this.currentMessage[this.currentPositionInMessage]))
            # play a sound 
            SceneInstance.sounds[2].toggleSound()

            this.currentPositionInMessage = this.currentPositionInMessage + 1
            this.timer = 0.0
        end
    elseif s == :setParent
        function(parent)
            this.parent = parent
        end
    else
        try
            getfield(this, s)
        catch e
            println(e)
        end
    end
end