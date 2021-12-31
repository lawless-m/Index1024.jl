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

function rw_lrnode()
    io = buff()
    ni = Index1024.NodeInfo(Index1024.tag(Index1024.onpage, 0x0), Index1024.LR(1,2))
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
        0x10 => 0x1100,
        0x12 => 0x2120,
        0x13 => 0x1130,
        0x15 => 0x3150,
        0x17 => 0x1170,
        0x18 => 0x2180,
        0x20 => 0x3200,
        0x25 => 0x1250,
        0x29 => 0x2290,
        0x31 => 0x3310,
        0x36 => 0x3360,
        0x38 => 0x2380,
        0x40 => 0x1400,
        0x43 => 0x2430,
        0x46 => 0x2460,
        0x50 => 0x3500,
        0x54 => 0x1540,
        0x57 => 0x3570,
        0x59 => 0x1590
    )
end

function egtree()
    io = buff()
    entries = egtree_entries()
    build_index_file(io, entries)
    open_index(io)
end

function tsearch()
    idx = egtree()
    search(idx, 0x54) == (0x1540, 0) && search(idx, 0) === nothing
end

function tget()
    idx = egtree()
    get(idx, 0x54, 0) == (0x1540, 0) && get(idx, 0, "space") == "space"
end

function taux()
    io = buff()
    entries = egtree_entries()
    aux = Dict([k=>2entries[k] for k in collect(keys(entries))])
    build_index_file(io, entries; aux)
    idx = open_index(io)
    search(idx, 0x54) == (0x1540, UInt64(aux[0x54]))
end

function tmetaaux()
    io = buff()
    entries = egtree_entries()
    aux = Dict([k=>2entries[k] for k in collect(keys(entries))])
    meta = String["one", "two", "three"]
    build_index_file(io, entries; meta, aux)
    idx = open_index(io)
    search(idx, 0x54) == (0x1540, UInt64(aux[0x54]))
    idx.meta == meta
end


@testset "Index1024.jl" begin
    @test nb(0) == 0
    @test nb(1) == 1024
    @test rw_leafnode()
    @test rw_lrnode()
    @test rw_empty_index()
    @test rw_index1p()
    @test rw_index()
    @test tsearch()
    @test tget()
    @test taux()
    @test tmetaaux()
end
