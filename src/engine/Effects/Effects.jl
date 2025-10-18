module Effects
    include("effects_module.jl")
    using .EffectsModule
    export EffectsModule

    include("effect_algorithms.jl")
    using .EffectAlgorithmsModule
    export EffectAlgorithmsModule

    include("effect_renderer.jl")
    using .EffectRendererModule
    export EffectRendererModule

    include("effect_cache.jl")
    using .EffectCacheModule
    export EffectCacheModule

    include("effect_examples.jl")
    using .EffectExamplesModule
    export EffectExamplesModule
end
