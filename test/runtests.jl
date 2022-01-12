using Index1024
using Test

include("testfunctions.jl")

@testset "Index1024.jl" begin
    #@test nb(0) == 0
    #@test nb(1) == 16
    @test rw_leafnode()
    @test rw_empty_index()
    @test rw_index1p()
    @test rw_index()
    @test tsearch_exists(8) == ktup(8)
    @test tsearch_exists(8; padding=17) == ktup(8)
    @test tsearch_exists(16) == ktup(16)
    @test tsearch_exists(17) == ktup(17)
    @test tsearch_exists(160) == ktup(160)
    @test tsearch_exists(1_000_000) == ktup(1_000_000)
    @test tsearch_fails(16) === nothing
    @test tsearch_fails(17) === nothing
    @test tsearch_fails(160) === nothing 
    @test tget_exists(5) == ktup(5)
    @test tget_exists(16) == ktup(16)
    @test tget_exists(17) == ktup(17)
    @test tget_exists(170) == ktup(170)
    @test tget_fails(16) == 0
    @test tget_fails(17) == 0 
    @test tget_fails(170) == 0 
    @test tmeta(16) 
    @test sort(collect(keys(node_range(egtree(8), 0x8, 0xa)))) == [0x8, 0x9, 0xa]
    @test sort(collect(keys(node_range(egtree(1248), 0x8, 0xa)))) == [0x8, 0x9, 0xa]
    @test sort(collect(keys(node_range(egtree(164), 0x9f, 0xffff)))) == [0x9f, 0xa0, 0xa1, 0xa2, 0xa3, 0xa4, 0xa5, 0xa6, 0xa7]
end
