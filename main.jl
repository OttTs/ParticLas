using GLMakie
using GLMakie.GLFW
using LinearAlgebra:norm, cross, dot
using PoissonRandom:pois_rand
using SpecialFunctions:erf

# Simulation parameters
const MAX_N_PARTICLES = 100000
const BOLTZMANN_CONST = 1.380649e-23

const N_THREADS = 6 # Number of simulation threads

# Particle parameters
const WEIGHTING = 2e16
const SPECIES_MASS = 4.652e-26

# Mesh parameters
const N_CELLS = (128, 90)
const MAX_N_LINES_PER_CELL = 100
const MAX_N_LINES = 10000

# Inflow parameters
const TEMPERATURE = 195e0

# General Parameters
const TIMESTEP = 1e-6
const REF_TEMP = 273.0
const REF_DIAMETER = 4.07e-10
const REF_OMEGA = 0.24
const REF_DYN_VISC = 30 * √(SPECIES_MASS * BOLTZMANN_CONST * REF_TEMP / π) /
    (4 * (5 - 2 * REF_OMEGA) * (7 - 2 * REF_OMEGA) * REF_DIAMETER^2)

include("simulation/geometry.jl")
include("simulation/parameters.jl")
include("simulation/mesh.jl")
include("simulation/computation_thread.jl")
include("simulation/movement.jl")
include("simulation/macroscopic_values.jl")
include("simulation/insertion.jl")

include("synchronization.jl")
include("gui.jl")
include("simulation/simulation.jl")

function main()
    # Setup GUI
    gui = GUI(MAX_N_PARTICLES, N_CELLS, MAX_N_LINES)
    screen, resolution = setup(gui)

    meshlength = resolution ./ resolution[2] # Set length to (1.xxx, 1.0)

    # Setup Simulation
    inflow = Inflow(gui.density[], gui.velocity[], TEMPERATURE, SPECIES_MASS)
    parameters = Parameters(
        WEIGHTING, SPECIES_MASS, TIMESTEP, REF_DYN_VISC,
        REF_TEMP, REF_OMEGA, inflow, GameState()
    )

    mesh = SimulationMesh(meshlength, N_CELLS, MAX_N_LINES_PER_CELL)
    threads = tuple([ComputationThread(MAX_N_PARTICLES, N_CELLS) for _ in 1:N_THREADS]...)

    # Setup syncs
    compsync = Synchronizer(N_THREADS)
    globsync = Synchronizer(N_THREADS + 1)

    # Start simulation threads
    for _ in 1:N_THREADS
        Threads.@spawn :interactive start_simulation_thread(
            threads, mesh, parameters, gui, compsync, globsync
        )
    end

    # Start renderloop
    renderloop(screen, gui, threads[1], mesh, globsync)

end

main()
