module ContactAnalysis

using SimpleTasks

export count_edges

include("count_edges.jl")

neuroglancer_in_path = false
for d in PyVector(pyimport("sys")["path"])
    neuroglancer_in_path |= contains(d, "neuroglancer")
end
if neuroglancer_in_path
    include("tasks/Precomputed.jl")
    include("tasks/CountEdgesTask.jl")
    include("tasks/awsscheduler.jl")
end

end # module
