module ContactAnalysis

using SimpleTasks

export count_edges

include("count_edges.jl")

include("tasks/Precomputed.jl")
include("tasks/CountEdgesTask.jl")
include("tasks/awsscheduler.jl")

end # module
