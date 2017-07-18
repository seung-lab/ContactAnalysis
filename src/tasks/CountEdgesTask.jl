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

function map_chunks(sz, o, chunk, overlap)
    """
    Create ranges for 3D chunks

    Args:
        sz: dataset size (collection of 3 ints)
        o: origin voxel (collection of 3 ints)
        chunk: size of the chunk (collection of 3 ints)
        overlap: number of voxels in positive overlap (collection of 3 ints)

    Returns:
        list of ranges describing chunks in larger volume
    """
    # pre = PrecomputedWrapper(segmentation_storage, scale_idx)
    # sz = pre.val[:_scale]["size"]
    # o = pre.val[:_scale]["voxel_offset"]
    ranges = []
    for x_start in o[1]:max(chunk[1],1):o[1]+sz[1]-1
        x_end = min(x_start+chunk[1]+overlap[1]-1, o[1]+sz[1]-1)
        for y_start in o[2]:max(chunk[2],1):o[2]+sz[2]-1
            y_end = min(y_start+chunk[2]+overlap[2]-1, o[2]+sz[2]-1)
            for z_start in o[3]:max(chunk[3],1):o[3]+sz[3]-1
                z_end = min(z_start+chunk[3]+overlap[3]-1, o[3]+sz[3]-1)
                r = x_start:x_end, y_start:y_end, z_start:z_end
                push!(ranges, r)
            end
        end
    end
    return ranges
end

function DaemonTask.finalize(task::CountEdgesTaskDetails, 
                datasource::DatasourceService, result::DaemonTask.Result)
    return true
end

end # module CountEdgesTask