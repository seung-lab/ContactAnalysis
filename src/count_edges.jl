"""
Count the number of voxels in border between segments

Args:
    * A: n-dimensional array (i.e. segmentation volume)
    * weights: list of weights assigned to faces (in ijk order)
        e.g. surface area of the faces, [yz, xz, xy]

Outputs:
    * edge_counts: dict of voxel face metric between neighboring segments
        keys are ordered tuple of segment IDs
        faces are only in cardinal directions
"""
function count_edges{T}(A::Array{T}, weights=[])

    if length(weights) > 0
        assert(length(weights) == length(size(A)))
    else
        weights = ones(length(size(A)))
    end

    function increment_dict!(d::Dict{}, k, w=1)
        if !(k in keys(d))
            d[k] = 0
        end
        d[k] += w
    end

    edge_counts = Dict()
    dirs = eye(Int, length(size(A)))
    cardinals = [CartesianIndex(dirs[i,:]...) for i in 1:size(dirs,1)]
    R = CartesianRange(size(A))
    if length(R) > 0
        Istart = first(R)
        for I in R
            x = A[I]
            for (J, w) in zip(cardinals, weights)
                K = max(I-J, Istart)
                if K != I
                    y = A[K]
                    if x != y
                        xy = (min(x,y), max(x,y))
                        increment_dict!(edge_counts, xy, w)
                    end
                end
            end
        end
    end
    return edge_counts
end