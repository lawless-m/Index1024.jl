module Index1024

export Index, index_vector, get_node

export testidx

const mask = 0xf000000000000000
const shift = 60
const onpage = 0x1
const topage = 0x2
const leaf = 0x3
const empty = 0xf
const ff = ~UInt64(0)


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
    child_count::UInt64
    value::Node
    NodeInfo(key, children, value) = new(key, children, value)
end

tag(t, v) = UInt64(v) | (UInt64(t) << shift)
detag(n::NodeInfo) = detag(n.tagged_key)
detag(v::UInt64) = UInt16((UInt64(v) & mask) >> shift)
key(n::NodeInfo) = key(n.tagged_key)
key(v::UInt64) = UInt64(v) & ~mask

struct Page 
    nodes::Vector{NodeInfo}
    Page() = Page(31)
    Page(n) = new(Vector{NodeInfo}(undef, n))
end

struct Index
    pages::Vector{Page}
    Index(nitems) = new(Vector{Page}(undef, round(Int, ceil(nitems/16))))
end

function build_leaf_page(ks, kvs)
    p = Page(31)
    
    k = 1
    for pk in 16:31
        # tag the key as a leaf (or empty), leaf the value
        if k > length(ks)
            p.nodes[pk] = NodeInfo(tag(empty, ff), 0, Leaf(0, 0))
        else
            p.nodes[pk] = NodeInfo(tag(leaf, ks[k]), 0, Leaf(kvs[ks[k]], 0))
        end
        k += 1
    end

    k = 1
    for pk in 8:15
        # tag the left key as a threshold, leaf the L & R
        if k > length(ks)
            p.nodes[pk] = NodeInfo(tag(onpage, ff), 1, LR(2pk, 2pk+1))
        else
            p.nodes[pk] = NodeInfo(tag(onpage, ks[k]), 2, LR(2pk, 2pk+1))
        end
        k += 2
    end

    k = 2
    for pk in 4:7
        # tag the left key as a threshold, leaf the L & R
        if k > length(ks)
            p.nodes[pk] = NodeInfo(tag(onpage, ff), 2, LR(2pk, 2pk+1))
        else
            p.nodes[pk] = NodeInfo(tag(onpage, ks[k]), 4, LR(2pk, 2pk+1))
        end
        k += 4
    end

    k = 4
    for pk in 2:3
        # tag the left key as a threshold, leaf the L & R
        if k > length(ks)
            p.nodes[pk] = NodeInfo(tag(onpage, ff), 4, LR(2pk, 2pk+1))
        else
            p.nodes[pk] = NodeInfo(tag(onpage, ks[k]), 8, LR(2pk, 2pk+1))
        end
        k += 8
    end

    if 8 > length(ks)
        p.nodes[1] = NodeInfo(tag(onpage, ff), 8, LR(2, 3))
    else
        p.nodes[1] = NodeInfo(tag(onpage, ks[8]), 16, LR(2, 3))
    end

    p
end

function get_node(key, p::Page)
    n = p.nodes[1]
    t = detag(n)
    while t == onpage 
        n = p.nodes[key < key(n) ? n.value.left : n.value.right]
        t = detag(n)
    end
    if t == topage
        return n
    end
    if t == leaf && key(n) == key
        return n
    end
    nothing    
end

function build_leaf_pages!(idx, kvs)
    sorted_keys = sort(collect(keys(kvs)))
    for k in 0:length(idx.pages)-1
        sks = @views length(sorted_keys) < 16k+16 ? sorted_keys[16k+1:end] : sorted_keys[16k+1:16k+16]
        idx.pages[k+1] = build_leaf_page(sks, kvs)
    end
    1:length(idx.pages)
end

function node_count(n)
    if n < 2
        return 3
    end
    if n < 4
        return 9
    end
    if n < 8
        return 17
    end
    if n < 16
        return 31
    end
    throw("Too many values for a page")
end

function build_tree_page(topages) # pageno=>key
    
    k = 1
    for pk in 16:31
        # tag the key as a leaf (or empty), leaf the value
        if k > length(ks)
            p.nodes[pk] = NodeInfo(tag(empty, ff), 0, Leaf(0, 0))
        else
            p.nodes[pk] = NodeInfo(tag(topage, ks[k]), 0, Leaf(kvs[ks[k]], 0))
        end
        k += 1
    end

    k = 1
    for pk in 8:15
        # tag the left key as a threshold, leaf the L & R
        if k > length(ks)
            p.nodes[pk] = NodeInfo(tag(onpage, ff), 1, LR(2pk, 2pk+1))
        else
            p.nodes[pk] = NodeInfo(tag(onpage, ks[k]), 2, LR(2pk, 2pk+1))
        end
        k += 2
    end

    k = 2
    for pk in 4:7
        # tag the left key as a threshold, leaf the L & R
        if k > length(ks)
            p.nodes[pk] = NodeInfo(tag(onpage, ff), 2, LR(2pk, 2pk+1))
        else
            p.nodes[pk] = NodeInfo(tag(onpage, ks[k]), 4, LR(2pk, 2pk+1))
        end
        k += 4
    end

    k = 4
    for pk in 2:3
        # tag the left key as a threshold, leaf the L & R
        if k > length(ks)
            p.nodes[pk] = NodeInfo(tag(onpage, ff), 4, LR(2pk, 2pk+1))
        else
            p.nodes[pk] = NodeInfo(tag(onpage, ks[k]), 8, LR(2pk, 2pk+1))
        end
        k += 8
    end

    if 8 > length(ks)
        p.nodes[1] = NodeInfo(tag(onpage, ff), 8, LR(2, 3))
    else
        p.nodes[1] = NodeInfo(tag(onpage, ks[8]), 16, LR(2, 3))
    end

    p
end

function build_tree_pages!(idx, prev_page_range)
    topages = Dict()
    for p in prev_page_range
        topages[p] = key(idx.pages[p].nodes[1])
    end

    p1 = length(idx.pages)+1
    new_page_count = round(Int, ceil(length(topages)/16))
    append!(idx.pages, Vector{Page}(undef, new_page_count))
    for k in 0:length(new_page_count)-1
        idx.pages[p1+k] = build_tree_page(topages)
    end

    last(prev_level)+1:length(idx.pages)
end

function index_kvs(kvs)
    sorted_keys = sort(collect(keys(kvs)))
    idx = Index(length(sorted_keys))
    page_range = build_leaf_pages!(idx, kvs)

    while length(page_range) > 1
        page_range = build_tree_pages!(idx, page_range)
    end
    idx
end

testidx() = index_kvs(Dict{UInt64, UInt64}(2k=>10k for k in 1:33))


###
end
