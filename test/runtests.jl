using Index1024
using Test

import Base.==
function ==(i1::Index, i2::Index)
    i1.meta == i2.meta
end

function buff(size=3000)
    io = IOBuffer()
    write(io, [UInt8(1) for _ in 1:size])
    seek(io, 0)
    io
end

function rw_leafnode()
    io = buff()
    ni = Index1024.NodeInfo(Index1024.tag(Index1024.leaf, 0x01), Index1024.Leaf(1, 0))
    @assert write(io, ni) == 24
    seek(io, 0)
    ni == read(io, Index1024.NodeInfo)
end

function rw_empty_index()
    io = buff()
    idx = Index(io)
    @assert write(io, idx) == 1024
    seek(io,0)
    idx == read(io, Index)
end

function rw_index1p()
    io = buff()
    idx = Index(io)
    push!(idx.meta, "file1")
    push!(idx.meta, "file2")
    push!(idx.meta, "file3")
    @assert write(io, idx) == 1024
    seek(io,0)
    idx == read(io, Index)
end

function rw_index()
    io = buff()
    idx = Index(io)
    for i in 1:256
        push!(idx.meta, "file$i")
    end
    @assert write(io, idx) == 2048
    seek(io,0)
    idx == read(io, Index)
end

function nb(n=0)
    io = buff()
    if n > 0
        write(io, [1 for _ in 0:n])
    end
    Index1024.nextblock(io)
    position(io)
end

function egtree_entries(n=16)
    Dict([UInt64(k+mod(k,7))=>(data=UInt64(10k), aux=UInt64(1000*(1+mod(k,3)))) for k in 1:n])
end

function egtree(n=16)
    io = buff()
    entries = egtree_entries(n)
    build_index_file(io, entries)
    open_index(io)
end

function tsearch_exists(n)
    idx = egtree(n)
    search(idx, 0x13)
end

function tsearch_fails(n)
    idx = egtree(n)
    search(idx, 0)
end

function tget_exists(n)
    idx = egtree(n)
    get(idx, 0x13, 0)
end

function tget_fails(n)
    idx = egtree(n)
    get(idx, 0x0, 0)
end

function tmeta()
    io = buff()
    entries = egtree_entries()
    meta = String["one", "two", "three"]
    build_index_file(io, entries; meta)
    idx = open_index(io)
    search(idx, 0x13) == (data=0x82, aux=0x7d0)
    idx.meta == meta
end


@testset "Index1024.jl" begin
    @test nb(0) == 0
    @test nb(1) == 1024
    @test rw_leafnode()
    @test rw_empty_index()
    @test rw_index1p()
    @test rw_index()
    @test tsearch_exists(16) == (data=0x82, aux=0x7d0) 
    @test tsearch_exists(17) == (data=0x82, aux=0x7d0) 
    @test tsearch_exists(160) == (data=0x82, aux=0x7d0) 
    @test tsearch_fails(16) === nothing
    @test tsearch_fails(17) === nothing
    @test tsearch_fails(160) === nothing 
    @test tget_exists(16) == (data=0x82, aux=0x7d0) 
    @test tget_exists(17) == (data=0x82, aux=0x7d0) 
    @test tget_exists(170) == (data=0x82, aux=0x7d0) 
    @test tget_fails(16) == 0
    @test tget_fails(17) == 0 
    @test tget_fails(170) == 0 
    @test tmeta() 

end
