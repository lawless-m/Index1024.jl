Example Indexing of a CSV file
==============================

# The Data

The CSV file I wish to index contains the data from the UK Land Registry. 
https://www.gov.uk/guidance/about-the-price-paid-data
This records the value of every house sale in England and Wales. I have gathered the data from 2000 onwards and extracted the following dataset. The postcode, year and price of every transaction.

What I want is to be able to extract the list of year / price entries for a particular postcode.

```
postcode,year,price       
AL10 0AB,2000,63000       
AL10 0AB,2003,126500      
AL10 0AB,2003,167000      
AL10 0AB,2003,177000      
AL10 0AB,2004,125000      
AL10 0AB,2013,220000      
AL10 0AB,2014,180000      
⋮
YO8 9YB,2021,269950
YO8 9YD,2011,230000
YO8 9YD,2012,249999
YO8 9YD,2018,327500
YO8 9YE,2009,320000
YO8 9YE,2019,380000
YO8 9YE,2020,371500
YO90 1UU,2017,15500000
YO90 1WR,2015,28100000
YO91 1RT,2017,150000
```

13,193,754 lines, including the header. The file size is 267,473,752 bytes.

In the Index I can store the Named Tuple `(data:UInt64, aux:UInt64)` for each `UInt64` Key.

So what I shall do is to store the file offset of the first postcode entry in the data and the number of rows in the aux.

It just so happens that the postcode is, at most, 7 characters long, so this can be converted into a UInt64 with a byte spare the the tag.

By turning the postcodes into a fixed format
from
```
YO8 9YE
YO90 1UU
```
to
```
YO 8 9YE
YO90 1UU
```
we can also make the process reversible.

Here are the functions to do this

```
function postcode_to_UInt64(pc) 
    m = match(r"([A-Z]+)([0-9]+([A-Z]+)?) ?([0-9]+)([A-Z]+)", replace(pc, " "=>""))
    if m == nothing || m[1] === nothing || m[2] === nothing || m[4] === nothing || m[5] === nothing
        return 0
    end
    reduce((a,c) -> UInt64(a) << 8 + UInt8(c), collect(lpad(m[1], 2) * lpad(m[2], 2) * m[4] * m[5]), init=0)
end

function UInt64_to_postcode(u)
    cs = Char[]
    while u > 0
        push!(cs, Char(u & 0xff))
        u >>= 8
    end
    part(cs) = replace(String(reverse(cs)), " "=>"")
    "$(part(cs[4:end])) $(part(cs[1:3]))"
end
```

# Creating the Keyset

So, now iterate over the data and create the Keyset

```
function count_lines(io, pcode)
    lines = 0
    pos = position(io)
    while (line = readline(io)) !== nothing
        lines += 1
        newcode = split(line, ",", limit=2)[1]
        if newcode != pcode
            return newcode, lines, pos
        end
        pos = position(io)
    end
    return "", lines, pos
end

create_kvs(fname) = open(create_kvs, fname)

function create_kvs(io::IO)
    kvs = Dict{UInt64, DataAux}()
    readline(io)
    pos = position(io)
    pcode, lines, nextpos = count_lines(io, "postcode")
    while pcode != ""
        newcode, lines, nextpos = count_lines(io, pcode)
        kvs[postcode_to_UInt64(pcode)] = (data=pos, aux=lines)
        pcode = newcode
        pos = nextpos
    end
    kvs
end
```

It's not really necessary to understand how all that works (in fact my first version was wrong!), just know that when we run it

```
julia> create_kvs("pc_year_price.csv")
```

we get something like the following Dictionary

```
Dict{UInt64, NamedTuple{(:data, :aux), Tuple{UInt64, UInt64}}} with 4 entries:
  0x00594f2038395942 => (data = 0x00000000000000e6, aux = 0x0000000000000007)
  0x00594f2038395945 => (data = 0x0000000000000136, aux = 0x0000000000000009)
  ⋮
  0x00414c3130304142 => (data = 0x0000000000000536, aux = 0x0000000000000027)
  0x00594f2038395944 => (data = 0x0000000000000bfa, aux = 0x0000000000000013)
```

The keys are the encoded postcodes e.g.

`"AL10 0AB"` becomes `0x00414c3130304142` and at offset 0x536 in the CSV files, has 27 rows of data

Which is the format of the keyset we need to build the actual index.

That part of the process is in the modules

```
julia> @time build_index_file("Postcode_Year_Price.index", create_kvs("pc_year_price.csv"))
 10.181108 seconds (83.94 M allocations: 6.096 GiB, 10.57% gc time)
42453022
```

`build_index_file` returns the number of bytes written

So now in my pwd() is the index file

`42453022 Jan 18 13:56 Postcode_Year_Price.index`

At 41M it is only a bit smaller than the 256M of pc_year_price.csv but to explore it, we don't need to have it in memory.

What we do need, though, are some accessor functions. 

If we open the index we get
```
julia> idx = open_index("Postcode_Year_Price.index")
 NI key:0x1053522036384146 value: (LR left: NI key:0x2053522036384146 value:(Leaf data:0x000000000287c576 aux:0x0000000000000000) right: NI key:0x20594f3931315254 value:(Leaf data:0x000000000287c76e aux:0x0000000000000000))
```
This is the root node of the first page. This example is rather shallow, but that is an artefact of the number of data Leafs.

We can search this idx 
```
julia> get_leaf(idx, postcode_to_UInt64("YO8 9YB"))
 NI key:0x30594f2038395942 value:(Leaf data:0x000000000ff15226 aux:0x0000000000000007)
```
How quick is this? 
```
julia> @benchmark get_leaf($idx, $postcode_to_UInt64("YO8 9YB"))
BenchmarkTools.Trial: 10000 samples with 1 evaluation.
 Range (min … max):  32.455 μs …  3.829 ms  ┊ GC (min … max): 0.00% … 97.92%
 Time  (median):     35.409 μs              ┊ GC (median):    0.00%
 Time  (mean ± σ):   36.733 μs ± 52.923 μs  ┊ GC (mean ± σ):  2.01% ±  1.38%

    ▃█▆▄▅▄▃▆█▆▅▅▃     ▄▅▃                                      
  ▂▅██████████████▆▅▅█████▇▅▄▅▄▃▃▂▂▂▂▂▂▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁ ▄
  32.5 μs         Histogram: frequency by time        46.5 μs <

 Memory estimate: 9.31 KiB, allocs estimate: 247.
 ```
 
 Certainly a lot slower (20x) than reading it straight from memory. 
 
 But at least doesn't need the whole kvs in memory

 What we don't have, though, is the actual data. So let's write an accessor function for that.

```
prices_for_postcode(idx, pcode, csvfile) = open(csvfile) do io prices_for_postcode(idx, pcode, io) end
        
function prices_for_postcode(idx, pcode, csvio::IO)
    (offset, lines) = get(idx, postcode_to_UInt64(pcode), (0,0))
    if lines > 0
        seek(csvio, offset)
        return CSV.File(csvio; header=["postcode", "year", "price"], limit=lines)
    end
end
```

We write two functions, one which takes a filename and one which takes an IO. That way we can perform either a single lookup or multiple lookups without opening / closing the file (or use an IOBuffer instead of a file and go full circle!)

The function finds a Leaf node. Remmbering the data is the offset and the aux the number of rows, we can then read the rows as CSV from the file.

```
julia> prices_for_postcode(idx, "YO8 9YB", csvfile)
7-element CSV.File:
 CSV.Row: (postcode = "YO8 9YB", year = 2000, price = 59500)
 CSV.Row: (postcode = "YO8 9YB", year = 2000, price = 95000)
 CSV.Row: (postcode = "YO8 9YB", year = 2009, price = 230000)
 CSV.Row: (postcode = "YO8 9YB", year = 2014, price = 222000)
 CSV.Row: (postcode = "YO8 9YB", year = 2014, price = 237000)
 CSV.Row: (postcode = "YO8 9YB", year = 2018, price = 142500)
 CSV.Row: (postcode = "YO8 9YB", year = 2021, price = 269950)
```

 We could also create a DataFrame from this data, if we were so inclined
```
julia> LR.prices_for_postcode(idx, "YO8 9YB", csvfile) |> DataFrame
7×3 DataFrame
 Row │ postcode  year   price  
     │ String7   Int64  Int64  
─────┼─────────────────────────
   1 │ YO8 9YB    2000   59500
   2 │ YO8 9YB    2000   95000
   3 │ YO8 9YB    2009  230000
   4 │ YO8 9YB    2014  222000
   5 │ YO8 9YB    2014  237000
   6 │ YO8 9YB    2018  142500
   7 │ YO8 9YB    2021  269950
```

Creating this document revealed that node_range might be broken, so I won't write that up at the moment.

In the future work, I plan to incorprate SeaweedFS into the Index. So we could use this index along with Distributed. But that's another project!

