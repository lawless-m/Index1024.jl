var documenterSearchIndex = {"docs":
[{"location":"example1/#Example-Indexing-of-a-CSV-file","page":"Example Indexing of a CSV file","title":"Example Indexing of a CSV file","text":"","category":"section"},{"location":"example1/#The-Data","page":"Example Indexing of a CSV file","title":"The Data","text":"","category":"section"},{"location":"example1/","page":"Example Indexing of a CSV file","title":"Example Indexing of a CSV file","text":"The CSV file I wish to index contains the data from the UK Land Registry.  https://www.gov.uk/guidance/about-the-price-paid-data This records the value of every house sale in England and Wales. I have gathered the data from 2000 onwards and extracted the following dataset. The postcode, year and price of every transaction.","category":"page"},{"location":"example1/","page":"Example Indexing of a CSV file","title":"Example Indexing of a CSV file","text":"What I want is to be able to extract the list of year / price entries for a particular postcode.","category":"page"},{"location":"example1/","page":"Example Indexing of a CSV file","title":"Example Indexing of a CSV file","text":"postcode,year,price        AL10 0AB,2000,63000        AL10 0AB,2003,126500       AL10 0AB,2003,167000       AL10 0AB,2003,177000       AL10 0AB,2004,125000       AL10 0AB,2013,220000       AL10 0AB,2014,180000       ⋮ YO8 9YB,2021,269950 YO8 9YD,2011,230000 YO8 9YD,2012,249999 YO8 9YD,2018,327500 YO8 9YE,2009,320000 YO8 9YE,2019,380000 YO8 9YE,2020,371500 YO90 1UU,2017,15500000 YO90 1WR,2015,28100000 YO91 1RT,2017,150000","category":"page"},{"location":"example1/","page":"Example Indexing of a CSV file","title":"Example Indexing of a CSV file","text":"13,193,754 lines, including the header. The file size is 267,473,752 bytes.","category":"page"},{"location":"#Index1024.jl","page":"Index1024.jl","title":"Index1024.jl","text":"","category":"section"},{"location":"","page":"Index1024.jl","title":"Index1024.jl","text":"Documentation for Index1024.jl","category":"page"},{"location":"","page":"Index1024.jl","title":"Index1024.jl","text":"Data Types","category":"page"},{"location":"","page":"Index1024.jl","title":"Index1024.jl","text":"Index","category":"page"},{"location":"#Index1024.Index","page":"Index1024.jl","title":"Index1024.Index","text":"Index\n\nstruct to hold the data associated with a particular Index\n\nProperties\n\nmeta::Vector{String} user defined meta-data to save in the index file\nio::IO the file handle of the index used to navigate\n\n\n\n\n\n","category":"type"},{"location":"","page":"Index1024.jl","title":"Index1024.jl","text":"DataAux","category":"page"},{"location":"#Index1024.DataAux","page":"Index1024.jl","title":"Index1024.DataAux","text":"DataAux\n\nType of the leaf data. (data=UInt64, aux=UInt64)\n\nNamed elements\n\ndata::UInt64 user supplied\naux::UInt64 user supplied\n\n\n\n\n\n","category":"type"},{"location":"","page":"Index1024.jl","title":"Index1024.jl","text":"Creating an Index","category":"page"},{"location":"","page":"Index1024.jl","title":"Index1024.jl","text":"build_index_file","category":"page"},{"location":"#Index1024.build_index_file","page":"Index1024.jl","title":"Index1024.build_index_file","text":"build_index_file(io::IO, kvs; meta=String[])\nbuild_index_file(filename::AbstractString, kvs; meta=String[])\n\nCreate the on-disk representation of the index of the kvs Dict. The Leafs are sorted by the key values of the kvs.\n\nArguments\n\nio::IO descriptor for writing (so you can use IOBuffer if desired)\nkvs Dict{UInt64, T}() where T is the type of the leaf, by default DataAux - might expand in future\nmeta::Vector{AbstractString} vector of strings to add meta data\n\n\n\n\n\n","category":"function"},{"location":"","page":"Index1024.jl","title":"Index1024.jl","text":"Using an index","category":"page"},{"location":"","page":"Index1024.jl","title":"Index1024.jl","text":"open_index","category":"page"},{"location":"#Index1024.open_index","page":"Index1024.jl","title":"Index1024.open_index","text":"open_index(filename::AbstractString)::Index\nopen_index(io::IO)::Index\n\nOpen an Index struct from file on which one can perform searches.\n\n\n\n\n\n","category":"function"},{"location":"","page":"Index1024.jl","title":"Index1024.jl","text":"search","category":"page"},{"location":"#Index1024.search","page":"Index1024.jl","title":"Index1024.search","text":"search(idx::Index, search_key::UInt64)::Union{UInt64, Nothing}\n\nSearch the given index for a given search_key returning a Tuple of the previously stored value If the search_key is not found, return nothing\n\nArguments\n\nidx Index to use\nsearch_key UInt64 key to search for\n\n\n\n\n\n","category":"function"},{"location":"","page":"Index1024.jl","title":"Index1024.jl","text":"get","category":"page"},{"location":"#Base.get","page":"Index1024.jl","title":"Base.get","text":"get(idx::Index, search_key, default)\n\nSearch the given index for a given search_key returning a Tuple of the previously stored value or the default\n\nArguments\n\nidx Index to search\nsearch_key untagged UInt64 key to search for\ndefault what to return if the key is not found\n\n\n\n\n\n","category":"function"},{"location":"","page":"Index1024.jl","title":"Index1024.jl","text":"node_range","category":"page"},{"location":"#Index1024.node_range","page":"Index1024.jl","title":"Index1024.node_range","text":"node_range(idx::Index, min_key, max_key)\n\nGather all the Leafs in a given idx where min_key <= key <= max_key\n\n\n\n\n\n","category":"function"},{"location":"","page":"Index1024.jl","title":"Index1024.jl","text":"todot","category":"page"},{"location":"#Index1024.todot","page":"Index1024.jl","title":"Index1024.todot","text":"todot(idx::Index)\n\nOutput the tree in GraphViz dot format. Used for debugging and only includes the root node.\n\n\n\n\n\n","category":"function"},{"location":"","page":"Index1024.jl","title":"Index1024.jl","text":"Extending the library","category":"page"},{"location":"","page":"Index1024.jl","title":"Index1024.jl","text":"build_page","category":"page"},{"location":"#Index1024.build_page","page":"Index1024.jl","title":"Index1024.build_page","text":"build_page(ks, kvs, terminal_tag)\n\nUsing the given keys ks use the key/values in ks to generate the tree for this page.  The page is the same structure whether the terminals are leafs or \"pointers\"\n\nArguments\n\nks UInt64 keys to write in the terminals (a fixed size per page)\nkvs the key / value dictionary containing all of the UInt64 => DataAux pairs\nterminal_tag the UInt8 Tag applied to the keys of the terminals\n\n\n\n\n\n","category":"function"},{"location":"","page":"Index1024.jl","title":"Index1024.jl","text":"page_nodes","category":"page"},{"location":"#Index1024.page_nodes","page":"Index1024.jl","title":"Index1024.page_nodes","text":"page_nodes(idx, page, min_key, max_key)\n\nWalk the entire page, a return the leafs and topage Nodes in separate lists\n\nArguments\n\nidx Index of the tree, needed for io\npage first node of the given page\nmin_key, max_key range of keys for the Leafs wanted\n\n\n\n\n\n","category":"function"},{"location":"","page":"Index1024.jl","title":"Index1024.jl","text":"get_leaf","category":"page"},{"location":"#Index1024.get_leaf","page":"Index1024.jl","title":"Index1024.get_leaf","text":"get_leaf(idx::Index, search_key)\n\nSearch the tree for a particular leaf node and return it (or nothing)\n\nArguments\n\nidx an Index to search\nsearch_key an untagged UInt64 key to search for\n\n\n\n\n\n","category":"function"},{"location":"","page":"Index1024.jl","title":"Index1024.jl","text":"write_pages","category":"page"},{"location":"#Index1024.write_pages","page":"Index1024.jl","title":"Index1024.write_pages","text":"write_pages(io, sorted_keys, kvs, terminal_tag; terminal_count=16)\n\nWrite the current depth of the tree to disk, depth first. Returns the keys at the root of each page in order and generates the kvs to use as DataAux values\n\nArguments\n\nio - write into this IO\nsorted_keys keys to use in the terminals, in order\nkvs Dict of the values to use in the terminals\nterminal_tag Tag the terminals with terminal_tag (which will be either leaf or topage)\nterminal_count write this many terminals, which might be more than the number of keys\n\n\n\n\n\n","category":"function"}]
}
