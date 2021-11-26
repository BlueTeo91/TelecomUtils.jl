### A Pluto.jl notebook ###
# v0.17.2

# using Markdown
# using InteractiveUtils

# ╔═╡ 74975885-9a4e-4857-8135-9e4f69061caf
begin
	using DocStringExtensions
	using StaticArrays
	using LinearAlgebra
end

# ╔═╡ c0a30957-4c7b-4d7b-bfa9-c2fb691a077b
#=╠═╡ notebook_exclusive
begin
	using PlutoUtils
	using PlotlyBase
	using BenchmarkTools
end
  ╠═╡ notebook_exclusive =#

# ╔═╡ 379613ec-0973-4000-ae8c-d7c33ddca18e
#=╠═╡ notebook_exclusive
md"""
# Packages
"""
  ╠═╡ notebook_exclusive =#

# ╔═╡ 736b0cf6-bec2-4226-8ef4-70f6a865d34a
#=╠═╡ notebook_exclusive
ToC()
  ╠═╡ notebook_exclusive =#

# ╔═╡ f8243a65-9f5e-464e-bb06-0bb4f5131b8b
#=╠═╡ notebook_exclusive
md"""
# Exports
"""
  ╠═╡ notebook_exclusive =#

# ╔═╡ 8660a7c4-eb78-4e7c-966b-d759df7f3dfa
#=╠═╡ notebook_exclusive
md"""
# Lattice Functions
"""
  ╠═╡ notebook_exclusive =#

# ╔═╡ 71163795-9695-4f11-acc2-6e3838c8a158
#=╠═╡ notebook_exclusive
md"""
## generate\_regular_lattice
"""
  ╠═╡ notebook_exclusive =#

# ╔═╡ da97848f-a7ff-4f2d-b98d-e8bf1ccc3038
function lattice_generator(dx::T, dy::T, ds::T;x0::T = T(0), y0::T = T(0), M::Int = 70,N::Int = M) where T<:Real
	# Function to generate x position as function of row,column number m,n
	x(m, n) = m * dx + n * ds + x0
	# Function to generate y position as function of row,column number m,n
	y(n) = n * dy + y0
	# Generate the elements. For each row, shift the columns to always have the search domain around x=0
	gen = ((x(m - round(Int,n * ds / dx), n), y(n)) for n in -N:N,m in -M:M)
	return gen
end

# ╔═╡ f8a53711-e07f-4b6b-84ea-803679496571
"""
Generate a regular lattice of points
$(TYPEDSIGNATURES)

# Arguments
- `dx` → element spacing on the x axis
- `dy` → element spacing on the y axis
- `ds` → displacement along x between rows of elements
- `f_cond::Function` → function of two arguments (`f(x,y) = ...`) returning `true` if element at position `x,y` must be kept and `false` otherwise

# Keyord Arguments
- `x0 = 0` → x coordinate of the origin of the lattice
- `y0 = 0` → y coordinate of the origin of the lattice
- `M::Int = 70` → Number of elements to generate per row of points before appliying the filtering function `f_cond`
- `N::Int = M` → Number of rows of points to generate before appliying the filtering function `f_cond`
"""
function generate_regular_lattice(dx::T, dy::T, ds::T, f_cond::Function = (x, y) -> true;x0::T = T(0), y0::T = T(0), M::Int = 70,N::Int = M) where T<:Real
	gen = lattice_generator(dx, dy, ds; x0, y0, M, N)
	return [x for x ∈ gen if f_cond(x...)]
end

# ╔═╡ ce22b91e-6bba-4312-a89b-1a78f84034d3
function regular_lattice_nelements(dx::T, dy::T, ds::T, f_cond::Function = (x, y) -> true;x0::T = T(0), y0::T = T(0), M::Int = 70,N::Int = M) where T<:Real
	gen = lattice_generator(dx, dy, ds; x0, y0, M, N)
	sum(x -> f_cond(x...), gen)
end

# ╔═╡ 0eb5d19d-b535-4cda-a89b-26ba295e2711
generate_regular_lattice(dx::Real,dy::Real,ds::Real,args...;kwargs...) = generate_regular_lattice(promote(dx,dy,ds)...,args...;kwargs...)

# ╔═╡ 2ba73b51-ecb9-4632-9f39-bdaeb8c5bd34
#=╠═╡ notebook_exclusive
@benchmark generate_square_lattice(1, (x,y) -> x^2 + y^2 < 100)
  ╠═╡ notebook_exclusive =#

# ╔═╡ f0834b38-8efe-4e77-b0f9-47e5b7595191
#=╠═╡ notebook_exclusive
md"""
## generate\_rect_lattice
"""
  ╠═╡ notebook_exclusive =#

# ╔═╡ 9e5db472-f96a-4acb-96ae-024b5c73a93d
"""
    generate_rect_lattice(spacing_x::Real,spacing_y::Real[,f_cond];kwargs...)
# Summary
Generate a rectangular lattice of points (with different spacing among x and y directions)
# Arguments
- `spacing_x` → spacing between points on the x axis
- `spacing_y` → spacing between points on the y axis

See [`generate_regular_lattice`](@ref) for a description of `f_cond` and of  the keyword arguments
"""
generate_rect_lattice(spacing_x::Real,spacing_y::Real,args...;kwargs...) = generate_regular_lattice(spacing_x,spacing_y,0,args...;kwargs...)

# ╔═╡ c41f9f41-d8bd-4001-98cb-2ab788404b1b
#=╠═╡ notebook_exclusive
md"""
## generate\_square\_lattice
"""
  ╠═╡ notebook_exclusive =#

# ╔═╡ 8787134f-9d14-4329-8dda-72557e3175b8
"""
`generate_square_lattice(spacing::Real[,f_cond];kwargs...)`
# Summary
Generate a square lattice of points (with equal spacing among x and y directions)
# Arguments
- `spacing` → spacing between points on both x and y axis

See [`generate_regular_lattice`](@ref) for a description of `f_cond` and of  the keyword arguments
"""
generate_square_lattice(spacing::Real,args...;kwargs...) = generate_regular_lattice(spacing,spacing,0,args...;kwargs...)

# ╔═╡ f589306c-919d-468a-a0fd-9367acc36a7b
#=╠═╡ notebook_exclusive
md"""
## generate\_hex\_lattice
"""
  ╠═╡ notebook_exclusive =#

# ╔═╡ 6ca05079-4c0d-4c45-8486-a4291310189d
"""
`generate_hex_lattice(spacing::Real[,f_cond];kwargs...)`
# Summary
Generate a hexagonal lattice of points (with equal distance between neighboring points).
The hexagonal lattice generated by this function has distance between points on the same
column √3 times greater than the distance between points on the same row.
# Arguments
- `spacing` → spacing between points

See [`generate_regular_lattice`](@ref) for a description of `f_cond` and of  the keyword arguments
"""
generate_hex_lattice(spacing::Real,args...;kwargs...) = generate_regular_lattice(spacing .* (1,√3/2,.5)...,args...;kwargs...)

# ╔═╡ 243621c4-245a-4267-9bb4-568e673450fa
#=╠═╡ notebook_exclusive
generate_hex_lattice(1;M=20, x0 = .5) |> x -> scatter(x; mode="markers") |> Plot
  ╠═╡ notebook_exclusive =#

# ╔═╡ 059045e0-9acc-438d-b3f5-602f8d5892f7
#=╠═╡ notebook_exclusive
md"""
# Misc Functions
"""
  ╠═╡ notebook_exclusive =#

# ╔═╡ 2f1f02c5-3ea5-40c1-8fae-704d150036e6
# Get the conversion from linear to db and viceversa
"""
$(TYPEDSIGNATURES)
Convert a number from linear to dB
"""
lin2db(x::Real) = 10log10(x)

# ╔═╡ 5be397fe-a531-423c-8be0-5d31df79dd2f
"""
$(TYPEDSIGNATURES)
Convert a number from dB to linear
"""
db2lin(x::Real) = 10^(x/10)

# ╔═╡ b2e80c33-bbfe-43ca-8795-c9d8d6fa52a9
# Convert between frequency and wavelength
"""
$(TYPEDSIGNATURES)
Get the wavelength (in m) starting from the frequency (in Hz)
"""
f2λ(f::Real) = c₀/f

# ╔═╡ 9165c4d4-69b5-456c-813c-4725feeb5b52
"""
$(TYPEDSIGNATURES)
Get the frequency (in Hz) starting from the wavelength (in m) 
"""
λ2f(λ::Real) = c₀/λ

# ╔═╡ a5ca5a8a-8497-41e2-9af0-92db5db9ce73
#=╠═╡ notebook_exclusive
md"""
# Generate Colors
"""
  ╠═╡ notebook_exclusive =#

# ╔═╡ 3f2a31d4-0fa8-40fa-9dc4-bd6a26d2ddc9
# Initialize the vector that contains the matrix to compute the beam coloring. We limit ourselves at 500 colors to start
const F_reuse_matrix = (square = SMatrix{2,2,Float64,4}[], triangular = SMatrix{2,2,Float64,4}[])

# ╔═╡ 6b9beb62-dc7e-4b8b-9b7c-8fee5b1da98f
function _coloring_inner_bruteforce!(T_mat, rot_mat, grid_max)
    max_colours = length(T_mat)
    check_vec = fill((typemax(Int),typemax(Int)),max_colours)
    @inline norm2(x) = sum(abs2.(x))
    @inbounds for x1 = 0:grid_max, y1 = 0:grid_max, x2 = -grid_max:grid_max, y2 = 0:grid_max
        mat = @SMatrix [x1 y1;x2 y2]
        # Compute the determinant
        t_det = Int(det(mat))
        # Skip points which are not likely to give useful results
        if (t_det < 1)  || (t_det > max_colours) || (t_det > grid_max^2) || (maximum(abs.(mat)) > ceil(sqrt(t_det) + 3))
            continue
        end
        # Compute the angle between the basis vectors identified by [x1,y1] and [x2,y2]
        angle = abs(atan(y1,x1) - atan(y2,x2))
        # Skip cases where the angle between vectors is either too acute or too obtuse
        if abs(π/2-angle) > π/4
            continue
        end
        # Create temp variables for computation of the minimum distance
        dmat = mat*rot_mat
        # Compute frobenius norm and minimum squared distance for the candidate lattice generating matrix
        frobe = round(Int,norm2(dmat))
        # display(frobe)
        # Minimum squared distance is either the modulo of one of the vectors or the modulo of sum or difference of them
        dmin = round(Int,minimum((norm2(dmat[1,:]), norm2(dmat[2,:]), norm2(sum(dmat;dims=1)), norm2(diff(dmat;dims=1)))))
        # Check if the current realization is better than the saved one
        if isless((-dmin,frobe),check_vec[t_det])
            # Update the check_vec
            check_vec[t_det] = (-dmin,frobe)
            # Update the vector containing the generating matrices
            T_mat[t_det] = mat'
        end
    end
end

# ╔═╡ 14cb2a0b-2ea8-471b-987f-1647f1516992
## Here we have the functions for the coloring computation
function compute_F_cell(max_colours::Int;grid_max::Int=25)
    #=
    This function is used to compute all the possible 2x2 lattice generating matrices for possible coloring schemes up to 'max_colours' colors
    Computation is done with a brute-force approach, generating all possible 2x1 vectors with maximum elements up to grid_max
    =#
    
    # Find the current length of the pre-computed vector
    current_length = length(F_reuse_matrix.square)
    if current_length >= max_colours
        # We already computed the function for the required number of colors
        return
    end
    n_missing = max_colours - current_length
    append!(F_reuse_matrix.square,Vector{SMatrix{2,2,Float64,4}}(undef,n_missing))
    append!(F_reuse_matrix.triangular,Vector{SMatrix{2,2,Float64,4}}(undef,n_missing))
    # Compute the matrix for the square lattice
    _coloring_inner_bruteforce!(F_reuse_matrix.square,I,grid_max)
    # Compute the matrix for the triangular lattice
    _coloring_inner_bruteforce!(F_reuse_matrix.triangular,@SMatrix([1 0;cosd(60) sind(60)]),grid_max)
end

# ╔═╡ 1d44cf1c-11a5-4366-94f3-85b695c6ca12
function generate_F_reuse_matrix(lattice_type::Symbol=:triangular,N_Colours::Int=4;max_colours::Int=max(10,N_Colours))
    compute_F_cell(max_colours)
    return getproperty(F_reuse_matrix,lattice_type)[N_Colours]
end

# ╔═╡ 7e68054e-4268-424e-b413-ef18baf832ac
"""
    generate_colors(BeamCenters::AbstractVector,N_Colours::Int=4;lattice_type::Symbol=:triangular)   

Provide a the coloring breakdown for a given set of lattice points.
# Arguments
- `BeamCenters` → Vector of Tuple or StaticVectors expressing the U-V coordinates of each point in the lattice for which the coloring is being computed
- `N_Colours` → Number of colors to divide the lattice in. Defaults to `4`

# keyword Arguments
- `lattice_type` → Symbol that can either be `:triangular` or `:square`, idenifying the type of lattice. Defaults to `:triangular`
"""
function generate_colors(BeamCenters::AbstractVector,N_Colours::Int=4;first_color_coord=nothing,first_color_idx=nothing,precision_digits::Int=7,lattice_type::Symbol=:triangular)
    #=
    **************************************************************************
       Generate frequency colouring file
    **************************************************************************

     References:
     [1]   "On the frequency allocation for mobile radio telephone systems", C. de
           Almeida; R. Palazzo, Proceedings of 6th International Symposium on
           Personal, Indoor and Mobile Radio Communications, Year: 1995, Volume: 1, Pages: 96 - 99 vol.1
     [2]   P. Angeletti, "Simple implementation of vectorial modulo operation based
           on fundamental parallelepiped," in Electronics Letters, vol. 48, no. 3, pp. 159-160,
           February 2 2012. doi: 10.1049/el.2011.3667

     Authors: Alberto Mengali, 2020, European Space Agency

    Input Arguments:
    BeamCenters:         A vector containing the U,V coordinates of the beam centers as tuples or staticvectors
    N_Colours:           An integer number specifying the number of colors to generate in the association
    first_color_coord:   A tuple or static vector containing the U,V coordinates of the beam that will have the first color
    first_color_idx:     The beam index of the beam containing the first color, either this variable of first_order_coord can be specified, not together
    precision_digits:    The number of digits to be used in the flooring operation
    =#

    # Check if either the first color coordinates or first color idx are given
    if first_color_coord === nothing
        if first_color_idx === nothing
            # Initialize to coorinates of the first beam
            first_color_idx = 1;
        end
        first_color_coord = BeamCenters[first_color_idx]
    else
        if first_color_idx !== nothing
            @warn "Both first_color_idx and first_color_coord were given, disregarding the idx variable"
        end
    end
    if lattice_type ∉ (:triangular, :square)
        @error "The specified lattice type ($lattice_type) is not recognized, it should be either :triangular or :square"
    end

    n_beams = length(BeamCenters)

    # If only 1 color is requested, simply return the trivial result
    if N_Colours == 1
        Colours = ones(n_beams)
        nbeams_per_color = n_beams
        idxs = fill(fill(true,nbeams))
    end

    # Find the minimum distance in U and V
    minU_dist = minimum(diff(sort(first.(BeamCenters)) |> x -> unique!(y -> round(y;digits=precision_digits),x)))
    minV_dist = minimum(diff(sort(last.(BeamCenters)) |> x -> unique!(y -> round(y;digits=precision_digits),x)))
    if lattice_type === :triangular
        beamU_spacing = 2minU_dist
        beamV_spacing = 2minV_dist
        # Matrix to normalize the grid points in u-v into a integer grid with y(v) axis not pointing north but north-east with 60° inclination
        D = @SMatrix [1 -1/2;0 1]
    elseif lattice_type === :square
        beamU_spacing = minU_dist
        beamV_spacing = minV_dist
        D = @SMatrix [1 0;0 1]
    end
    # Get the coloring generating matrix
    F_reuse_matrix = generate_F_reuse_matrix(lattice_type,N_Colours)
    # Create the set that will contain the unique results
    unique_colors_vecs = SVector{2,Int}[]
    # Initialize the colors vector
    Colors = similar(BeamCenters, Int)
    @inbounds for (n,p₀) ∈ enumerate(BeamCenters)
        # Compute the integer beam centers
        p₀_normalized = p₀ ./ SA_F64[beamU_spacing, minV_dist]
        # Transform the beam centers from u-v coordinates in radians into integer indexes
        beam_index_vector = round.(Int,D*p₀_normalized);
        # Find the values of the beam indexes modulo F_reuse_matrix
        unique_beam_index = round.(Int,beam_index_vector .- (F_reuse_matrix*floor.(round.(inv(F_reuse_matrix)*beam_index_vector,digits=precision_digits))))
        # Check if this color has already been assigned/registered
        idx = findfirst(x -> x == unique_beam_index,unique_colors_vecs)
        if idx isa Nothing
            push!(unique_colors_vecs, unique_beam_index)
            cidx = length(unique_colors_vecs)
        else
            cidx = idx
        end
        Colors[n] = cidx
    end
    
    return Colors
end

# ╔═╡ d8584d03-8eb4-4864-b646-a6a0656a2e12
begin
	export generate_regular_lattice, generate_square_lattice, generate_hex_lattice, generate_rect_lattice
	export generate_colors
	export f2λ, λ2f, db2lin, lin2db
end

# ╔═╡ 8160086a-6349-447c-87ae-880b02fa97f5
#=╠═╡ notebook_exclusive
md"""
# Tests
"""
  ╠═╡ notebook_exclusive =#

# ╔═╡ 3ea0415c-af14-430c-bf7c-2c7d71b7a333
#=╠═╡ notebook_exclusive
let
	N_colors = 6
	lat = generate_hex_lattice(1; M = 10)
	colors = generate_colors(lat,N_colors)	
	data = scatter(lat;mode="markers", marker_color = colors)
	Plot(data)
end
  ╠═╡ notebook_exclusive =#

# ╔═╡ 65b74f4a-e2af-4caf-8719-5a59c6349bb9
#=╠═╡ notebook_exclusive
let
	N_colors = 4
	lat = generate_square_lattice(1; M = 10)
	colors = generate_colors(lat,N_colors; lattice_type = :square)	
	data = scatter(lat;mode="markers", marker_color = colors)
	Plot(data)
end
  ╠═╡ notebook_exclusive =#

# ╔═╡ 00000000-0000-0000-0000-000000000001
PLUTO_PROJECT_TOML_CONTENTS = """
[deps]
BenchmarkTools = "6e4b80f9-dd63-53aa-95a3-0cdb28fa8baf"
DocStringExtensions = "ffbed154-4ef7-542d-bbb7-c09d3a79fcae"
LinearAlgebra = "37e2e46d-f89d-539d-b4ee-838fcccc9c8e"
PlotlyBase = "a03496cd-edff-5a9b-9e67-9cda94a718b5"
PlutoUtils = "ed5d0301-4775-4676-b788-cf71e66ff8ed"
StaticArrays = "90137ffa-7385-5640-81b9-e52037218182"

[compat]
BenchmarkTools = "~1.2.0"
DocStringExtensions = "~0.8.6"
PlotlyBase = "~0.8.18"
PlutoUtils = "~0.4.13"
StaticArrays = "~1.2.13"
"""

# ╔═╡ 00000000-0000-0000-0000-000000000002
PLUTO_MANIFEST_TOML_CONTENTS = """
# This file is machine-generated - editing it directly is not advised

julia_version = "1.7.0-rc2"
manifest_format = "2.0"

[[deps.AbstractPlutoDingetjes]]
deps = ["Pkg"]
git-tree-sha1 = "0bc60e3006ad95b4bb7497698dd7c6d649b9bc06"
uuid = "6e696c72-6542-2067-7265-42206c756150"
version = "1.1.1"

[[deps.ArgTools]]
uuid = "0dad84c5-d112-42e6-8d28-ef12dabb789f"

[[deps.Artifacts]]
uuid = "56f22d72-fd6d-98f1-02f0-08ddc0907c33"

[[deps.Base64]]
uuid = "2a0f44e3-6c83-55bd-87e4-b1978d98bd5f"

[[deps.BenchmarkTools]]
deps = ["JSON", "Logging", "Printf", "Profile", "Statistics", "UUIDs"]
git-tree-sha1 = "61adeb0823084487000600ef8b1c00cc2474cd47"
uuid = "6e4b80f9-dd63-53aa-95a3-0cdb28fa8baf"
version = "1.2.0"

[[deps.Chain]]
git-tree-sha1 = "cac464e71767e8a04ceee82a889ca56502795705"
uuid = "8be319e6-bccf-4806-a6f7-6fae938471bc"
version = "0.4.8"

[[deps.ColorSchemes]]
deps = ["ColorTypes", "Colors", "FixedPointNumbers", "Random"]
git-tree-sha1 = "a851fec56cb73cfdf43762999ec72eff5b86882a"
uuid = "35d6a980-a343-548e-a6ea-1d62b119f2f4"
version = "3.15.0"

[[deps.ColorTypes]]
deps = ["FixedPointNumbers", "Random"]
git-tree-sha1 = "024fe24d83e4a5bf5fc80501a314ce0d1aa35597"
uuid = "3da002f7-5984-5a60-b8a6-cbb66c0b333f"
version = "0.11.0"

[[deps.Colors]]
deps = ["ColorTypes", "FixedPointNumbers", "Reexport"]
git-tree-sha1 = "417b0ed7b8b838aa6ca0a87aadf1bb9eb111ce40"
uuid = "5ae59095-9a9b-59fe-a467-6f913c188581"
version = "0.12.8"

[[deps.CompilerSupportLibraries_jll]]
deps = ["Artifacts", "Libdl"]
uuid = "e66e0078-7015-5450-92f7-15fbd957f2ae"

[[deps.Crayons]]
git-tree-sha1 = "3f71217b538d7aaee0b69ab47d9b7724ca8afa0d"
uuid = "a8cc5b0e-0ffa-5ad4-8c14-923d3ee1735f"
version = "4.0.4"

[[deps.DataAPI]]
git-tree-sha1 = "cc70b17275652eb47bc9e5f81635981f13cea5c8"
uuid = "9a962f9c-6df0-11e9-0e5d-c546b8b5ee8a"
version = "1.9.0"

[[deps.DataValueInterfaces]]
git-tree-sha1 = "bfc1187b79289637fa0ef6d4436ebdfe6905cbd6"
uuid = "e2d170a0-9d28-54be-80f0-106bbe20a464"
version = "1.0.0"

[[deps.Dates]]
deps = ["Printf"]
uuid = "ade2ca70-3891-5945-98fb-dc099432e06a"

[[deps.DelimitedFiles]]
deps = ["Mmap"]
uuid = "8bb1440f-4735-579b-a4ab-409b98df4dab"

[[deps.DocStringExtensions]]
deps = ["LibGit2"]
git-tree-sha1 = "b19534d1895d702889b219c382a6e18010797f0b"
uuid = "ffbed154-4ef7-542d-bbb7-c09d3a79fcae"
version = "0.8.6"

[[deps.Downloads]]
deps = ["ArgTools", "LibCURL", "NetworkOptions"]
uuid = "f43a241f-c20a-4ad4-852c-f6b1247861c6"

[[deps.FileWatching]]
uuid = "7b1f6079-737a-58dc-b8bc-7a2ca5c1b5ee"

[[deps.FixedPointNumbers]]
deps = ["Statistics"]
git-tree-sha1 = "335bfdceacc84c5cdf16aadc768aa5ddfc5383cc"
uuid = "53c48c17-4a7d-5ca2-90c5-79b7896eea93"
version = "0.8.4"

[[deps.Formatting]]
deps = ["Printf"]
git-tree-sha1 = "8339d61043228fdd3eb658d86c926cb282ae72a8"
uuid = "59287772-0a20-5a39-b81b-1366585eb4c0"
version = "0.4.2"

[[deps.Glob]]
git-tree-sha1 = "4df9f7e06108728ebf00a0a11edee4b29a482bb2"
uuid = "c27321d9-0574-5035-807b-f59d2c89b15c"
version = "1.3.0"

[[deps.Hyperscript]]
deps = ["Test"]
git-tree-sha1 = "8d511d5b81240fc8e6802386302675bdf47737b9"
uuid = "47d2ed2b-36de-50cf-bf87-49c2cf4b8b91"
version = "0.0.4"

[[deps.HypertextLiteral]]
git-tree-sha1 = "2b078b5a615c6c0396c77810d92ee8c6f470d238"
uuid = "ac1192a8-f4b3-4bfe-ba22-af5b92cd3ab2"
version = "0.9.3"

[[deps.IOCapture]]
deps = ["Logging", "Random"]
git-tree-sha1 = "f7be53659ab06ddc986428d3a9dcc95f6fa6705a"
uuid = "b5f81e59-6552-4d32-b1f0-c071b021bf89"
version = "0.2.2"

[[deps.InteractiveUtils]]
deps = ["Markdown"]
uuid = "b77e0a4c-d291-57a0-90e8-8db25a27a240"

[[deps.IteratorInterfaceExtensions]]
git-tree-sha1 = "a3f24677c21f5bbe9d2a714f95dcd58337fb2856"
uuid = "82899510-4779-5014-852e-03e436cf321d"
version = "1.0.0"

[[deps.JSON]]
deps = ["Dates", "Mmap", "Parsers", "Unicode"]
git-tree-sha1 = "8076680b162ada2a031f707ac7b4953e30667a37"
uuid = "682c06a0-de6a-54ab-a142-c8b1cf79cde6"
version = "0.21.2"

[[deps.LaTeXStrings]]
git-tree-sha1 = "f2355693d6778a178ade15952b7ac47a4ff97996"
uuid = "b964fa9f-0449-5b57-a5c2-d3ea65f4040f"
version = "1.3.0"

[[deps.LibCURL]]
deps = ["LibCURL_jll", "MozillaCACerts_jll"]
uuid = "b27032c2-a3e7-50c8-80cd-2d36dbcbfd21"

[[deps.LibCURL_jll]]
deps = ["Artifacts", "LibSSH2_jll", "Libdl", "MbedTLS_jll", "Zlib_jll", "nghttp2_jll"]
uuid = "deac9b47-8bc7-5906-a0fe-35ac56dc84c0"

[[deps.LibGit2]]
deps = ["Base64", "NetworkOptions", "Printf", "SHA"]
uuid = "76f85450-5226-5b5a-8eaa-529ad045b433"

[[deps.LibSSH2_jll]]
deps = ["Artifacts", "Libdl", "MbedTLS_jll"]
uuid = "29816b5a-b9ab-546f-933c-edad1886dfa8"

[[deps.Libdl]]
uuid = "8f399da3-3557-5675-b5ff-fb832c97cbdb"

[[deps.LinearAlgebra]]
deps = ["Libdl", "libblastrampoline_jll"]
uuid = "37e2e46d-f89d-539d-b4ee-838fcccc9c8e"

[[deps.Logging]]
uuid = "56ddb016-857b-54e1-b83d-db4d58db5568"

[[deps.MacroTools]]
deps = ["Markdown", "Random"]
git-tree-sha1 = "3d3e902b31198a27340d0bf00d6ac452866021cf"
uuid = "1914dd2f-81c6-5fcd-8719-6d5c9610ff09"
version = "0.5.9"

[[deps.Markdown]]
deps = ["Base64"]
uuid = "d6f4376e-aef5-505a-96c1-9c027394607a"

[[deps.MbedTLS_jll]]
deps = ["Artifacts", "Libdl"]
uuid = "c8ffd9c3-330d-5841-b78e-0817d7145fa1"

[[deps.Mmap]]
uuid = "a63ad114-7e13-5084-954f-fe012c677804"

[[deps.MozillaCACerts_jll]]
uuid = "14a3606d-f60d-562e-9121-12d972cd8159"

[[deps.NetworkOptions]]
uuid = "ca575930-c2e3-43a9-ace4-1e988b2c1908"

[[deps.OpenBLAS_jll]]
deps = ["Artifacts", "CompilerSupportLibraries_jll", "Libdl"]
uuid = "4536629a-c528-5b80-bd46-f80d51c5b363"

[[deps.OrderedCollections]]
git-tree-sha1 = "85f8e6578bf1f9ee0d11e7bb1b1456435479d47c"
uuid = "bac558e1-5e72-5ebc-8fee-abe8a469f55d"
version = "1.4.1"

[[deps.Parameters]]
deps = ["OrderedCollections", "UnPack"]
git-tree-sha1 = "34c0e9ad262e5f7fc75b10a9952ca7692cfc5fbe"
uuid = "d96e819e-fc66-5662-9728-84c9c7592b0a"
version = "0.12.3"

[[deps.Parsers]]
deps = ["Dates"]
git-tree-sha1 = "ae4bbcadb2906ccc085cf52ac286dc1377dceccc"
uuid = "69de0a69-1ddd-5017-9359-2bf0b02dc9f0"
version = "2.1.2"

[[deps.Pkg]]
deps = ["Artifacts", "Dates", "Downloads", "LibGit2", "Libdl", "Logging", "Markdown", "Printf", "REPL", "Random", "SHA", "Serialization", "TOML", "Tar", "UUIDs", "p7zip_jll"]
uuid = "44cfe95a-1eb2-52ea-b672-e2afdf69b78f"

[[deps.PlotlyBase]]
deps = ["ColorSchemes", "Dates", "DelimitedFiles", "DocStringExtensions", "JSON", "LaTeXStrings", "Logging", "Parameters", "Pkg", "REPL", "Requires", "Statistics", "UUIDs"]
git-tree-sha1 = "180d744848ba316a3d0fdf4dbd34b77c7242963a"
uuid = "a03496cd-edff-5a9b-9e67-9cda94a718b5"
version = "0.8.18"

[[deps.PlutoDevMacros]]
deps = ["MacroTools", "PlutoHooks"]
git-tree-sha1 = "7392720177703062cb2e2a0115efb77dc5dc818c"
uuid = "a0499f29-c39b-4c5c-807c-88074221b949"
version = "0.3.7"

[[deps.PlutoHooks]]
deps = ["FileWatching", "InteractiveUtils", "Markdown", "UUIDs"]
git-tree-sha1 = "f297787f7d7507dada25f6769fe3f08f6b9b8b12"
uuid = "0ff47ea0-7a50-410d-8455-4348d5de0774"
version = "0.0.3"

[[deps.PlutoTest]]
deps = ["HypertextLiteral", "InteractiveUtils", "Markdown", "Test"]
git-tree-sha1 = "92b8ae1eee37c1b8f70d3a8fb6c3f2d81809a1c5"
uuid = "cb4044da-4d16-4ffa-a6a3-8cad7f73ebdc"
version = "0.2.0"

[[deps.PlutoUI]]
deps = ["AbstractPlutoDingetjes", "Base64", "Dates", "Hyperscript", "HypertextLiteral", "IOCapture", "InteractiveUtils", "JSON", "Logging", "Markdown", "Random", "Reexport", "UUIDs"]
git-tree-sha1 = "e071adf21e165ea0d904b595544a8e514c8bb42c"
uuid = "7f904dfe-b85e-4ff6-b463-dae2292396a8"
version = "0.7.19"

[[deps.PlutoUtils]]
deps = ["Chain", "Glob", "HypertextLiteral", "InteractiveUtils", "Markdown", "PlutoDevMacros", "PlutoHooks", "PlutoTest", "PlutoUI", "PrettyTables", "Reexport", "Requires", "UUIDs"]
git-tree-sha1 = "3d3856ecfea340b4ee0c77e5c3228dd1b4478ae1"
uuid = "ed5d0301-4775-4676-b788-cf71e66ff8ed"
version = "0.4.13"

[[deps.PrettyTables]]
deps = ["Crayons", "Formatting", "Markdown", "Reexport", "Tables"]
git-tree-sha1 = "d940010be611ee9d67064fe559edbb305f8cc0eb"
uuid = "08abe8d2-0d0c-5749-adfa-8a2ac140af0d"
version = "1.2.3"

[[deps.Printf]]
deps = ["Unicode"]
uuid = "de0858da-6303-5e67-8744-51eddeeeb8d7"

[[deps.Profile]]
deps = ["Printf"]
uuid = "9abbd945-dff8-562f-b5e8-e1ebf5ef1b79"

[[deps.REPL]]
deps = ["InteractiveUtils", "Markdown", "Sockets", "Unicode"]
uuid = "3fa0cd96-eef1-5676-8a61-b3b8758bbffb"

[[deps.Random]]
deps = ["SHA", "Serialization"]
uuid = "9a3f8284-a2c9-5f02-9a11-845980a1fd5c"

[[deps.Reexport]]
git-tree-sha1 = "45e428421666073eab6f2da5c9d310d99bb12f9b"
uuid = "189a3867-3050-52da-a836-e630ba90ab69"
version = "1.2.2"

[[deps.Requires]]
deps = ["UUIDs"]
git-tree-sha1 = "4036a3bd08ac7e968e27c203d45f5fff15020621"
uuid = "ae029012-a4dd-5104-9daa-d747884805df"
version = "1.1.3"

[[deps.SHA]]
uuid = "ea8e919c-243c-51af-8825-aaa63cd721ce"

[[deps.Serialization]]
uuid = "9e88b42a-f829-5b0c-bbe9-9e923198166b"

[[deps.Sockets]]
uuid = "6462fe0b-24de-5631-8697-dd941f90decc"

[[deps.SparseArrays]]
deps = ["LinearAlgebra", "Random"]
uuid = "2f01184e-e22b-5df5-ae63-d93ebab69eaf"

[[deps.StaticArrays]]
deps = ["LinearAlgebra", "Random", "Statistics"]
git-tree-sha1 = "3c76dde64d03699e074ac02eb2e8ba8254d428da"
uuid = "90137ffa-7385-5640-81b9-e52037218182"
version = "1.2.13"

[[deps.Statistics]]
deps = ["LinearAlgebra", "SparseArrays"]
uuid = "10745b16-79ce-11e8-11f9-7d13ad32a3b2"

[[deps.TOML]]
deps = ["Dates"]
uuid = "fa267f1f-6049-4f14-aa54-33bafae1ed76"

[[deps.TableTraits]]
deps = ["IteratorInterfaceExtensions"]
git-tree-sha1 = "c06b2f539df1c6efa794486abfb6ed2022561a39"
uuid = "3783bdb8-4a98-5b6b-af9a-565f29a5fe9c"
version = "1.0.1"

[[deps.Tables]]
deps = ["DataAPI", "DataValueInterfaces", "IteratorInterfaceExtensions", "LinearAlgebra", "TableTraits", "Test"]
git-tree-sha1 = "fed34d0e71b91734bf0a7e10eb1bb05296ddbcd0"
uuid = "bd369af6-aec1-5ad0-b16a-f7cc5008161c"
version = "1.6.0"

[[deps.Tar]]
deps = ["ArgTools", "SHA"]
uuid = "a4e569a6-e804-4fa4-b0f3-eef7a1d5b13e"

[[deps.Test]]
deps = ["InteractiveUtils", "Logging", "Random", "Serialization"]
uuid = "8dfed614-e22c-5e08-85e1-65c5234f0b40"

[[deps.UUIDs]]
deps = ["Random", "SHA"]
uuid = "cf7118a7-6976-5b1a-9a39-7adc72f591a4"

[[deps.UnPack]]
git-tree-sha1 = "387c1f73762231e86e0c9c5443ce3b4a0a9a0c2b"
uuid = "3a884ed6-31ef-47d7-9d2a-63182c4928ed"
version = "1.0.2"

[[deps.Unicode]]
uuid = "4ec0a83e-493e-50e2-b9ac-8f72acf5a8f5"

[[deps.Zlib_jll]]
deps = ["Libdl"]
uuid = "83775a58-1f1d-513f-b197-d71354ab007a"

[[deps.libblastrampoline_jll]]
deps = ["Artifacts", "Libdl", "OpenBLAS_jll"]
uuid = "8e850b90-86db-534c-a0d3-1478176c7d93"

[[deps.nghttp2_jll]]
deps = ["Artifacts", "Libdl"]
uuid = "8e850ede-7688-5339-a07c-302acd2aaf8d"

[[deps.p7zip_jll]]
deps = ["Artifacts", "Libdl"]
uuid = "3f19e933-33d8-53b3-aaab-bd5110c3b7a0"
"""

# ╔═╡ Cell order:
# ╟─379613ec-0973-4000-ae8c-d7c33ddca18e
# ╠═74975885-9a4e-4857-8135-9e4f69061caf
# ╠═c0a30957-4c7b-4d7b-bfa9-c2fb691a077b
# ╠═736b0cf6-bec2-4226-8ef4-70f6a865d34a
# ╟─f8243a65-9f5e-464e-bb06-0bb4f5131b8b
# ╠═d8584d03-8eb4-4864-b646-a6a0656a2e12
# ╟─8660a7c4-eb78-4e7c-966b-d759df7f3dfa
# ╟─71163795-9695-4f11-acc2-6e3838c8a158
# ╠═f8a53711-e07f-4b6b-84ea-803679496571
# ╠═ce22b91e-6bba-4312-a89b-1a78f84034d3
# ╠═da97848f-a7ff-4f2d-b98d-e8bf1ccc3038
# ╠═0eb5d19d-b535-4cda-a89b-26ba295e2711
# ╠═2ba73b51-ecb9-4632-9f39-bdaeb8c5bd34
# ╟─f0834b38-8efe-4e77-b0f9-47e5b7595191
# ╠═9e5db472-f96a-4acb-96ae-024b5c73a93d
# ╟─c41f9f41-d8bd-4001-98cb-2ab788404b1b
# ╠═8787134f-9d14-4329-8dda-72557e3175b8
# ╟─f589306c-919d-468a-a0fd-9367acc36a7b
# ╠═6ca05079-4c0d-4c45-8486-a4291310189d
# ╠═243621c4-245a-4267-9bb4-568e673450fa
# ╟─059045e0-9acc-438d-b3f5-602f8d5892f7
# ╠═2f1f02c5-3ea5-40c1-8fae-704d150036e6
# ╠═5be397fe-a531-423c-8be0-5d31df79dd2f
# ╠═b2e80c33-bbfe-43ca-8795-c9d8d6fa52a9
# ╠═9165c4d4-69b5-456c-813c-4725feeb5b52
# ╟─a5ca5a8a-8497-41e2-9af0-92db5db9ce73
# ╠═3f2a31d4-0fa8-40fa-9dc4-bd6a26d2ddc9
# ╠═14cb2a0b-2ea8-471b-987f-1647f1516992
# ╠═6b9beb62-dc7e-4b8b-9b7c-8fee5b1da98f
# ╠═1d44cf1c-11a5-4366-94f3-85b695c6ca12
# ╠═7e68054e-4268-424e-b413-ef18baf832ac
# ╟─8160086a-6349-447c-87ae-880b02fa97f5
# ╠═3ea0415c-af14-430c-bf7c-2c7d71b7a333
# ╠═65b74f4a-e2af-4caf-8719-5a59c6349bb9
# ╟─00000000-0000-0000-0000-000000000001
# ╟─00000000-0000-0000-0000-000000000002
