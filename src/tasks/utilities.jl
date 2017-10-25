using JSON

function get_precomputed()
    inlayer = "gs://neuroglancer/pinky40_v11/watershed_mst_trimmed_sem_remap"
    outlayer = "gs://neuroglancer/pinky40_v11/analysis/contact_dicts/"
    p = ContactAnalysis.Precomputed.PrecomputedWrapper(inlayer, 1)
    return inlayer, outlayer, p
end

function schedule_tasks(ranges, inlayer, outlayer)
    for r in ranges
        payload_info = ContactAnalysis.CountEdgesTask.CountEdgesPayloadInfo(inlayer, 
                ContactAnalysis.CountEdgesTask.slices_to_str([r...]), 1, outlayer)
        basic_info = SimpleTasks.Tasks.BasicTask.Info(0, "CountEdgesTask", inlayer, [""])
        ContactAnalysis.AWSScheduler.schedule_count_edges(basic_info, payload_info, queue_name="task-queue-pinky")
    end
end

function schedule_pinky40()
    inlayer, outlayer, p = get_precomputed()
    ranges = make_ranges(p)
    schedule_tasks(ranges, inlayer, outlayer)
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

"""
Given a precomputed PyCall object, chunk size, and overlap, give list of ranges
"""
function make_ranges(p, chunk_size=[256,256,64], overlap=[1,1,1])
    return map_chunks(p.val[:_scale]["size"], p.val[:_scale]["voxel_offset"], 
                                                        chunk_size, overlap)
end

"""
Pull all contact analysis files from gcloud
"""
function copy_results_locally()
    Base.run(`gsutil -m cp gs://neuroglancer/pinky40_v11/analysis/contact_dicts/* ~/data/contact_dicts/`)
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

function str_to_slice_start_stop(s)
    m=match(r"(\d+)-(\d+)_(\d+)-(\d+)_(\d+)-(\d+)",s)
    bounds = map(x->parse(Int,x), m.captures)
    return [bounds[1], bounds[3], bounds[5], bounds[2], bounds[4], bounds[6]]
end

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

function get_folder(name)
    return joinpath(homedir(), "data", name)
end

"""
Compute center on output of str_to_slice_start_stop
"""
 function get_center(s)
    ctr = round(Int, [(s[1]+s[4])/2, (s[2]+s[5])/2, (s[3]+s[6])/2])
end

"""
Horizontally concatenate center and bbox info to an edge list
"""
 function append_locations(fn, edge_list)
    s = str_to_slice_start_stop(fn)
    ctr = repmat(get_center(s), 1, size(edge_list,1))'
    bbox = repmat(s, 1, size(edge_list,1))'
    return hcat(edge_list[:,1:2], ctr, edge_list[:,3], bbox)
end

"""
Create contact edge list
"""
 function create_contact_edge_list(fn)
    d = JSON.parsefile(fn, dicttype=Dict{AbstractString,Float64}, use_mmap=true)
    contacts = Array{Any,2}(length(d), 3)
    segs = Set{Int64}()
    for (i, (k, v)) in enumerate(d)
        ki = (map(Int, map(parse, split(k[2:end-1], r",")))...)
        contacts[i,:] = [ki..., v]
        push!(segs, ki[1])
        push!(segs, ki[2])
    end
    return contacts, segs
end

"""
Convert contact dicts into contact edge list and list of segments for proximity
"""
function resave_contact_dict(inputs)
    i, n, dir, fn = inputs
    print("\r$i / $n")
    contacts, segs = create_contact_edge_list(joinpath(dir, fn))
    contacts = append_locations(fn, contacts)
    contacts_dst_fn = joinpath(get_folder("touches"), fn[1:end-17])
    segs_dst_fn = joinpath(get_folder("segs"), fn[1:end-17])
    writedlm(contacts_dst_fn, contacts, ',')
    writedlm(segs_dst_fn, segs, ',')
end

"""
Write out contact lists & sets of segments
"""
function dir_to_contact_lists()
    dir = get_folder("contact_dicts")
    files = readdir(dir)
    inputs = [(i, length(files), dir, fn) for (i,fn) in enumerate(files)]
    pmap(resave_contact_dict, inputs)
end

"""
From chunk with chunk_range, find range of neighbor in relative direction
"""
function get_neighbor(chunk_range, chunk_size, direction=[1,0,0])
    return (chunk_range[1] + chunk_size[1]*direction[1],
            chunk_range[2] + chunk_size[2]*direction[2],
            chunk_range[3] + chunk_size[3]*direction[3])
end

function get_start(chunk_range)
    return [chunk_range[1].start, chunk_range[2].start, chunk_range[3].start]
end

function get_end(chunk_range)
    return [chunk_range[1].stop, chunk_range[2].stop, chunk_range[3].stop]
end

"""
Given two grided coords, order them
"""
function order_coords(coord1, coord2)
    return reduce(|, coord1 .<= coord2) ? (coord1, coord2) : (coord2, coord1);
end

function write_proximities(inputs)
    i, n, directions, chunk, chunk_r = inputs
    print("\r$i / $n")
    segs_fn = joinpath(get_folder("segs"), slices_to_str(chunk_r))
    if isfile(segs_fn)
        chunk_start = get_start(chunk_r)
        chunk_stop = get_end(chunk_r)
        for d in directions
            neigh_r = get_neighbor(chunk_r, chunk, d)
            neigh_fn = joinpath(get_folder("segs"), slices_to_str(neigh_r))
            if isfile(neigh_fn)
                neigh_start = get_start(neigh_r)
                neigh_stop = get_end(neigh_r)
                cube_start, _ = order_coords(chunk_start, neigh_start)
                _, cube_stop = order_coords(chunk_stop, neigh_stop)
                ctr = get_center([cube_start..., cube_stop...])
                try
                    segs = readdlm(segs_fn, Int64)
                    combined_segs = vcat(segs, readdlm(neigh_fn, Int64))
                    unique_segs = sort(unique(segs))
                    if unique_segs[1] == 0
                        unique_segs = unique_segs[2:end]
                    end
                    n = length(unique_segs)
                    k = 1
                    proximity = Array{Any,2}(Int((n^2-n)/2), 9)
                    for (i, seg1) in enumerate(unique_segs[1:end-1])
                        for seg2 in unique_segs[i+1:end]
                            proximity[k,:] = [seg1, seg2,
                                        round(sum(chunk.*[8,8,40]/1000.*d),2),
                                        cube_start..., cube_stop...]
                            k += 1
                        end
                    end
                    cube_range = (cube_start[1]:cube_stop[1], 
                                    cube_start[2]:cube_stop[2], 
                                    cube_start[3]:cube_stop[3])
                    r_name = slices_to_str(cube_range)
                    proximity_fn = joinpath(get_folder("proximity"), r_name)
                    # proximity = append_locations(proximity_fn, proximity)
                    writedlm(proximity_fn, proximity, ',')
                catch e
                    println((e, chunk_start, neigh_start))
                end
            end
        end
    end
end

"""
Compile list of all segment pairs in nearest-neighbor chunks
"""
function compute_all_proximities(sz, origin, chunk=[256,256,64], overlap=[1,1,1])
    ranges = map_chunks(sz, origin, chunk, overlap)
    # directions = ([0,0,0])
    directions = ([ 1, 1, 1],
                  [ 1, 0, 1],
                  [ 0,-1, 1],
                  [ 0, 1, 1],
                  [ 0, 0, 1],
                  [ 0,-1, 1],
                  [-1, 1, 1],
                  [-1, 0, 1],
                  [-1,-1, 1],
                  [ 1, 1, 0],
                  [ 1, 0, 0],
                  [ 0, 1, 0],
                  [ 0, 0, 0])
    inputs = [(i, length(ranges), directions, chunk, chunk_r) 
                            for (i,chunk_r) in enumerate(ranges)]
    pmap(write_proximities, inputs)                                
end

"""
Add index in first column of the edge list
"""
function index_edges(edge_list)
    id = 1:size(edge_list,1)
    return hcat(id, edge_list)
end

"""
Combine directory of edge lists into one large edge list
"""
function compile_edge_lists(name="touches")
    dir = get_folder(name)
    files = readdir(dir)
    edge_list = append_locations(files[1], readdlm(joinpath(dir,files[1]), Any))
    for (i, fn) in enumerate(files[2:end])
        print("\r$i / $(length(files))")
        try
            next_edge_list = append_locations(fn, readdlm(joinpath(dir,fn), Any))
            edge_list = vcat(edge_list, next_edge_list)
        end
    end
    edge_fn = joinpath(homedir(), "data", string(name, ".csv"))
    writedlm(edge_fn, index_edges(edge_list), ',')
end

