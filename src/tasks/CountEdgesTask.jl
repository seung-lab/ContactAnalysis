"""
    CountEdgesTask

This module includes the composite type CountEdgesTask which includes both the
        generic DaemonTask.Info and an AbstractString as a payload
"""
module CountEdgesTask

using JSON
using PyCall
@pyimport neuroglancer.pipeline as pl

using ...SimpleTasks.Types
using ContactAnalysis.Precomputed.PrecomputedWrapper

import SimpleTasks.Tasks.DaemonTask
import SimpleTasks.Tasks.BasicTask
import SimpleTasks.Services.Datasource

export CountEdgesTaskDetails, NAME, execute

function str_to_slices(s)
    m=match(r"(\d+)-(\d+)_(\d+)-(\d+)_(\d+)-(\d+)",s)
    bounds = map(x->parse(Int,x), m.captures)
    return (bounds[1]:bounds[2], bounds[3]:bounds[4], bounds[5]:bounds[6])
end

function slices_to_str(s)
    t=map(slice_to_str,s)
    return "$(t[1])_$(t[2])_$(t[3])"
end

function slice_to_str(s)
    return "$(s.start)-$(s.stop)"
end

type CountEdgesTaskDetails <: DaemonTaskDetails
    segmentation_storage::AbstractString
    slices::AbstractString
    scale_idx::Int64
    output_storage::AbstractString
end

"""
Parse task from JSON
"""
function CountEdgesTaskDetails{String <: AbstractString}(d::Dict{String, Any})
    return CountEdgesTaskDetails(d["segmentation_storage"],
                                 d["slices"],
                                 d["scale_idx"],
                                 d["output_storage"])
end

const NAME = "CountEdgesTask"

function DaemonTask.prepare(task::CountEdgesTaskDetails)
end

function DaemonTask.execute(task::CountEdgesTaskDetails)

    if length(task.segmentation_storage) == ""
        return DaemonTask.Result(true, [])
    end

    segmentation_storage = task.segmentation_storage
    str_slices = task.slices
    slices = str_to_slices(str_slices)
    scale_idx = task.scale_idx
    output_storage = task.output_storage

    seg = PrecomputedWrapper(segmentation_storage, scale_idx)
    res = seg.val[:_scale]["resolution"]/1000 # convert nm to um
    weights = [] 
    for (i,r) in enumerate(res) # calculate surface areas of faces
        push!(weights, prod(res[filter(a->!(i in a), 1:length(res))]))
    end
    d = Main.count_edges(seg[slices...], weights)

    out = pl.Storage(output_storage)
    out[:put_file](file_path="$(str_slices)_edge_counts.json",
                        content="$(JSON.json(d))")
    out[:wait]()

    return DaemonTask.Result(true, [str_slices])
end

function DaemonTask.finalize(task::CountEdgesTaskDetails, 
                                    result::DaemonTask.Result)
end

end # module CountEdgesTask