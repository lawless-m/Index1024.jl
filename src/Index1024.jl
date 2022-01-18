module Index1024

import Base.read, Base.write

using Printf

# for use by clients
# creating Index
export Index, DataAux, build_index_file

# using Index
export search, get, open_index, node_range, todot

# for use by libraries
export build_page, page_nodes, get_leaf, write_pages

const mask = 0xf000000000000000
const shift = 60
const onpage = 0x1
const topage = 0x2
const leaf = 0x3
const empty = 0xf
const ff = ~UInt64(0) >> 4

const pages_per_block = 31

const version = UInt16(3)
#==
Offset Contents
000000 UInt16(version)
000002 UInt32(length(meta))
000... Meta lines

Nextblock multiple of 0x400

000000 page1

==#
"""
    DataAux
Type of the leaf data. (data=UInt64, aux=UInt64)
# Named elements
- `data::UInt64` user supplied
- `aux::UInt64` user supplied
"""
const DataAux = typeof((data=zero(UInt64), aux=zero(UInt64)))

"""
    Index
struct to hold the data associated with a particular `Index`
# Properties
- `meta::Vector{String}` user defined meta-data to save in the index file
- `io::IO` the file handle of the index used to navigate
"""
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
    position(io)
end

function read(io::IO, ::Type{Index})
    @assert read(io, UInt16) == version
    metacount = read(io, UInt32)
    index = Index(io)
    while metacount > 0
        push!(index.meta, readline(io))
        metacount -= 1
    end
    mark(io)
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

"""
    build_page(ks, kvs, terminal_tag)
Using the given keys `ks` use the key/values in `ks` to generate the tree for this page. 
The page is the same structure whether the terminals are leafs or "pointers"
# Arguments
- `ks` UInt64 keys to write in the terminals (a fixed size per page)
- `kvs` the key / value dictionary containing all of the UInt64 => DataAux pairs
- `terminal_tag` the UInt8 Tag applied to the keys of the terminals
"""
function build_page(ks, kvs, terminal_tag)
    next2pow::Int = Int(1 << (64 - (leading_zeros(length(ks)-1))+1))
    nodes = Vector{NodeInfo}(undef, next2pow-1)
    kstep = 1
    k = 1
    for pk in (next2pow>>1):(next2pow-1) # e.g. 0x10:0x1f
        if k > length(ks)
            nodes[pk] = NodeInfo(tag(empty, ff), Empty())
        else
            nodes[pk] = NodeInfo(tag(terminal_tag, ks[k]), Leaf(kvs[ks[k]].data, kvs[ks[k]].aux))
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
Search the given index for a given `search_key` returning a Tuple of the previously stored value
If the `search_key` is not found, return `nothing`
# Arguments
- `idx` Index to use
- `search_key` UInt64 key to search for
"""
function search(idx::Index, search_key)
    node = get_leaf(idx, search_key)
    node === nothing ? nothing : (; data=node.value.data, aux=node.value.aux)
end

import Base.get
"""
    get(idx::Index, search_key, default)
Search the given index for a given `search_key` returning a Tuple of the previously stored value or the `default`
# Arguments
- `idx` Index to search
- `search_key` untagged UInt64 key to search for
- `default` what to return if the key is not found
"""
function get(idx::Index, search_key, default)
    da = search(idx, UInt64(search_key))
    da === nothing ? default : da
end

# use io marks to manage the id position
rewind(idx::Index) = rewind(idx.io)
rewind(io::IO) = begin reset(io); mark(io); end

# move the pointer to the start of the index
function root_node(idx::Index)
    rewind(idx.io)
    read(idx.io, NodeInfo)
end

"""
    get_leaf(idx::Index, search_key)
Search the tree for a particular leaf node and return it (or nothing)
# Arguments
- `idx` an Index to search
- `search_key` an untagged UInt64 key to search for
"""
function get_leaf(idx::Index, search_key)
    node = root_node(idx::Index)
    while tag(node) == onpage
        node = search_key <= key(node) ? node.value.left : node.value.right
        if tag(node) == topage
            seek(idx.io, node.value.data)
            node = read(idx.io, NodeInfo)
        end
    end
    # not always a key match, just the last leaf found
    tag(node) == leaf && key(node) == search_key ? node : nothing
end

"""
    page_nodes(idx, page, min_key, max_key)
Walk the entire page, a return the leafs and topage Nodes in separate lists
# Arguments
- `idx` Index of the tree, needed for io
- `page` first node of the given page
- `min_key`, `max_key` range of keys for the Leafs wanted
"""
function page_nodes(idx, page, min_key, max_key)

    nodes = NodeInfo[]
    leafs = Dict{UInt64, Node}()
    pages = NodeInfo[]

    function add_leaf(nde)
        k = key(nde)
        if min_key <= k <= max_key
            leafs[k] = nde.value
        end
    end

    add_onpage(nde) = push!(nodes, nde)
    function add_topage(nde)
        seek(idx.io, nde.value.data)
        push!(pages, read(idx.io, NodeInfo))
    end

    vt = Dict(leaf=>add_leaf, onpage =>add_onpage, topage=>add_topage)

    dvt(nde) = get(vt, tag(nde), (n)->nothing)(nde)

    dvt(page.value.left)
    dvt(page.value.right)

    while length(nodes) > 0
        node = pop!(nodes)
        dvt(node.value.left)
        dvt(node.value.right)
    end
    leafs, pages
end

"""
    node_range(idx::Index, min_key, max_key)
Gather all the Leafs in a given `idx` where `min_key <= key <= max_key`
"""
function node_range(idx::Index, min_key, max_key)
    page = root_node(idx)
    range_leafs, unseen_pages = page_nodes(idx, page, min_key, max_key)
    
    while length(unseen_pages) > 0
        page = pop!(unseen_pages)
        page_leafs, more_unseen_pages = page_nodes(idx, page, min_key, max_key)
        merge!(range_leafs, page_leafs)
        append!(unseen_pages, more_unseen_pages)
    end
    range_leafs
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

"""
    write_pages(io, sorted_keys, kvs, terminal_tag; terminal_count=16)
Write the current depth of the tree to disk, depth first.
Returns the keys at the root of each page in order and generates the kvs to use as DataAux values
# Arguments
- `io` - write into this IO
- `sorted_keys` keys to use in the terminals, in order
- `kvs` Dict of the values to use in the terminals
- `terminal_tag` Tag the terminals with `terminal_tag` (which will be either `leaf` or `topage`)
- `terminal_count` write this many terminals, which might be more than the number of keys
"""
function write_pages(io, sorted_keys, kvs, terminal_tag; terminal_count=16)
    node_count = round(Int, ceil(length(sorted_keys)/(terminal_count)))
    next_sorted_keys = Vector{UInt64}(undef, node_count)
    next_kvs = typeof(kvs)()
    for i in 0:node_count-1
        tstart = terminal_count * i + 1
        tend = min(length(sorted_keys), tstart + terminal_count -1)
        sks = @views sorted_keys[tstart:tend]
        next_sorted_keys[i+1] = sks[end] # this repeats if not enough sks exist for all the terminals
        next_kvs[sks[end]] = (data=position(io), aux=0)
        write(io, build_page(sks, kvs, terminal_tag))
    end

    next_sorted_keys, next_kvs
end

function nextblock(io; blocksize=1024)  # no longer used
    p = position(io)
    if mod(p, blocksize) > 0
        skip(io, blocksize - mod(p, blocksize))
    end
end

"""
    build_index_file(io::IO, kvs; meta=String[])
    build_index_file(filename::AbstractString, kvs; meta=String[])
Create the on-disk representation of the index of the kvs Dict.
The Leafs are sorted by the key values of the kvs.
# Arguments
- `io::IO` descriptor for writing (so you can use IOBuffer if desired)
- `kvs` Dict{UInt64, T}() where T is the type of the leaf, by default DataAux - might expand in future
- `meta::Vector{AbstractString}` vector of strings to add meta data
"""
build_index_file(filename::AbstractString, kvs; meta=String[]) = open(filename, "w+") do io build_index_file(io::IO, kvs; meta) end

function build_index_file(io::IO, kvs; meta=String[])
    startpos = position(io)
    write(io, zero(Int64)) # middle of page where root node starts
    write(io, Index(meta, io))
    sorted_keys = sort(collect(keys(kvs)))
    next_sorted_keys, next_kvs = write_pages(io, sorted_keys, kvs, leaf)
    while length(next_sorted_keys) > 1
        next_sorted_keys, next_kvs = write_pages(io, next_sorted_keys, next_kvs, topage)
    end
    size = position(io) - startpos
    seek(io, startpos)
    write(io, next_kvs[next_sorted_keys[1]].data)
    seek(io, startpos)
    return size
end

"""
    open_index(filename::AbstractString)::Index
    open_index(io::IO)::Index
Open an Index struct from file on which one can perform searches.
"""
function open_index(io::IO)
    root = read(io, Int64)
    idx = read(io, Index)
    seek(io, root)
    mark(io)
    idx
end

open_index(filename::AbstractString) = open_index(open(filename, "r"))

import Base.show

function show(io::IO, lr::LR)
    print(io, " (LR left:", lr.left)
    print(io, " right:", lr.right)
    print(io, ")")
end

function show(io::IO, lr::Leaf)
    print(io, "(Leaf data:")
    show(io, lr.data)
    print(io, " aux:")
    show(io, lr.aux)
    print(io, ")")
end

function show(io::IO, ni::NodeInfo)
    print(io, " NI key:")
    show(io, ni.tagged_key)

    print(io, " value:")
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

"""
    todot(idx::Index)
Output the tree in GraphViz dot format. Used for debugging and only includes the root node.
"""
function todot(idx::Index)
    rewind(idx)
    buff = IOBuffer()
    write(buff, "digraph I { \n")
    todot(buff, read(idx.io, NodeInfo), 0)
    write(buff, "}")
    seekstart(buff)
    read(buff, String)
end

###
end
