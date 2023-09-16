mutable struct Inflow
    flux :: Float64
    velocity :: Float64
    const most_probable_velocity :: Float64
end
function Inflow(density::Number, velocity::Number, temperature::Number, mass::Number)
    inflow = Inflow(0, 0, √(2 * BOLTZMANN_CONST * temperature / mass))
    set_condition!(inflow, density, velocity)
    return inflow
end


mutable struct GameState
    pause :: Bool
    reset :: Bool
    terminate :: Bool
    collisions :: Bool
    wallcoeff :: Float64
    GameState() = new(true, false, false, true, 0)
end


struct Parameters
    weighting :: Float64
    mass :: Float64
    timestep :: Float64
    reference_dynamic_viscosity :: Float64
    reference_temperature :: Float64
    omega :: Float64
    inflow :: Inflow
    state :: GameState
end


function set_condition!(inflow::Inflow, density::Number, velocity::Number)
    ratio = velocity / inflow.most_probable_velocity
    inflow.flux = 0.5 * (velocity * (erf(ratio) + 1) +
        inflow.most_probable_velocity / √π * exp(-(ratio)^2)) * density
    inflow.velocity = velocity
end

