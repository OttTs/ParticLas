"""
Needs: ComputationThread, SimulationMesh, Parameters

Functions
    insert_particles(thread::ComputationThread, mesh::SimulationMesh, parameters::Parameters)
        sample_velocity(inflow::Inflow) -> Point3f
            samplezs(a::Number) -> Float64
"""

function insert_particles(thread::ComputationThread, mesh::SimulationMesh, parameters::Parameters)
    inflow = parameters.inflow
    # Calculate number of new particles
    inflow_length = mesh.length[2]
    flux = inflow.flux * inflow_length / (N_THREADS * parameters.mass * parameters.weighting)

    # Add new particles
    for _ in 1:pois_rand(flux * parameters.timestep)
        isfull(thread) && return nothing

        position = Point2{Float64}(0, rand() * inflow_length)
        velocity = sample_velocity(inflow)

        # Move the particle back for a fraction of a time step to avoid clumbing at the inflow
        position = position - rand() * parameters.timestep * Point2{Float64}(velocity)

        add_particle!(thread, position, velocity, index(position, mesh))
    end
end


function sample_velocity(inflow::Inflow)
    zs = samplezs(inflow.velocity / inflow.most_probable_velocity)
    vx = inflow.velocity - zs * inflow.most_probable_velocity
    vy = √0.5 * inflow.most_probable_velocity * randn()
    vz = √0.5 * inflow.most_probable_velocity * randn()
    return Point3{Float64}(vx, vy, vz)
end


function samplezs(a::Number)
    # Samples the random variable zs with a given speed ratio a
    # See "Garcia and Wagner - 2006 - Generation of the Maxwellian inflow distribution"
    if a < -0.4
        z = 0.5*(a - √(a^2+2))
        β = a - (1 - a) * (a - z)
        while true
            if exp(-β^2) / (exp(-β^2) + 2 * (a - z) * (a - β) * exp(-z^2)) > rand()
                zs = -√(β^2 - log(rand()))
                (zs - a) / zs > rand() && return zs
            else
                zs = β + (a - β) * rand()
                (a - zs) / (a - z) * exp(z^2 - zs^2) > rand() && return zs
            end
        end
    elseif a < 0
        while true
            zs = -√(a^2 - log(rand()))
            (zs - a) / zs > rand() && return zs
        end
    elseif a < 1.3
        while true
            u = rand()
            a * √π / (a * √π + 1 + a^2) > u && return -1/√2 * abs(randn())
            (a * √π + 1) / (a * √π + 1 + a^2) > u && return -√(-log(rand()))
            zs = (1 - √rand()) * a
            exp(-zs^2) > rand() && return zs
        end
    else # a > 1.3
        while true
            if 1 / (2 * a * √π + 1) > rand()
                zs = -√(-log(rand()))
            else
                zs = 1 / √2 * randn()
            end
            (a - zs) / a > rand() && return zs
        end
    end
end
