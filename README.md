# Index1024.jl
Write-Once-Read-Many Disk Based B-Tree.

The name comes from deciding to use 1024 byte blocks as pages - the Linux kernel block size - as the memory structure. This turned out to not matter for performance but I've kept it for generating fixed sized pages, loaded on demand. 

I thought aligning them by block size on disk would improve performance but, like many things one imagines, made things worse. I even copied the whole index into RAM disk and it made no difference to the runtime. Either my code is so terrible that it is CPU bound or Linux read-ahead is a great mitigator.

I needed a way to index 10Gb of Read Only data, which is keyed on the range 1 - 999999999999
```
julia> bitstring(999999999999)
"0000000000000000000000001110100011010100101001010000111111111111"
```
The data is also delimited, supplied in a CSV file.
e.g.
```
10024655943,88253,7678,"TR22 0PL","E99999999","E99999999","E06000053","E05011091","E04012730","E18000010","E92000001","E12000009","E14000964","E15000009","E30000252","E06000053","E99999999","E00096400","E01019077","E02006781","E33050815","E38000089","E34999999","E35999999","E2","1B3","E37000005","","E23000035",22165192000016,88276,8001,"TR22 0PL","E99999999","E99999999","E06000053","E05011091","E04012730","E18000010","E92000001","E12000009","E14000964","E15000009","E30000252","E06000053","E99999999","E00096400","E01019077","E02006781","E33050815","E38000089","E34999999","E35999999","E2","1B3","E37000005","","E23000035",22165
```
I might index the CSV file, or not, that's not relevant to the index, the leaf node will contain whatever that ends up being.

[![Build Status](https://github.com/lawless-m/Index1024.jl/actions/workflows/CI.yml/badge.svg?branch=main)](https://github.com/lawless-m/Index1024.jl/actions/workflows/CI.yml?query=branch%3Amain)

https://lawless-m.github.io/Index1024.jl/

# Future Work

1) Keeping the 1k block size, I want to experiment and use SeaweedFS and store the pages individually and use SeaweedFS FIDs instead of file pointer positions to read new pages. 

2) Perhaps this will make it possible to update the index by re-writing on insert. 

I've started the works on a SeaweedFS client

https://github.com/lawless-m/SeaweedFSClient.jl

