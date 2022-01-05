module Index1024

import Base.read, Base.write

using Printf

export Index, search, build_index_file, open_index, get

const mask = 0xf000000000000000
const shift = 60
const onpage = 0x1
const topage = 0x2
const leaf = 0x3
const empty = 0xf
const ff = ~UInt64(0) >> 4

const pages_per_block = 31

const version = UInt16(2)

const DataAux = typeof((data=zero(UInt64), aux=zero(UInt64)))

struct Index
    meta::Vector{String}
    io::IO
    Index(meta, io) = new(meta, io)
    Index(io::IO) = Index(Vector{String}(), io)
end

function write(io::IO, index::Index)
    write(io, version) # version
    write(io, UInt32(length(index.meta)))
    foreach(f->println(io, f), index.meta)
    nextblock(io)
    position(io)
end

function read(io::IO, ::Type{Index})
    @assert read(io, UInt16) == version
    n = read(io, UInt32)
    index = Index(io)
    while n > 0
        push!(index.meta, readline(io))
        n -= 1
    end
    nextblock(io)
    index
end

abstract type Node end

struct Leaf <: Node
    data::UInt64
    aux::UInt64
end

struct Empty <: Node end

struct NodeInfo
    tagged_key::UInt64 # threshold or leaf value - determined by tag
    value::Node
    NodeInfo(key, value) = new(key, value)
end

struct LR <: Node
    left::NodeInfo
    right::NodeInfo
end

tag(t, v) = UInt64(v) | (UInt64(t) << shift)
tag(n::NodeInfo) = tag(n.tagged_key)
tag(v::UInt) = UInt16((UInt64(v) & mask) >> shift)
key(n::NodeInfo) = key(n.tagged_key)
key(v::UInt) = UInt64(v) & ~mask

function build_page(ks, kvs, leaf_tag)
    next2pow::Int = Int(1 << (64 - (leading_zeros(length(ks)-1))+1))
    nodes = Vector{NodeInfo}(undef, next2pow-1)
    kstep = 1
    k = 1
    for pk in (next2pow>>1):(next2pow-1) # e.g. 0x10:0x1f
        if k > length(ks)
            nodes[pk] = NodeInfo(tag(empty, ff), Empty())
        else
            nodes[pk] = NodeInfo(tag(leaf_tag, ks[k]), Leaf(kvs[ks[k]].data, kvs[ks[k]].aux))
        end
        k += kstep
    end

    k = 1
    while next2pow > 2
        next2pow >>= 1
        kstep *= 2
        k = kstep >> 1
        for pk in (next2pow>>1):(next2pow-1)
            if k > length(ks)
                nodes[pk] = NodeInfo(tag(onpage, ff), LR(nodes[2pk], nodes[2pk+1]))
            else
                nodes[pk] = NodeInfo(tag(onpage, ks[k]), LR(nodes[2pk], nodes[2pk+1]))
            end
            k += kstep
        end
    end

    nodes[1]
end
"""
    search(idx::Index, search_key::UInt64)::Union{UInt64, Nothing}
Search the given index for a given search_key returning a Tuple of the previously stored value
If the search_key is not found, return nothing
"""
search(idx::Index, search_key) = get_node(idx.io, UInt64(search_key))

import Base.get
"""
    get(idx::Index, search_key, default)
Search the given index for a given search_key returning a Tuple of the previously stored value
If the search_key is not found, return the supplied default
"""
function get(idx::Index, search_key, default)
    tpl = get_node(idx.io, UInt64(search_key))
    if tpl === nothing
        return default
    end
    return tpl
end

rewind(idx::Index) = rewind(idx.io)
rewind(io::IO) = begin reset(io); mark(io); end

function get_node(io::IO, search_key)
    rewind(io)
    node = read(io, NodeInfo)
    while tag(node) == onpage
        node = search_key <= key(node) ? node.value.left : node.value.right
        if tag(node) == topage
            seek(io, node.value.data)
            node = read(io, NodeInfo)
        end
    end
    if tag(node) == leaf && key(node) == search_key
        return (data=node.value.data, aux=node.value.aux)
    end
end

write(io::IO, n::LR) = write(io, n.left) + write(io, n.right)
write(io::IO, n::Leaf) = write(io, n.data) + write(io, n.aux)
write(io::IO, n::Empty) = 0
write(io::IO, ni::NodeInfo) = write(io, ni.tagged_key) + write(io, ni.value)

read(io::IO, ::Type{LR}) = LR(read(io, NodeInfo), read(io, NodeInfo))
read(io::IO, ::Type{Leaf}) = Leaf(read(io, UInt64), read(io, UInt64))

function read(io::IO, ::Type{NodeInfo})
    tagged_key = read(io, UInt64)
    t = tag(tagged_key)
    if t == onpage
        return NodeInfo(tagged_key, read(io, LR))
    end
    if t == empty
        return NodeInfo(tagged_key, Empty())
    end
    return NodeInfo(tagged_key, read(io, Leaf))
end

function write_pages(io, sorted_keys, kvs, leaf_tag; leafcount=16)
    node_count = round(Int, ceil(length(sorted_keys)/(leafcount)))
    next_sorted_keys = Vector{UInt64}(undef, node_count)
    next_kvs = typeof(kvs)()
    for i in 0:node_count-1
        lstart = leafcount * i
        sks = @views length(sorted_keys) < lstart+leafcount ? sorted_keys[lstart+1:end] : sorted_keys[lstart+1:lstart+leafcount]
        next_sorted_keys[i+1] = sks[end]
        next_kvs[sks[end]] = (data=position(io), aux=0)
        root = build_page(sks, kvs, leaf_tag)
        s = write(io, root)
        #println(stderr, "Nodes size $s")
    end

    next_sorted_keys, next_kvs
end

function nextblock(io; blocksize=1024)
    p = position(io)
    if mod(p, blocksize) > 0
        skip(io, blocksize - mod(p, blocksize))
    end
end
"""
    build_index_file(io::IO, kvs; meta=String[])
    build_index_file(filename::AbstractString, kvs; meta=String[])
#Arguments
`io::IO` descriptor for writing (so you can use IOBuffer if desired)
`meta::Vector{AbstractString}` vector of strings to add meta data
Create the on-disk representation of the index of the kvs Dict.
The Tree's Leaves are sorted by the key value of the kvs and store the kvs[key] 
All keys and values are all converted to UInt64.
"""
function build_index_file(io::IO, kvs; meta=String[])
    pos = position(io)
    write(io, UInt64(0)) # placeholder for root page offset
    write(io, Index(meta, io))
    sorted_keys = sort(collect(keys(kvs)))
    next_sorted_keys, next_kvs = write_pages(io, sorted_keys, kvs, leaf)
    while length(next_sorted_keys) > 1
        next_sorted_keys, next_kvs = write_pages(io, next_sorted_keys, next_kvs, topage)
    end
    seek(io, pos)
    write(io, next_kvs[next_sorted_keys[1]].data) # root position
    return pos
end

function build_index_file(filename::AbstractString, kvs; meta=String[])
    open(filename, "w+") do io
        build_index_file(io::IO, kvs; meta)
    end
end
"""
    open_index(filename::AbstractString)::Index
    open_index(io::IO)::Index
Create an Index struct on which one can perform searches using a previously created Index file.
"""
function open_index(io::IO) ## assume at position of root offset field
    root = read(io, UInt64)
    idx = read(io, Index)
    seek(io, root)
    mark(io)
    idx
end

open_index(filename::AbstractString) = open_index(open(filename, "r"))

import Base.show

function show(io::IO, lr::LR)
    print(io, " (Left:", lr.left)
    print(io, " Right:", lr.right)
    print(io, ")")
end

function show(io::IO, lr::Leaf)
    print(io, " Data:")
    show(io, lr.data)
    print(io, " Aux:")
    show(io, lr.aux)
end

function show(io::IO, ni::NodeInfo)
   
    print(io, " Key:")
    show(io, ni.tagged_key)

    print(io, " Node:")
    show(io, ni.value)
end

function show(io::IO, idx::Index)
    rewind(idx)
    show(io, read(idx.io, NodeInfo))
end

function todot(io::IO, ni::NodeInfo, level)
    if tag(ni) == onpage
        @printf(io, "X%d_%x [shape=invhouse, label=\"0x%x0..0%02x\"]\n ", level, ni.tagged_key, tag(ni.tagged_key), key(ni.tagged_key))
        @printf(io, "X%d_%x -> X%d_%x [label=\"<= 0x%02x\"]\n ", level, ni.tagged_key, level+1, ni.value.left.tagged_key, key(ni.tagged_key))
        @printf(io, "X%d_%x -> X%d_%x\n ", level, ni.tagged_key, level+1, ni.value.right.tagged_key)
        todot(io, ni.value.left, level+1)
        todot(io, ni.value.right, level+1)
    elseif tag(ni) == topage
        @printf(io, "X%d_%x [shape=invtriangle, label=\"offset: 0x%x\"]\n ", level, ni.tagged_key, ni.value.data)
    elseif tag(ni) == leaf
        @printf(io, "X%d_%x [shape=rect, label=\"key: 0x%x0..0%02x\ndata: 0x%x\naux: 0x%x\"]\n ", level, ni.tagged_key, tag(ni.tagged_key), key(ni.tagged_key), ni.value.data,ni.value.aux)
    end
end

function todot(idx::Index)
    rewind(idx)
    buff = IOBuffer()
    write(buff, "digraph I { \n")
    todot(buff, read(idx.io, NodeInfo), 0)
    write(buff, "}")
    seekstart(buff)
    read(buff, String)
end

function show(io::IO, m::MIME{Symbol("text/dot")}, idx::Index)
    show(io, todot(idx))
end
###
end
