# test without resolution
A = ones(Int, 8,8) 
edge_count = count_edges(A)
@test length(edge_count) == 0

A = [[ones(Int, 4,4) 2*ones(Int, 4,4)]; [3*ones(Int, 4,4) 4*ones(Int, 4,4)]]
edge_count = count_edges(A)
@test edge_count[(1,2)] == 4
@test edge_count[(1,3)] == 4
@test edge_count[(2,4)] == 4
@test edge_count[(3,4)] == 4

A = ones(Int, 8,8) 
A[2:7,2:7] = 2*ones(Int, 6,6)
A[3:6,3:6] = 3*ones(Int, 4,4)
A[4:5,4:5] = 4*ones(Int, 2,2)
edge_count = count_edges(A)
@test edge_count[(1,2)] == 24
@test edge_count[(2,3)] == 16
@test edge_count[(3,4)] == 8

A = ones(Int, 0,0)
edge_count = count_edges(A)
@test length(edge_count) == 0

A = ones(Int, 4,4,4) 
A[2:3,2:3,2:3] = 2*ones(Int, 2,2,2)
edge_count = count_edges(A)
@test edge_count[(1,2)] == 24

A = ones(Int, 4,4,4,4) 
A[2:3,2:3,2:3,2:3] = 2*ones(Int, 2,2,2,2)
edge_count = count_edges(A)
@test edge_count[(1,2)] == 64

# test with resolution
A = [[ones(Int, 4,4) 2*ones(Int, 4,4)]; [3*ones(Int, 4,4) 4*ones(Int, 4,4)]]
edge_count = count_edges(A, [1,2])
@test edge_count[(1,2)] == 4*2
@test edge_count[(1,3)] == 4*1
@test edge_count[(2,4)] == 4*1
@test edge_count[(3,4)] == 4*2

A = ones(Int, 4,4,4) 
A[2:3,2:3,2:3] = 2*ones(Int, 2,2,2)
edge_count = count_edges(A, [1,2,2])
@test edge_count[(1,2)] == 40

A = ones(Int, 4,4,4) 
A[2:3,2:3,2:3] = 2*ones(Int, 2,2,2)
@test_throws AssertionError count_edges(A, [2])