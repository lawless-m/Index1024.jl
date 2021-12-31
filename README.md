# Index1024.jl
Disk Block based B-Tree

The name comes from deciding to use 1024 byte blocks as pages - the Linux kernel block size - as the memory structure.

I needed a way to index 10Gb of Read Only data, which is keyed on the range 1 - 999999999999
```
julia> bitstring(999999999999)
"0000000000000000000000001110100011010100101001010000111111111111"
```
The data is also a fixed size record, supplied in a CSV file.
e.g.
```
10024655943,88253,7678,"TR22 0PL","E99999999","E99999999","E06000053","E05011091","E04012730","E18000010","E92000001","E12000009","E14000964","E15000009","E30000252","E06000053","E99999999","E00096400","E01019077","E02006781","E33050815","E38000089","E34999999","E35999999","E2","1B3","E37000005","","E23000035",22165192000016,88276,8001,"TR22 0PL","E99999999","E99999999","E06000053","E05011091","E04012730","E18000010","E92000001","E12000009","E14000964","E15000009","E30000252","E06000053","E99999999","E00096400","E01019077","E02006781","E33050815","E38000089","E34999999","E35999999","E2","1B3","E37000005","","E23000035",22165
```
I might index the CSV file, or not, that's not relevant to the index, the leaf node will contain whatever that ends up being.

[![Build Status](https://github.com/lawless-m/Index1024.jl/actions/workflows/CI.yml/badge.svg?branch=main)](https://github.com/lawless-m/Index1024.jl/actions/workflows/CI.yml?query=branch%3Amain)

https://lawless-m.github.io/Index1024.jl/

