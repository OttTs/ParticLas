"""
Needs: Mesh

Constructor:
    ComputationThread(maximum_particle_number) -> ComputationThread

Functions:
    reset!(thread::ComputationThread)
    isfull(thread::ComputationThread) -> true/false
    add_particle!(thread::ComputationThread, position, velocity, index)
    remove_particle!(thread::ComputationThread, index)
    copy!(dst::Particle, src::Particle)
    calculate_moments(thread::ComputationThread)
    correct_velocity(thread::ComputationThread, mesh::SimulationMesh)
"""

mutable struct Moment
    ∑v⁰ :: Int64
    ∑v¹ :: Point3{Float64}
    ∑v² :: Float64
end
Moment() = Moment(0, Point3{Float64}(0), 0)


mutable struct Particle
    position :: Point2{Float64}
    velocity :: Point3{Float64}
    index :: NTuple{2, Int64}
end
Particle() = Particle(Point2{Float64}(0), Point3{Float64}(0), (0,0))


struct ComputationThread
    n_particles :: Base.RefValue{Int64}
    particles :: Vector{Particle}
    moments :: Matrix{Moment}
end
ComputationThread(maximum_particle_number, n_cells) = ComputationThread(
    Base.RefValue(0),
    [Particle() for _ in 1:maximum_particle_number],
    [Moment() for i in 1:n_cells[1], j in 1:n_cells[2]]
)


function reset!(thread::ComputationThread)
    thread.n_particles[] = 0
end


isfull(thread::ComputationThread) = thread.n_particles[] >= length(thread.particles)


function add_particle!(thread::ComputationThread, position, velocity, index)
    isfull(thread) && return nothing

    thread.n_particles[] += 1
    particle = thread.particles[thread.n_particles[]]

    particle.position = position
    particle.velocity = velocity
    particle.index = index
end


function remove_particle!(thread::ComputationThread, index)
    index > thread.n_particles[] && return nothing

    copy!(thread.particles[index], thread.particles[thread.n_particles[]])
    thread.n_particles[] -= 1
end


function copy!(dst::Particle, src::Particle)
    dst.position = src.position
    dst.velocity = src.velocity
    dst.index = src.index
end

function calculate_moments(thread::ComputationThread)
    for moment in thread.moments
        moment.∑v⁰ = 0
        moment.∑v¹ = Point3{Float64}(0)
        moment.∑v² = 0
    end

    for i in 1:thread.n_particles[]
        particle = thread.particles[i]

        moment = thread.moments[particle.index...]
        moment.∑v⁰ += 1
        moment.∑v¹ += particle.velocity
        moment.∑v² += sum(particle.velocity[i]^2 for i in 1:3)
    end
end

function collide_particles(thread::ComputationThread, mesh::SimulationMesh)
    for i in 1:thread.n_particles[]
        particle = thread.particles[i]
        cell = mesh.cells[particle.index...]

        rand() > cell.collision_probability && continue

        # Sample velocity from Maxwellian
        particle.velocity = cell.velocity + √0.5 * cell.most_probable_velocity * randn(Point3{Float64})
    end
end

function correct_velocity(thread::ComputationThread, mesh::SimulationMesh)
    for i in 1:thread.n_particles[]
        particle = thread.particles[i]
        cell = mesh.cells[particle.index...]
        particle.velocity = cell.velocity + cell.ratio * (particle.velocity - cell.new_velocity)
    end
end