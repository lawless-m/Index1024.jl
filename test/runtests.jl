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

function egtree_entries()
    Dict(
        0x10 => (data=0x100,aux=0x1000),
        0x12 => (data=0x120,aux=0x2000),
        0x13 => (data=0x130,aux=0x1000),
        0x15 => (data=0x150,aux=0x3000),
        0x17 => (data=0x170,aux=0x1000),
        0x18 => (data=0x180,aux=0x2000),
        0x20 => (data=0x200,aux=0x3000),
        0x25 => (data=0x250,aux=0x1000),
        0x29 => (data=0x290,aux=0x2000),
        0x31 => (data=0x310,aux=0x3000),
        0x36 => (data=0x360,aux=0x3000),
        0x38 => (data=0x380,aux=0x2000),
        0x40 => (data=0x400,aux=0x1000),
        0x43 => (data=0x430,aux=0x2000),
        0x46 => (data=0x460,aux=0x2000),
        0x50 => (data=0x500,aux=0x3000),
        0x54 => (data=0x540,aux=0x1000),
        0x57 => (data=0x570,aux=0x3000),
        0x59 => (data=0x590,aux=0x1000)
    )
end

function egtree(io=nothing)
    if io === nothing
        io = buff()
    end
    entries = egtree_entries()
    build_index_file(io, entries)
    open_index(io)
end

function tsearch()
    idx = egtree()
    search(idx, 0x54) == (data=0x540, aux=0x1000) && search(idx, 0) === nothing
end

function tget()
    idx = egtree()
    get(idx, 0x54, 0) == (data=0x540, aux=0x1000) && get(idx, 0, "space") == "space"
end

function tmeta()
    io = buff()
    entries = egtree_entries()
    meta = String["one", "two", "three"]
    build_index_file(io, entries; meta)
    idx = open_index(io)
    search(idx, 0x54) == 0x1540
    idx.meta == meta
end


@testset "Index1024.jl" begin
    @test nb(0) == 0
    @test nb(1) == 1024
    @test rw_leafnode()
    @test rw_empty_index()
    @test rw_index1p()
    @test rw_index()
    @test tsearch()
    @test tget()
    @test tmeta() 

end
