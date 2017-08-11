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
using ContactAnalysis
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

type CountEdgesPayloadInfo
    segmentation_storage::AbstractString
    slices::AbstractString
    scale_idx::Int64
    output_storage::AbstractString
end

function CountEdgesPayloadInfo(d::Dict{String, Any})
    return CountEdgesPayloadInfo(d["segmentation_storage"],
                                 d["slices"],
                                 d["scale_idx"],
                                 d["output_storage"])
end

type CountEdgesTaskDetails <: DaemonTaskDetails
    basic_info::BasicTask.Info
    payload_info::CountEdgesPayloadInfo
end

"""
Parse task from JSON
"""
function CountEdgesTaskDetails(basic_info::BasicTask.Info, d::Dict{String, Any})
    payload_info = CountEdgesPayloadInfo(d)
    return CountEdgesTaskDetails(basic_info, payload_info)
end

const NAME = "CountEdgesTask"

function DaemonTask.prepare(task::CountEdgesTaskDetails, 
                                datasource::DatasourceService)
    return true
end

function DaemonTask.execute(task::CountEdgesTaskDetails, 
                                datasource::DatasourceService)

    if length(task.payload_info.segmentation_storage) == ""
        return DaemonTask.Result(true, [])
    end


    segmentation_storage = task.payload_info.segmentation_storage
    str_slices = task.payload_info.slices
    slices = str_to_slices(str_slices)
    scale_idx = task.payload_info.scale_idx
    output_storage = task.payload_info.output_storage

    seg = PrecomputedWrapper(segmentation_storage, scale_idx)
    res = seg.val[:_scale]["resolution"]/1000 # convert nm to um
    weights = [] 
    for (i,r) in enumerate(res) # calculate surface areas of faces
        push!(weights, prod(res[filter(a->!(i in a), 1:length(res))]))
    end
    d = ContactAnalysis.count_edges(seg[slices...], weights)

    out = pl.Storage(output_storage)
    out[:put_file](file_path="$(str_slices)_edge_counts.json",
                        content="$(JSON.json(d))")
    out[:wait]()

    return DaemonTask.Result(true, [str_slices])
end

function DaemonTask.finalize(task::CountEdgesTaskDetails, 
                datasource::DatasourceService, result::DaemonTask.Result)
    return true
end

end # module CountEdgesTask