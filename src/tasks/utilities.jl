using JSON

function schedule_tasks(ranges, inlayer, outlayer)
	for r in ranges
		payload_info = ContactAnalysis.CountEdgesTask.CountEdgesPayloadInfo(inlayer, 
                ContactAnalysis.CountEdgesTask.slices_to_str([r...]), 1, outlayer)
		basic_info = SimpleTasks.Tasks.BasicTask.Info(0, "CountEdgesTask", inlayer, [""])
		ContactAnalysis.AWSScheduler.schedule_count_edges(basic_info, payload_info, queue_name="task-queue-pinky")
	end
end

"""
Given a precomputed PyCall object, chunk size, and overlap, give list of ranges
"""
function make_ranges(p, chunk_size=[256,256,64], overlap=[1,1,1])
    return map_chunks(p.val[:_scale]["size"], p.val[:_scale]["voxel_offset"], 
                                                        chunk_size, overla)
end

function schedule_pinky40()
    inlayer = "gs://neuroglancer/pinky40_v11/watershed_mst_trimmed_sem_remap"
    outlayer = "gs://neuroglancer/pinky40_v11/analysis"
    p = ContactAnalysis.Precomputed.PrecomputedWrapper(inlayer, 1)
    ranges = make_ranges(p)
    schedule_tasks(ranges, inlayer, outlayer)
end

# function compile_results(ranges, outlayer)
#     out = pl.Storage(outlayer)
#     for r in ranges
#         str_slices = ContactAnalysis.CountEdgesTask.slices_to_str([r...])
#         try
#             f = out[:get_file](file_path="$(str_slices)_edge_counts.json")
#             d = JSON.parsefile(fn)
#         end
# end

function map_to_uint32_tuple_keys!(d)
    return map(x->map(Int, map(parse, split(x[2:end-1], r","))), d)
end

"""
Pull all contact analysis files from gcloud
"""
function copy_results_locally()
    Base.run(`gsutil -m cp gs://neuroglancer/pinky40_v11/analysis/* ~/data/`)
end

"""
For a directory of contact analysis json dicts, merge them all together
"""
function merge_json_dicts(dir)
    contacts = Dict{String,Float64}()
    for fn in readdir(dir)
        d = JSON.parsefile(joinpath(dir, fn), dicttype=Dict{String,Float64}, use_mmap=true)
        merge!(contacts, d)
    end
    int_contacts = Dict{Tuple{Int64,Int64},Float64}()
    for (k, v) in contacts
        ki = (map(Int, map(parse, split(k[2:end-1], r",")))...)
        int_contacts[ki] = v
    end
    return contacts
end

