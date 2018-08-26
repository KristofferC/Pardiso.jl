# remove deps.jl if it exists, in case build.jl fails
isfile("deps.jl") && rm("deps.jl")

using Libdl


println("Pardiso library")
println("===============")

const LIBPARDISONAMES =
if Sys.iswindows()
[
    "libpardiso600-WIN-X86-64.dll",
    "libpardiso500-WIN-X86-64.dll",
]
elseif Sys.isapple()
[
    "libpardiso600-MACOS-X86-64.dylib",
    "libpardiso500-MACOS-X86-64.dylib",
]
elseif Sys.islinux()
[
    "libpardiso600-GNU720-X86-64",
    "libpardiso500-GNU461-X86-64",
    "libpardiso500-GNU472-X86-64",
    "libpardiso500-GNU481-X86-64",
]
else
    error("unhandled OS")
end

println("Looking for libraries with name: ", join(LIBPARDISONAMES, ", "), ".")


PATH_PREFIXES = [@__DIR__; get(ENV, "JULIA_PARDISO", [])]

if !haskey(ENV, "JULIA_PARDISO")
    println("INFO: use the `JULIA_PARDISO` environment variable to set a path to " *
            "the folder where the Pardiso library is located")
end

pardiso_version = 0
function find_paradisolib()
    found_lib = false
    for prefix in PATH_PREFIXES
        println("Looking in \"$(abspath(prefix))\" for libraries")
        for libname in LIBPARDISONAMES
            local path
            try
                path = joinpath(prefix, libname)
                if isfile(path)
                    println("    found \"$(abspath(path))\", attempting to load it...")
                    Libdl.dlopen(path, Libdl.RTLD_GLOBAL)
                    println("    loaded successfully!")
                    global PARDISO_LIB_FOUND = true
                    if occursin("600", libname)
                        global pardiso_version = 6
                    else
                        global pardiso_version = 5
                    end
                    return path, true
                end
            catch e
                println("    failed to load due to:")
                Base.showerror(stderr, e)
            end
        end
    end
    println("did not find libpardiso, assuming PARDISO 5/6 is not installed")
    return "", false
end

pardisopath, found_pardisolib = find_paradisolib()

#################################################

println("\nMKL Pardiso")
println("=============")
function find_mklparadiso()
    if haskey(ENV, "MKLROOT")
        println("found MKLROOT environment variable, using it")
        return ENV["MKLROOT"], true
    end
    println("did not find MKLROOT environment variable, assuming MKL is not installed")
    return "", false
end

mklroot, found_mklpardiso = find_mklparadiso()

if !(found_mklpardiso || found_pardisolib)
    println("WARNING: no Pardiso library managed to load")
end

open("deps.jl", "w") do f
    print(f,
"""
const MKL_PARDISO_LIB_FOUND = $found_mklpardiso
const PARDISO_LIB_FOUND = $found_pardisolib
const PARDISO_VERSION = $pardiso_version
const MKLROOT = $(repr(mklroot))
const PARDISO_PATH = raw"$pardisopath"
"""
)

end
