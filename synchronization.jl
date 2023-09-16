mutable struct Synchronizer
    barrier :: Threads.Condition
    counter :: Base.RefValue{Int8}
    const maxcount :: Int8
    Synchronizer(maxcount) = new(Threads.Condition(), Base.RefValue{Int8}(0), maxcount)
end

function synchronize(sync::Synchronizer)
    ID = 0
    lock(sync.barrier)
    try
        ID = sync.counter[] += 1
        if ID >= sync.maxcount
            sync.counter[] = 0
            notify(sync.barrier)
        else
            wait(sync.barrier)
        end
    finally
        unlock(sync.barrier)
    end
    return ID
end

#mutable struct Synchronizer
#    barrier :: Threads.Condition
#    counter :: Base.RefValue{Int8}
#    @atomic atomicc :: Int8
#    const maxcount :: Int8
#    Synchronizer(maxcount) = new(Threads.Condition(), Base.RefValue{Int8}(0), 0, maxcount)
#end
#
#function synchronize(sync::Synchronizer)
#    ID = 0
#    lock(sync.barrier)
#    try
#        ID = sync.counter[] += 1
#        if ID >= sync.maxcount
#            sync.counter[] = 0
#            notify(sync.barrier)
#        else
#            wait(sync.barrier)
#        end
#    finally
#        unlock(sync.barrier)
#    end
#    return ID
#end
#
#function synchronize(sync::Synchronizer, ID)
#    val = Int8(ID - 1)
#    while true
#        _, success = @atomicreplace sync.atomicc val => ID
#        success && break
#    end
#    if ID < sync.maxcount
#        while 0 < @atomic sync.atomicc
#            yield()
#            # busywait
#        end
#    else
#        @atomic sync.atomicc = 0
#    end
#end


#mutable struct Synchronizer
#    @atomic counter :: Int8
#    @atomic flip :: Bool
#    const maxcount :: Int8
#    Synchronizer(maxcount) = new(0, true, maxcount)
#    #Synchronizer(maxcount) = new(Threads.Condition(), Base.RefValue{Int8}(0), maxcount)
#end

#mutable struct Synchronizer
#    barrier :: Threads.Condition
#    counter :: Base.RefValue{Int8}
#    const maxcount :: Int8
#    Synchronizer(maxcount) = new(Threads.Condition(), Base.RefValue{Int8}(0), maxcount)
#end

#function synchronize(sync::Synchronizer)
#    ID = 0
#    lock(sync.barrier)
#    try
#        ID = sync.counter[] += 1
#        if ID >= sync.maxcount
#            sync.counter[] = 0
#            notify(sync.barrier)
#        else
#            wait(sync.barrier)
#        end
#    finally
#        unlock(sync.barrier)
#    end
#    return ID
#end

#function synchronize(sync::Synchronizer)
#    flip = @atomic sync.flip
#    ID = @atomic sync.counter += one(Int8)
#    if ID >= sync.maxcount
#        #println("ID=", ID, " sync is done!")
#        @atomic sync.flip = !flip
#        @atomic sync.counter = zero(Int8)
#    else
#        while flip == @atomic sync.flip;
#            #a = frametime(FPS)
#            #while frametime(FPS) - a < 0.1; end
#        end
#    end
#    return ID
#end

#function synchronize(sync::Synchronizer)
#    flip = @atomic sync.flip
#    ID = @atomic sync.counter += one(Int8)
#    if ID >= sync.maxcount
#        #println("ID=", ID, " sync is done!")
#        @atomic sync.flip = !flip
#        @atomic sync.counter = zero(Int8)
#    else
#        while flip == @atomic sync.flip
#        end
#    end
#    return ID
#end