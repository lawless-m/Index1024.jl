using Documenter
using Index1024
using Dates


makedocs(
    modules = [Index1024],
    sitename="Index1024.jl", 
    authors = "Matt Lawless",
    format = Documenter.HTML(),
)

deploydocs(
    repo = "github.com/lawless-m/Index1024.jl.git", 
    devbranch = "main",
    push_preview = true,
)
