module Index1024

import Base.read, Base.write

export Index, search, build_index_file, open_index

const mask = 0xf000000000000000
const shift = 60
const onpage = 0x1
const topage = 0x2
const leaf = 0x3
const empty = 0xf
const ff = ~UInt64(0) >> 4

const pages_per_block = 31

const version = UInt16(1)

struct Index
    files::Vector{String}
    io::IO
    Index(files, io) = new(files, io)
    Index(io::IO) = Index(Vector{String}(), io)
end

function write(io::IO, index::Index)
    write(io, version) # version
    write(io, UInt32(length(index.files)))
    foreach(f->println(io, f), index.files)
    nextblock(io)
    position(io)
end

function read(io::IO, ::Type{Index})
    @assert read(io, UInt16) == version
    n = read(io, UInt32)
    index = Index(io)
    while n > 0
        push!(index.files, readline(io))
        n -= 1
    end
    nextblock(io)
    index
end

abstract type Node end

struct LR <: Node
    left::UInt64
    right::UInt64
end

struct Leaf <: Node
    data::UInt64
    aux::UInt64
end

struct NodeInfo
    tagged_key::UInt64 # threshold or leaf value - determined by tag
    value::Node
    NodeInfo(key, value) = new(key, value)
end

tag(t, v) = UInt64(v) | (UInt64(t) << shift)
tag(n::NodeInfo) = tag(n.tagged_key)
tag(v::UInt) = UInt16((UInt64(v) & mask) >> shift)
key(n::NodeInfo) = key(n.tagged_key)
key(v::UInt) = UInt64(v) & ~mask

struct Page 
    nodes::Vector{NodeInfo}
    Page() = Page(pages_per_block)
    Page(n::Int) = Page(Vector{NodeInfo}(undef, n))
    Page(ns::Vector{NodeInfo}) = new(ns)
end

function read(io::IO, ::Type{Page})
    p = Page(pages_per_block)
    for i in 1:pages_per_block
        p.nodes[i] = read(io, NodeInfo)
    end
    p
end

function build_page(ks, kvs, leaf_tag; aux=Dict())
    p = Page(31)
    
    k = 1
    for pk in 0x10:0x1f # 10:16
        # tag the key as a leaf (or empty), leaf the value
        if k > length(ks)
            p.nodes[pk] = NodeInfo(tag(empty, ff), Leaf(0, 0))
        else
            p.nodes[pk] = NodeInfo(tag(leaf_tag, ks[k]), Leaf(kvs[ks[k]], get(aux, ks[k], 0)))
        end
        k += 1
    end

    k = 1
    for pk in 0x08:0x0f # 8:15
        # tag the left key as a threshold, leaf the L & R
        if k > length(ks)
            p.nodes[pk] = NodeInfo(tag(onpage, ff), LR(2pk, 2pk+1))
        else
            p.nodes[pk] = NodeInfo(tag(onpage, ks[k]), LR(2pk, 2pk+1))
        end
        k += 2
    end

    k = 2
    for pk in 0x04:0x07
        # tag the left key as a threshold, leaf the L & R
        if k > length(ks)
            p.nodes[pk] = NodeInfo(tag(onpage, ff), LR(2pk, 2pk+1))
        else
            p.nodes[pk] = NodeInfo(tag(onpage, ks[k]), LR(2pk, 2pk+1))
        end
        k += 4
    end

    k = 4
    for pk in 0x02:0x03
        # tag the left key as a threshold, leaf the L & R
        if k > length(ks)
            p.nodes[pk] = NodeInfo(tag(onpage, ff), LR(2pk, 2pk+1))
        else
            p.nodes[pk] = NodeInfo(tag(onpage, ks[k]), LR(2pk, 2pk+1))
        end
        k += 8
    end

    if 8 > length(ks)
        p.nodes[1] = NodeInfo(tag(onpage, ff), LR(2, 3))
    else
        p.nodes[1] = NodeInfo(tag(onpage, ks[8]), LR(2, 3))
    end

    p
end
"""
    search(idx::Index, search_key::UInt64)::Union{Tuple{UInt64, UInt64}, Nothing}
Search the given index for a given search_key returning a Tuple of the previously stored value / aux pair (or 0 for the aux if it wasn't supplied).
If the search_key is not found, return nothing
"""
search(idx::Index, search_key)::Union{Tuple{UInt64, UInt64}, Nothing} = get_node(idx.io, UInt64(search_key))

function get_node(io::IO, search_key)
    reset(io)
    mark(io)
    page = read(io, Page)
    node = page.nodes[1]
    while tag(node) == onpage
        node = search_key <= key(node) ? page.nodes[node.value.left] : page.nodes[node.value.right]
        if tag(node) == topage
            seek(io, node.value.data)
            page = read(io, Page)
            node = page.nodes[1]
        end
    end
    if tag(node) == leaf && key(node) == search_key
        return node.value.data, node.value.aux
    end
end

write(io::IO, n::LR) = write(io, n.left) + write(io, n.right)
write(io::IO, n::Leaf) = write(io, n.data) + write(io, n.aux)
write(io::IO, ni::NodeInfo) = write(io, ni.tagged_key) + write(io, ni.value)

read(io::IO, ::Type{LR}) = LR(read(io, UInt64), read(io, UInt64))
read(io::IO, ::Type{Leaf}) = Leaf(read(io, UInt64), read(io, UInt64))

function read(io::IO, ::Type{NodeInfo})
    tagged_key = read(io, UInt64)
    t = tag(tagged_key)
    if t == onpage
        return NodeInfo(tagged_key, read(io, LR))
    end
    return NodeInfo(tagged_key, read(io, Leaf))
end

write(io::IO, p::Page) = reduce((a,n)->a+=write(io, n), p.nodes, init=0)

function write_pages(io, sorted_keys, kvs, leaf_tag; aux=Dict())
    node_count = round(Int, ceil(length(sorted_keys)/16))
    next_sorted_keys = Vector{UInt64}(undef, node_count)
    next_kvs = Dict{UInt64, UInt64}()
    for i in 0:node_count-1
        sks = @views length(sorted_keys) < 16i+16 ? sorted_keys[16i+1:end] : sorted_keys[16i+1:16i+16]
        next_sorted_keys[i+1] = sks[end]
        next_kvs[sks[end]] = position(io)
        write(io, build_page(sks, kvs, leaf_tag; aux))
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
    build_index_file(io::IO, filelist, kvs; aux=Dict())
    build_index_file(filename::AbstractString, filelist, kvs; aux=Dict())

Create the on-disk representation of the index of the kvs Dict.
The Tree's Leaves are sorted by the key value of the kvs and store both the kvs[key] and aux[key] (if given)
All keys and values are all converted to UInt64.
"""
function build_index_file(io::IO, filelist, kvs; aux=Dict())
    write(io, UInt64(0)) # placeholder for root page offset
    write(io, Index(filelist, io))
    sorted_keys = sort(collect(keys(kvs)))
    next_sorted_keys, next_kvs = write_pages(io, sorted_keys, kvs, leaf; aux)
    while length(next_sorted_keys) > 1
        next_sorted_keys, next_kvs = write_pages(io, next_sorted_keys, next_kvs, topage; aux)
    end
    seek(io, 0)
    write(io, next_kvs[next_sorted_keys[1]]) # root position
end

function build_index_file(filename::AbstractString, filelist, kvs; aux=Dict())
    open(filename, "w+") do io
        build_index_file(io::IO, filelist, kvs; aux)
    end
end
"""
    open_index(filename::AbstractString)::Index
    open_index(io::IO)::Index
Create an Index struct on which one can perform searches using a previously created Index file.
"""
function open_index(io::IO)
    seekstart(io)
    root = read(io, UInt64)
    idx = read(io, Index)
    seek(io, root)
    mark(io)
    idx
end

open_index(filename::AbstractString) = open_index(open(filename, "r"))

###
end
