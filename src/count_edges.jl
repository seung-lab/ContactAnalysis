"""
Count the number of voxels in border between segments

Args:
    * A: n-dimensional array (i.e. segmentation volume)

Outputs:
    * edge_counts: dict of voxel counts between neighboring segments
        keys are ordered tuple of segment IDs
        counts are only in cardinal directions
"""
function count_edges{T}(A::Array{T})

    function increment_dict!(d::Dict{}, k)
        if !(k in keys(d))
            d[k] = 0
        end
        d[k] += 1
    end

    edge_counts = Dict()
    dirs = eye(Int, length(size(A)))
    cardinals = [CartesianIndex(dirs[i,:]...) for i in 1:size(dirs,1)]
    R = CartesianRange(size(A))
    if length(R) > 0
        Istart = first(R)
        for I in R
            x = A[I]
            for J in cardinals
                K = max(I-J, Istart)
                if K != I
                    y = A[K]
                    if x != y
                        xy = (min(x,y), max(x,y))
                        increment_dict!(edge_counts, xy)
                    end
                end
            end
        end
    end
    return edge_counts
end