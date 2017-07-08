"""
Copied from `cleanup_yacn` branch in neuroglancer:
https://github.com/seung-lab/neuroglancer/blob/cleanup_yacn/python/ext/third_party/yacn/chunked_regiongraph/tasks.jl
"""

module Precomputed

using PyCall
@pyimport neuroglancer.pipeline as pl
const pyslice=pybuiltin(:slice)

function cached(f)
	cache=Dict()
	function my_f(args...)
		if !haskey(cache, args)
			cache[args] = f(args...)
		else
			println("restoring from cache")
		end
		return cache[args]
	end
end

CachedStorage = cached(pl.Storage)

immutable PrecomputedWrapper
	val
	function PrecomputedWrapper(storage_string, scale_idx=0)
		return new(pl.Precomputed(CachedStorage(storage_string), scale_idx))
	end
end

function Base.getindex(x::PrecomputedWrapper, slicex::UnitRange, 
                                        slicey::UnitRange, slicez::UnitRange)
    return squeeze(get(x.val, 
            (pyslice(slicex.start,slicex.stop+1),
            pyslice(slicey.start,slicey.stop+1),
            pyslice(slicez.start,slicez.stop+1))),4)
end

end # module Precomputed