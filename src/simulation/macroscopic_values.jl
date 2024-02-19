"""
Needs: SimulationMesh, ComputationThread, Parameters

Functions:
    calculate_macros(mesh, threads, parameters, ID)
    calculate_ratio(mesh, threads, parameters, ID)

    collision_probability(density, temperature, parameters)
"""


function calculate_macros(
    mesh::SimulationMesh,
    threads::NTuple{N_THREADS, ComputationThread},
    parameters::Parameters,
    ID::Number
    )
    densityweight = parameters.weighting * parameters.mass / prod(mesh.cellsize)
    temperatureweight = parameters.mass / (3 * BOLTZMANN_CONST)
    nx, ny = mesh.n_cells
    for i in ID:N_THREADS:nx, j in 1:ny
        ∑v⁰ = sum(threads[jID].moments[i,j].∑v⁰ for jID in 1:N_THREADS)
        ∑v¹ = sum(threads[jID].moments[i,j].∑v¹ for jID in 1:N_THREADS)

        cell = mesh.cells[i, j]
        cell.density = densityweight * ∑v⁰
        ∑v⁰ > 0 || (∑v⁰ = 1)

        ∑c² = sum(threads[jID].moments[i,j].∑v² for jID in 1:N_THREADS) - sum(∑v¹[k]^2 for k in 1:3) / ∑v⁰
        ∑c² < 0 && (∑c² = 0)

        cell.velocity = ∑v¹ / ∑v⁰
        ∑v⁰ > 1 || (∑v⁰ = 2)
        cell.temperature = temperatureweight * ∑c² / (∑v⁰ - 1)
        cell.collision_probability =
            collision_probability(cell.density, cell.temperature, parameters)
        cell.most_probable_velocity = √(2 * BOLTZMANN_CONST * cell.temperature / parameters.mass)
    end

end


function collision_probability(density, temperature, parameters)
    dynamic_viscosity = parameters.reference_dynamic_viscosity *
        (temperature / parameters.reference_temperature)^parameters.omega
    density == 0 && return 0
    relaxation_frequency = density * BOLTZMANN_CONST * temperature /
        (dynamic_viscosity * parameters.mass)
    return parameters.timestep * relaxation_frequency
end


function calculate_ratio(
    mesh::SimulationMesh,
    threads::NTuple{N_THREADS, ComputationThread},
    parameters::Parameters,
    ID::Number
    )
    temperatureweight = parameters.mass / (3 * BOLTZMANN_CONST)
    nx, ny = mesh.n_cells
    for i in ID:N_THREADS:nx, j in 1:ny
        ∑v⁰ = sum(threads[jID].moments[i,j].∑v⁰ for jID in 1:N_THREADS)
        ∑v¹ = sum(threads[jID].moments[i,j].∑v¹ for jID in 1:N_THREADS)

        cell = mesh.cells[i, j]

        ∑v⁰ > 0 || (∑v⁰ = 1)
        ∑c² = sum(threads[jID].moments[i,j].∑v² for jID in 1:N_THREADS) - sum(∑v¹[k]^2 for k in 1:3) / ∑v⁰
        ∑c² < 0 && (∑c² = 0)

        cell.new_velocity = ∑v¹ / ∑v⁰

        ∑v⁰ > 1 || (∑v⁰ = 2)
        temperature = temperatureweight * ∑c² / (∑v⁰ - 1)

        cell.ratio = temperature == 0 ? 0 : √(cell.temperature / temperature)
    end
end