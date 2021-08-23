### A Pluto.jl notebook ###
# v0.15.1

using Markdown
using InteractiveUtils

# ╔═╡ 590cdbce-fc45-11eb-2fde-1d27628251b7
begin
	using PlutoUtils
	using Proj4
	using DocStringExtensions
	using CoordinateTransformations
	using StaticArrays
	using LinearAlgebra
	using Unitful
	using Unitful.DefaultSymbols
	using Rotations
end

# ╔═╡ bcee47c1-81c1-4c77-af09-22c04374fa4f
using Parameters

# ╔═╡ 9e29c3ea-2cda-4726-86a3-20cabdb20245
#=╠═╡ notebook_exclusive
begin
	using BenchmarkTools
	using PlutoTest
end
  ╠═╡ notebook_exclusive =#

# ╔═╡ d56dc0b2-204c-410e-ad75-f6abbdae1f7a
#=╠═╡ notebook_exclusive
using SatelliteToolbox
  ╠═╡ notebook_exclusive =#

# ╔═╡ 74422a23-0760-470f-9e1e-43b8c3972f65
hide_cell_shortcut()

# ╔═╡ 2ad47a80-881a-4ac5-a61e-0691e6bf35e0
initialize_eqref()

# ╔═╡ 77e399b7-0f7e-4ff1-9f8e-fd0f3408e894
ToC()

# ╔═╡ ac5e6327-98a1-478f-be65-05fa1cff717d
md"""
# Functions
"""

# ╔═╡ d5c40459-9894-43a4-81d1-54eeaf9febb2
md"""
Formulas used here are based on the [EPSG guidance note #7-2](https://epsg.org/guidance-notes.html)
"""

# ╔═╡ 367ad569-495a-458b-806d-e5e40db12e1a
md"""
## Exports
"""

# ╔═╡ cc8f63e4-77e4-4bdb-8f40-4e3450007e50
md"""
## Ellipsoid
"""

# ╔═╡ 0202190c-5906-4ca6-9346-71ae4f51bdad
begin
"""
    Ellipsoid{T}

Ellipsoid of rotation to be used for geocentric, geodetic and ecef transformations.

!!! note
    The constructor only accepts the fields `a` and `f`, with the other fields pre-computed 
    automatically from those two

# Fields
- `a` : Semi-major axis [m].
- `f` : Flattening of the ellipsoid.
- `b` : Semi-minor axis [m]
- `e²` : Eccentricity squared
- `el²` : Second Eccentricity squared
"""
struct Ellipsoid{T}
    ## Main Variables
    a::T # Semi-major axis in [m]
    f::T # Flattening of the ellipsoid
    ## Auxiliary variables, pre-computed just for convenience
    b::T # Semi-minor axis in [m]
    e²::T # Eccentricity squared
    el²::T # Second eccentricity squared
    
    ## Constructor
    function Ellipsoid(a,f)
        @assert f < 1 "The flattening should be lower than 1"
        b = a * (1 - f)
        e² = f * (2 - f)
        el² = e² / (1 - e²)
        new{typeof(el²)}(a,f,b,e²,el²)
    end
end
 
"""
    Ellipsoid(a,f)
    Ellipsoid{T}(a,f)

Generate an ellipsoid of rotation ([`Ellipsoid`](@ref)) as a function of the semi-major axis
in [m] and the flattening
"""
Ellipsoid{T}(a,f) where T = Ellipsoid(T(a),T(f))
end

# ╔═╡ 140481fb-9e22-47b8-8118-37811ca04bdd
const wgs84_ellipsoid = Ellipsoid(6378137.0, 1/298.257223563)

# ╔═╡ 0de61675-b5f5-4c57-afdb-f5ae2ff6b0c1
md"""
### Geocentric <-> Geodetic 
"""

# ╔═╡ 6bc1a3ac-414c-422b-9b6f-c7efea145a8c
"""
    ecef_to_geodetic(r_e::AbstractVector; ellipsoid=wgs84_ellipsoid)

Convert the vector `r_e` [m] represented in the Earth-Centered, Earth-Fixed
(ECEF) reference frame into Geodetic coordinates for a custom target ellipsoid
(defaults to WGS-84).

!!! info
    The algorithm is based in **[3]**.

# Returns

* Latitude [°].
* Longitude [°].
* Altitude [m].

# Reference

- **[3]**: mu-blox ag (1999). Datum Transformations of GPS Positions.
    Application Note.
"""
function ecef_to_geodetic(r_e::AbstractVector; ellipsoid = wgs84_ellipsoid)
    # Auxiliary variables.
    X = r_e[1]
    Y = r_e[2]
    Z = r_e[3]

    # Auxiliary variables.
    a = ellipsoid.a
    b = ellipsoid.b
    e² = ellipsoid.e²
    el² = ellipsoid.el²
    p = √(X^2 + Y^2)
    θ = atan(Z * a, p * b)
    sin_θ, cos_θ = sincos(θ)

    # Compute Geodetic.
    lon = atan(Y, X)
    lat = atan(
        Z + el² * b * sin_θ^3,
        p -  e² * a * cos_θ^3
    )

    sin_lat, cos_lat = sincos(lat)

    N = a/√(1 - e² * sin_lat^2)

    # Avoid singularity if we are near the poles (~ 1 deg according to [1,
    # p.172]). Note that `cosd(1) = -0.01745240643728351`.
    if !(-0.01745240643728351 < cos_lat < 0.01745240643728351)
        h = p/cos_lat - N
    else
        h = Z/sin_lat - N*(1 - e²)
    end

    return rad2deg(lat)*°, rad2deg(lon)*°, h*m
end

# ╔═╡ 75d0fc45-87e9-42bc-aab5-dae0cf099eaa
# Overload call with length
ecef_to_geodetic(r_e::AbstractVector{<:Unitful.Length};kwargs...) = ecef_to_geodetic(map(x -> uconvert(u"m",x) |> ustrip,r_e);kwargs...)

# ╔═╡ 34087d1f-9773-4a52-b153-8ffd728deb52
#=╠═╡ notebook_exclusive
@test ecef_to_geodetic([5000km,6000km,5500km]) == ecef_to_geodetic([5000e3,6000e3,5500e3])
  ╠═╡ notebook_exclusive =#

# ╔═╡ efb91b19-8e1e-4a26-ad25-e67f3453c018
"""
    geodetic_to_ecef(lat::Number, lon::Number, h::Number; ellipsoid = wgs84_ellipsoid)

Convert the latitude `lat` [rad], longitude `lon` [rad], and altitude `h` \\[m] above the
reference ellipsoid (defaults to WGS-84) into a vector represented on the Earth-Centered,
Earth-Fixed (ECEF) reference frame.

!!! info
    The algorithm is based in **[3]**.

# Reference

- **[3]**: mu-blox ag (1999). Datum Transformations of GPS Positions.
    Application Note.
"""
function geodetic_to_ecef(lat::Number, lon::Number, h::Number; ellipsoid = wgs84_ellipsoid)
    # Auxiliary variables.
    sin_lat, cos_lat = sincos(lat)
    sin_lon, cos_lon = sincos(lon)
    a = ellipsoid.a
    b = ellipsoid.b
    e² = ellipsoid.e²

    # Radius of curvature [m].
    N = a/√(1 - e² * sin_lat^2)

    # Compute the position in ECEF frame.
    return SVector(
        (N + h) * cos_lat * cos_lon,
        (N + h) * cos_lat * sin_lon,
        ((b / a)^2 * N + h) * sin_lat
    )
end

# ╔═╡ b15e13ab-71e3-4b78-a9d4-377d113e007c
# Method with altitude in Unitful.Length
geodetic_to_ecef(lat::Number,lon::Number,alt::Unitful.Length;kwargs...) = geodetic_to_ecef(lat,lon,uconvert(u"m",alt) |> ustrip;kwargs...)

# ╔═╡ 1fc544b8-9d87-4d16-a7f3-93bd533db412
md"""
## Override Proj4 definition
"""

# ╔═╡ f359e8fd-b75f-41ed-a847-9e8b2e3da150
md"""
The current definition of the `_geod_inverse` function in Proj4 expects a Vector rather than an AbstractVector of latlon positions, so it does not support StaticVectors.

We just override that specific function to accept AbstractVectors
"""

# ╔═╡ e03bb946-7060-436a-9959-04c0a3f32ddf
@eval Proj4 function _geod_inverse(geod::Proj4.geod_geodesic, lonlat1::AbstractVector{Cdouble}, lonlat2::AbstractVector{Cdouble})
    dist = Ref{Cdouble}()
    azi1 = Ref{Cdouble}()
    azi2 = Ref{Cdouble}()
    ccall((:geod_inverse, libproj), Cvoid, (Ptr{Cvoid},Cdouble,Cdouble,Cdouble,
          Cdouble,Ptr{Cdouble},Ptr{Cdouble},Ptr{Cdouble}),
          pointer_from_objref(geod), lonlat1[2], lonlat1[1], lonlat2[2], lonlat2[1], dist, azi1, azi2)
    dist[], azi1[], azi2[]
end

# ╔═╡ bf534d5c-b861-4c4c-b645-7848b3eaf0fe
md"""
## LLA
"""

# ╔═╡ f0758e99-9f2b-4934-88eb-7e62cdd5c51f
md"""
Here we want to define a structure that contains useful informations and functions to perform conversions between the view from the satellite based on it's orbital position and points on ground
"""

# ╔═╡ 41599efd-45b8-471c-a8ec-2fde36b4f58f
begin
	@with_kw_noshow struct LLA
		lat::typeof(1.0u"°")
		lon::typeof(1.0u"°")
		alt::typeof(1.0u"km")
	end
	
	# Define a constructor that takes combinations of real numbers, with lat/lon defaulting to degrees
	LLA(lat::Real,lon::Real,alt::Real) = LLA(lat*°,lon*°,alt*m)
	LLA(lat::Real,lon::Real,alt::Unitful.Length) = LLA(lat*°,lon*°,alt)
end

# ╔═╡ e817a623-cb7e-4de9-a4e6-a00ec736fdca
# Method with LLA input
geodetic_to_ecef(lla::LLA;kwargs...) = geodetic_to_ecef(lla.lat,lla.lon,lla.alt;kwargs...)

# ╔═╡ 23ae9323-9059-43cd-8efa-8a75a10ac236
#=╠═╡ notebook_exclusive
@test LLA(10,10,1000) ≈ LLA(10+100*eps(),10,1000)
  ╠═╡ notebook_exclusive =#

# ╔═╡ 1b546f06-aaea-4cfa-b7aa-df41d94c8dbd
#=╠═╡ notebook_exclusive
@test LLA(10,10,1000) !== LLA(10+100*eps(),10,1000)
  ╠═╡ notebook_exclusive =#

# ╔═╡ 5081a3aa-1c19-4a30-aaea-188b9732240f
md"""
## ERA
"""

# ╔═╡ 65efffbf-1fe8-48c1-9f47-de3d590b5c15
md"""
ERA stands for Elevation, Range and Azimuth and is used to express the position of a satellite relative to an observer in spherical coordinates.
The elevation is the angle of the pointing with respect to the local horizon of the observer, meaning the plane where the observer is located that is perpendicular to the gravity vector acting on the observe (or in an alternative definition, the plane where the observer is located that is parallel to the tangent plane to the earth ellipsoid at the given lat and lon positions of the observer.
"""

# ╔═╡ 1ca4f2bb-a865-49de-9899-e1ae93ae29be
begin
	@with_kw_noshow struct ERA
		el::typeof(1.0u"°")
		r::typeof(1.0u"km")
		az::typeof(1.0u"°")
	end

	# Define a constructor that takes combinations of real numbers, with el/az defaulting to degrees
	ERA(el::Real,r::Real,az::Real) = ERA(el*°,r*m,az*°)
	ERA(el::Real,r::Unitful.Length,az::Real) = ERA(el*°,r,az*°)
	
	# Show method
	Base.show(io::IO,era::ERA) = println(io,"ERA(el = $(era.el), r = $(era.r), az = $(era.az))") 
end

# ╔═╡ c98d3ea3-e146-40e6-ac02-500b4c0d5d78
begin
	export Ellipsoid, LLA, ERA, geodetic_to_ecef, ecef_to_geodetic
	export tropocentric_rotation_matrix
end

# ╔═╡ cebf3b11-ae0d-408e-a43b-b71a4561f780
#=╠═╡ notebook_exclusive
@test ERA(10,1000,20) == ERA(10°,1km,deg2rad(20)*rad)
  ╠═╡ notebook_exclusive =#

# ╔═╡ 40333531-f0a3-451b-aa52-b6e26b242d34
md"""
## Look Angles
"""

# ╔═╡ 5e3c2f13-d9ff-4f45-bb25-547ca5001e7b
md"""
To extract the look angles from a point representing a terminal with geodetic coordinates (``lat_u``,``lon_u``,``alt_u``) above the earth ellipsoid, to a satellite whose position is also specified via its geodetic coordinates (``lat_s``,``lon_s``,``alt_s``), we will first express the satellite coordinates in the tropocentric CRS (U,V,W) centered on the user position (see Section 4.1.2 of [EPSG guidance note #7-2](https://epsg.org/guidance-notes.html)).

We call ``\mathbf{U} = (X_u, Y_u, Z_u)`` the ECEF coordinates of the user and ``\mathbf{S} = (X_s, Y_s, Z_s)`` as the ECEF coordinates of the satellite.
To express the satellite position in the tropocentric CRS, we will have to perform the following operation:

$(texeq("
\\begin{bmatrix}
	U_s \\
	V_s \\
	W_s \\
\\end{bmatrix} = 
\\mathbf{R}
\\begin{bmatrix}
	X_s - X_u \\
	Y_s - Y_u\\
	Z_s - Z_u\\
\\end{bmatrix}
"))
where ``\mathbf{R}`` is a the rotation matrix:
$(texeq("
\\mathbf{R} = \\begin{bmatrix}
	- {\\rm sin}(lat_u) & {\\rm cos}(lat_u)& 0 \\
	- {\\rm sin}(lon_u){\\rm cos}(lat_u) & - {\\rm sin}(lon_u){\\rm cos}(lat_u) & {\\rm cos}(lon_u) \\
	{\\rm cos}(lon_u){\\rm cos}(lat_u) & {\\rm cos}(lon_u){\\rm sin}(lat_u) & {\\rm sin}(lon_u) 
\\end{bmatrix}.
"))

Once these are computed, elevation and azimuth are easily obtained as (el = 90°-θ, az = φ) by transforming the cartesian tropocentric vector of the satellite position in [spherical coordinates](https://en.wikipedia.org/wiki/Spherical_coordinate_system) (Assuming that θ is the polar angle and φ the azimuth angle, as in ISO/physics convention)
"""

# ╔═╡ 184f69ae-06d3-4f6d-8526-dd4ab30fadad
md"""
### Rotation Matrix
"""

# ╔═╡ 3179c657-aa27-4465-8a90-51ec991701c8
"""
$SIGNATURES

Compute the rotation matrix to compute the tropocentric coordinates with tropocentric origin in the point located at geodetic coordinates `lat` and `lon` expressed in radians or Unitful Angles (both `rad` and `°`)
"""
function tropocentric_rotation_matrix(lat,lon)
	# Precompute the sines and cosines
	sλ, cλ = sincos(lat)
	sφ, cφ = sincos(lon)
	
	# Generate the rotation matrix as a StaticArray
	return SA_F64[
		-sλ      cλ      0
		-sφ*cλ  -sφ*sλ   cφ
		 cφ*cλ   cφ*sλ   sφ
		] |> RotMatrix
end	

# ╔═╡ 3d630992-f6f5-4af2-beea-171428580037
#=╠═╡ notebook_exclusive
@test tropocentric_rotation_matrix(0°,60°) == SA_F64[0 1 0;-√3/2 0 1/2;1/2 0 √3/2]
  ╠═╡ notebook_exclusive =#

# ╔═╡ 5c450408-fa09-4325-b4f1-422ff7f77b30
#=╠═╡ notebook_exclusive
@test tropocentric_rotation_matrix(60°,0°) == SA_F64[-√3/2 1/2 0;0 0 1;1/2 √3/2 0]
  ╠═╡ notebook_exclusive =#

# ╔═╡ ef20e76d-8d2b-4e79-89bf-16743d74a063
tropocentric_rotation_matrix(-90°,10°)

# ╔═╡ 7342d9cd-6684-433d-bd21-e563f7bcd393
md"""
### Tropocentric Origin
"""

# ╔═╡ b4a74622-491a-435d-ac63-3f3892cb47a0
md"""
The generation of the TropocentricOrigin takes some time so (~500ns on my laptop) so it might be worth it to pre-compute this in some cases rather than re-generating this from the LLA coordinates of the user every time a calculation of the look angles needs to be performed.
"""

# ╔═╡ e0df66c4-8212-4c9c-93f3-bd992a97092a
struct TropocentricOrigin
	"Geodetic coordinates (longitude, latitude and altitude above the reerence ellipsoid) of the tropocentric CRS origin"
	lla::LLA
	"ECEF coordinates of the tropocentric CRS origin"
	ecef::SVector{3,Float64}
	"Rotation matrix for the tropocentric transformation"
	R::RotMatrix3{Float64}
	"Reference ellipsoid used in the transformation"
	ellipsoid::Ellipsoid{Float64}
	
	# Make the contructors starting from either the LLA or the ECEF position
	function TropocentricOrigin(lla::LLA; ellipsoid = wgs84_ellipsoid)
		ecef = geodetic_to_ecef(lla; ellipsoid = ellipsoid)
		R = tropocentric_rotation_matrix(lla.lat,lla.lon)
		new(lla,ecef,R,ellipsoid)
	end	
	function TropocentricOrigin(ecef::SVector{3,<:AbstractFloat}; ellipsoid = wgs84_ellipsoid)
		lla = LLA(ecef_to_geodetic(ecef; ellipsoid = ellipsoid)...)
		R = tropocentric_rotation_matrix(lla.lat,lla.lon)
		new(lla,ecef,R,ellipsoid)
	end
end

# ╔═╡ 11e7154b-9da0-46be-9486-a3a028520fb5
function Base.isapprox(x::T,y::T;kwargs...) where T <: Union{LLA,TropocentricOrigin,Ellipsoid}
	for s ∈ fieldnames(T)
		f = Base.isapprox(getfield(x,s),getfield(y,s);kwargs...)
		f || return false
	end
	return true
end

# ╔═╡ 0b6d85c5-c80b-4439-bf6f-309af42729b3
#=╠═╡ notebook_exclusive
@test TropocentricOrigin(LLA(10,10,1000)) ≈ TropocentricOrigin(LLA(10,10,1000) |> geodetic_to_ecef)
  ╠═╡ notebook_exclusive =#

# ╔═╡ a1ba94a9-965a-47b0-a2af-1b577a22bd50
md"""
### ECEF <-> UVW
"""

# ╔═╡ e19794aa-a667-4c7f-a067-d29db663f897
begin
struct UVWfromECEF <: Transformation
	origin::TropocentricOrigin
end
	
function (trans::UVWfromECEF)(ecef::StaticVector{3,<:AbstractFloat})
	uvw = trans.origin.R * (ecef - trans.origin.ecef)
end
end

# ╔═╡ 11fbbb1a-dbe0-4501-99be-1a32843e4f63
ecef2uvw = UVWfromECEF(TropocentricOrigin(LLA(0,0,0)))

# ╔═╡ 490efc34-046d-49c3-a7ad-8e36c9ed6c62
md"""
### ERA <-> UVW
"""

# ╔═╡ 7dea3c32-9adf-47cb-880e-83ee272651ec
begin
	# The transformation between ERA and tropocentric is simply a transformation between spherical and cartesian coordinates
struct ERAfromUVW <: Transformation end
	
function (::ERAfromUVW)(uvw::StaticVector{3,T}) where T
	x,y,z = uvw
	r = hypot(x, y, z)
	θ = r == 0 ? 0 : acos(z/r)
	ϕ = r == 0 ? 0 : atan(y,x)
	ERA((π/2 - θ) * rad,r * m, ϕ * rad)
end
end


# ╔═╡ ffec702e-ea68-4da1-9361-cb9d5a58769c
ecef2uvw(SA_F64[wgs84_ellipsoid.a + 600e3,1e3,1e3]) |> ERAfromUVW()

# ╔═╡ 6690727c-1adb-4334-a756-609bf8386693
md"""
### ERA <-> ECEF
"""

# ╔═╡ dd231bb5-fc61-46ad-acb9-d21e75b2c618
md"""
The transformations defined here allow going from the ECEF coordinates of a satellite to the elevation range and azimuth as seen from a point on ground (which is the tropocentric origin used for the transformation).

The satellite position is expected in ECEF because the altitude of a satellite in orbit above the reference ellipsoid changes with latitude (if the ellipsoid is not a sphere), so by forcing the user to provide ECEF coordinates one has to think about the transformation and there is less risk of putting the same reference orbit altitude regardless of the latitude
"""

# ╔═╡ 4ee2b3d2-df5a-4468-8b27-fb2deff92230
begin
struct ERAfromECEF <: Transformation
	origin::TropocentricOrigin
end
	
function (trans::ERAfromECEF)(ecef::StaticVector{3,<:AbstractFloat})
	era = (ERAfromUVW() ∘ UVWfromECEF(trans.origin))(ecef)
end
end

# ╔═╡ 8cbfefcb-7d3d-49bd-ab6d-d561e118d211
ecef2era = ERAfromECEF(TropocentricOrigin(LLA(0,0,0)))

# ╔═╡ e289acf4-2390-4c5f-8183-0584da9195c4
ecef2era(SA_F64[wgs84_ellipsoid.a + 600e3,0,0])

# ╔═╡ b7318a55-2544-4f00-b815-d73854fae191
ecef2era(SA_F64[wgs84_ellipsoid.a + 600e3,1e3,0])

# ╔═╡ 5d3f7abb-a5a1-47a9-acac-0d5c58c7043c
ecef2era(SA_F64[wgs84_ellipsoid.a + 600e3,1e3,1e3])

# ╔═╡ 50c37c6b-5671-4434-b5b6-c60cb6a8617c
lla_origin = LLA(10,0,0)

# ╔═╡ 86dde47b-1435-4aa5-91f8-d5e107939b3a
sat_ecef = SA_F64[wgs84_ellipsoid.a + 6000e3,1e3,1e3]

# ╔═╡ 33a1d133-6c74-4f63-a405-b61f285abf8c
ERAfromECEF(TropocentricOrigin(lla_origin;ellipsoid=Ellipsoid(wgs84_ellipsoid.a,0)))(sat_ecef)

# ╔═╡ 6614b4b5-8ccf-42e7-a9db-6ab808813ed3
ERAfromECEF(TropocentricOrigin(lla_origin))(sat_ecef)

# ╔═╡ 23b0b1d4-1de0-4e83-be23-45236319f70a
md"""
## SatView to LatLon
"""

# ╔═╡ a418f9b9-c3a8-4054-abd7-d29df23f8772
md"""
The computation of the lat/long position of a point on earth given the view angle (θ,φ or u,v) from the satellite can easily be performed exploiting spherical trigonometry when assuming the earth to be a sphere.

When considering the more appropriate ellipsoid of revolution model, computations become a bit more complex but the formulation can be found in [this recent paper](https://arc.aiaa.org/doi/10.2514/1.G004156)

The paper exploits the cosine directions of the pointing from the spacecraft, expressed in the earth reference frame. These can be obtained directly from the pointing U,V coordinates from the satellite point of view by performing a rotation.
This rotation is the one needed to transform the SatView CRS (origin on the satellite and z-axis pointing at nadir) to the earth reference frame.

This rotation to bring the SatView CRS to the Earth CRS can be expressed in terms of [Euler angles](https://en.wikipedia.org/wiki/Euler_angles#Proper_Euler_angles_2).
Assuimng a X₁Z₂X₃ rotation, the Euler angles can be computed as follows
$(texeq("
\\begin{aligned}
α &= 270° - lat_s \\
β &= 90° -lon_s \\
γ &= 0°
\\end{aligned} \\label{euler-angles}
"))

Exploiting the definitions for rotation matrices in the [wiki page](https://en.wikipedia.org/wiki/Euler_angles#Rotation_matrix) and remembering we are considering the X₁Z₂X₃ case, we can define the rotation matrix to translate points defined in the SatView CRS to the earth reference frame CRS as:
$(texeq("
\\mathbf{R}_{SatView} = \\begin{bmatrix}
	{\\rm cos}(lon_s) & -{\\rm sin}(lat_s){\\rm sin}(lon_s)& {\\rm cos}(lat_s){\\rm sin}(lon_u) \\
	{\\rm sin}(lon_s) & {\\rm sin}(lat_s){\\rm cos}(lon_s) & - {\\rm cos}(lat_s){\\rm cos}(lon_u) \\
	0 & {\\rm cos}(lat_s) & {\\rm sin}(lat_s)
\\end{bmatrix}.
"))

$(eqref("euler-angles"))
"""

# ╔═╡ b9044c02-a02b-4f3a-827a-6da38e70225f
md"""
$$c₁ = cos(270-lat_s) = -sin(lat_s)$$
$$s₁ = sin(270-lat_s) = -cos(lat_s)$$
"""

# ╔═╡ 7ac21bdc-1a22-41cd-801f-d61950b5c647
rot1(lat,lon) = 
SA_F64[
	cos(lon) -sin(lat)*sin(lon) cos(lat)*sin(lon)
	sin(lon) sin(lat)*cos(lon) -cos(lat)cos(lon)
	0 cos(lat) sin(lat)
	] |> inv

# ╔═╡ 20308d5c-c83a-4105-b5b7-3067f14f6398
rot2(lat,lon) = RotZX(π/2 -deg2rad(lon),3π/2-deg2rad(lat)) |> inv

# ╔═╡ 9feb8336-c1d7-40b8-953d-87ef0a6d4c11
rot1(.5,1)

# ╔═╡ 9ad30886-ac69-4903-9d78-34f7bf67ca52
RotZX(-1,3π/2-.5)

# ╔═╡ 7e5e6fec-9f52-4d61-a08a-b85b92e4d2d6
latlong = (-45°, 0°)

# ╔═╡ 6a7a6c49-2183-4a89-a984-923983d8dac5
n = SA_F64[0,0,1]

# ╔═╡ eef9c1ca-5192-45df-8ace-832fdb01776c
rot1(latlong...) * n

# ╔═╡ ce2d9371-6e35-453d-b0f0-74e06c0bb2dc
rot2(latlong...) * n

# ╔═╡ 8376d759-b29b-4167-b4a0-0824d9a5c27a
RotXZX(0,-1,3π/2-.5)

# ╔═╡ e5b30ed2-9868-4ecb-86c6-ef63bdf0e6fb
md"""
## Get source CRS geod
"""

# ╔═╡ 0c805467-20a7-42e3-9ca4-fe8dc8141725
"""
$TYPEDSIGNATURES

Get the geod_geodesic structure from the PROJ library based on the ellipsoid of a the source CRS of a `Proj4.Transformation`.

This structure is then used to solve the inverse geodetic problem (with `Proj4._geod_inverse`) to find distance between points on earth provided as lat-lon positions
"""
function get_source_crs_geod(t::Proj4.Transformation)
	# Initialize the C pointers required to extract the ellipsoid parameters
	inps = Tuple(Ref{s}() for s ∈ (Cdouble,Cdouble,Cint,Cdouble))
	# Extract the epplipsoid parameters
	t.pj |> Proj4.proj_get_source_crs |> Proj4.proj_get_ellipsoid |> x -> Proj4.proj_ellipsoid_get_parameters(x,inps...)
	# Extract ellipsoid axes and flattening from the C pointers
	a,b,computed,f_inv = map(x -> x[],inps)
	f = 1/f_inv # Compute the actual flattening
	# Create the geod from Proj4
	Proj4.geod_geodesic(a,f)
end

# ╔═╡ c023c6f2-ebcc-4bf2-8898-2563bf97ca45
md"""
## Define the angle types 
"""

# ╔═╡ c0a080c2-6e70-45e0-8482-25deb97da3e3
const angle_types = Union{typeof(°),typeof(rad)}

# ╔═╡ 8171a163-006d-4f80-bd2d-4dd05088055c
const angle_quantity_type = Quantity{<:Real,<:Any,<:angle_types}

# ╔═╡ f68e9146-cdac-42dd-afe3-e8bc8c2211d6
md"""
## Transformation betwee degrees and real
"""

# ╔═╡ 189afaa6-1d94-4f34-b44f-66994d728f58
md"""
To be able to interact the transformation coming from Proj4 (which only accept real number) with potentially inputs containing angular unit data, we need to create an artificial transformation that takes whatever vector,tuple or number of angular inputs, and outputs an SVector that contains the same number but converted to degrees and stripped from their unit
"""

# ╔═╡ f3e17b34-142e-41b7-946a-be800283c4e7
begin
	struct Degree2Real <: Transformation end
	struct Real2Degree <: Transformation end
	
	Base.inv(t::Degree2Real) = Real2Degree()
	Base.inv(t::Real2Degree) = Degree2Real()
	
	# Assume that real numbers are already in degrees
	(t::Degree2Real)(d::Real...) = SVector(d...) |> float
	(t::Degree2Real)(d::angle_quantity_type...) = SVector(@. uconvert(u"°",d) |> ustrip) |> float
	(t::Degree2Real)(d::SVector{<:Any,<:angle_quantity_type}) = t(d...)
	(t::Degree2Real)(d::Tuple) = t(d...)
	
	# Do the opposite, accept real numbers and give back Degrees
	(t::Real2Degree)(r::Real...) = SVector(r .* °) |> float
	(t::Real2Degree)(r::SVector{<:Any,<:Real}) = t(r...)
	(t::Real2Degree)(r::Tuple) = t(r...)
end

# ╔═╡ f65769b4-04f5-457b-beb6-5865c97108d4
#=╠═╡ notebook_exclusive
md"""
### Tests
"""
  ╠═╡ notebook_exclusive =#

# ╔═╡ f4c1d490-81f5-4243-8592-276020a80d39
#=╠═╡ notebook_exclusive
@test Degree2Real()(10,20) == Degree2Real()((10°,20°))
  ╠═╡ notebook_exclusive =#

# ╔═╡ cb73c175-0ae7-488e-9f9c-6460d1b08a11
#=╠═╡ notebook_exclusive
@test Degree2Real()((10°,20°)) == Degree2Real()(SVector(10° |> deg2rad,20° |> deg2rad))
  ╠═╡ notebook_exclusive =#

# ╔═╡ fa0b1a6f-44ce-4fb8-9e89-673913b9234d
#=╠═╡ notebook_exclusive
@test Degree2Real()((10°,20°)) |> inv(Degree2Real()) == SVector(10°,20°)
  ╠═╡ notebook_exclusive =#

# ╔═╡ 8cf22dae-6e53-469f-aa75-f7de1cc79ee4
#=╠═╡ notebook_exclusive
md"""
## Near-sided perspective to UV
"""
  ╠═╡ notebook_exclusive =#

# ╔═╡ 1c9de582-b9ae-4959-ad94-97a9db5802b7
#=╠═╡ notebook_exclusive
md"""
The outcome of the near-sided perspective projection from the PROJ library provides the coordinates on the projection plane that is tangent to the earth at the sub-satellite point.

To be converted into uv, this coordinates have to be scaled depending on the altitude of the satellite that generated the projection.
"""
  ╠═╡ notebook_exclusive =#

# ╔═╡ 8925296c-dcff-4b30-b2c8-0ca976fd1aa2
#=╠═╡ notebook_exclusive
md"""
### Drawing
"""
  ╠═╡ notebook_exclusive =#

# ╔═╡ 6c8dc4fe-0ca2-4038-b1fc-6e00747b3ad8
#=╠═╡ notebook_exclusive
md"""
![Drawnig of the nsper perspective to uv](https://github.com/disberd/TelecomUtils.jl/blob/master/imgs/nsper_projection.jpg?raw=true)
"""
  ╠═╡ notebook_exclusive =#

# ╔═╡ c4580cdb-dcab-45c6-9462-0200dfdab342
begin
	abstract type UVTransformation <: Transformation end
	
	"""
	$TYPEDFIELDS
	
	Transformation that goes from the near-sided perspective coordinates XY coming out of the PROJ4 transformation, into the UV coordinates from the satellite point of view, as a function of the altitude `h` of the satellite expressed as Real number in [m]
	"""
	struct NSper2UV{T<:Real} <: UVTransformation
		"Altitude of the satellite expressed in meters"
		h::T
	end
	
	function (t::NSper2UV)(XY::SVector{2,<:Number})
		coeff = sqrt((t.h)^2	+ sum(XY.^2))
		return XY ./ coeff
	end
	
	"""
	$TYPEDFIELDS
	
	Transformation that goes from the UV coordinates from the satellite point of view, into the near-sided perspective coordinates XY to be fed to the PROJ4 transformation  as a function of the altitude `h` of the satellite expressed as Real number in [m]
	"""
	struct UV2NSper{T} <: UVTransformation
		"Altitude of the satellite expressed in meters"
		h::T
	end
	
	function (t::UV2NSper)(UV::SVector{2,<:Number})
		coeff = t.h/sqrt(1	- sum(UV.^2))
		return UV .* coeff
	end
		
	Base.inv(t::UV2NSper) = NSper2UV(t.h)
	Base.inv(t::NSper2UV) = UV2NSper(t.h)
		
	(t::UVTransformation)(u::Real,v::Real) = t(SVector(u,v))
	(t::UVTransformation)(x::Tuple) = t(x...)
end

# ╔═╡ b0ce1320-2c57-4a43-9945-4a292f77bf03
#=╠═╡ notebook_exclusive
inv(NSper2UV(600e3))((.15,.15))
  ╠═╡ notebook_exclusive =#

# ╔═╡ d173f856-70fb-4f4c-aaf2-ea236a0bd8d8
md"""
## Geodesic Problem
"""

# ╔═╡ 3e7ff56a-cbcd-45b3-a2cb-287d1078d51b
"""
This const string contains the default longlat proj4 string which represent the EPSG 4326 reference (WGS84 datum).

	"+proj=longlat +datum=WGS84 +no_defs"

It is used to initialize the transformations from Proj4.jl
"""
const lonlat_string_default = "+proj=longlat +datum=WGS84 +no_defs"

# ╔═╡ 531ca4ea-cf0a-42bd-b84c-321c8993ee9c
tt = Proj4.Transformation(lonlat_string_default,"+proj=cart +ellps=WGS84")

# ╔═╡ 490456a5-d6e3-4763-8ca2-5f4fe89e8473
tt((10,10,0))

# ╔═╡ b02624f4-6296-4b84-983c-4badbfe0286e
"""
Base geod structure (`Proj4.geod_geodesic`) based on the longlat projection using the WGS84 datum and ellipsoid.
Used to perform inverse geodesic computations
"""
const geod_default = Proj4.Projection(lonlat_string_default) |> Proj4._geod

# ╔═╡ eb5c0f1a-ed26-4591-b687-e15f7ee44809
#=╠═╡ notebook_exclusive
geod_default
  ╠═╡ notebook_exclusive =#

# ╔═╡ 19b84a8e-7445-41b1-ae45-8e786634a364
"""
Solve the inverse geodesic problem.

$SIGNATURES

Kwargs:

    lon1,lat1 - point 1 (degrees), where lat ∈ [-90, 90], lon ∈ [-540, 540) 
    lon2,lat2 - point 2 (degrees), where lat ∈ [-90, 90], lon ∈ [-540, 540) 
    geod      - the geod_geodesic object specifying the ellipsoid.

Returns:

    dist    - distance between point 1 and point 2 (meters).
    azi1    - azimuth at point 1 (degrees) ∈ [-180, 180)
    azi2    - (forward) azimuth at point 2 (degrees) ∈ [-180, 180)

Remarks:

    If either point is at a pole, the azimuth is defined by keeping the longitude fixed,
    writing lat = 90 +/- eps, and taking the limit as eps -> 0+.
"""
function geod_inverse(;lon1,lat1,lon2,lat2,geod=geod_default)
	Proj4._geod_inverse(geod,Degree2Real()(lon1,lat1),Degree2Real()(lon2,lat2))
end

# ╔═╡ 9c5a1126-45a4-43e1-97fb-74cf9731c4a7
function geod_inverse(lonlat1::AbstractVector,lonlat2::AbstractVector,geod::Proj4.geod_geodesic)
	lon1,lat1 = lonlat1
	lon2,lat2 = lonlat2
	geod_inverse(;lon1=lon1,lat1=lat1,lon2=lon2,lat2=lat2,geod=geod)
end

# ╔═╡ 73f6b7b2-7e1f-4851-b085-99c03888bebc
geod_inverse(lonlat1::Tuple,lonlat2::Tuple,geod::Proj4.geod_geodesic) = geod_inverse(SVector(lonlat1),SVector(lonlat2),geod)

# ╔═╡ d38ac6b1-c756-4646-baac-1daec3410ee3
geod_inverse(lonlat1,lonlat2) = geod_inverse(lonlat1,lonlat2,geod_default)

# ╔═╡ a8ba1d47-1a83-42b1-be08-b252a8eb9377
#=╠═╡ notebook_exclusive
geod_inverse((0,0),(10,10))
  ╠═╡ notebook_exclusive =#

# ╔═╡ 6666d388-8500-451c-9a6c-57aa59b32a5f
md"""
## LLA to Transformations
"""

# ╔═╡ 3916fb1c-1fbf-413b-96a0-b72abc91539c
"""
$(TYPEDSIGNATURES)

Generate the transformation to go from lon,lat to UV coordinate, providing the satellite position with the lon and lat of the Sub-Satellite Point (SSP) in degrees and the altitude above the earth surface in m.
"""
function lluv_transform(SSP_lon::Real,SSP_lat::Real,alt::Real;lonlat_string = lonlat_string_default)
	uv_string = "+proj=nsper +lat_0=$SSP_lat +lon_0=$SSP_lon +h=$alt +ellps=WGS84"
	
	# Create the basic projection between lat-lon and satellite view
	ll2nsper = Proj4.Transformation(lonlat_string,uv_string)
	# Take into account the conversion from the projected plane and the uv plane from the satellite reference system
	nsper2uv = NSper2UV(alt)
	
	# Create the `geod_geodesic` object from the provided latlong string
	geod = Proj4.Projection(lonlat_string) |> Proj4._geod
	
	return nsper2uv,ll2nsper,geod
end

# ╔═╡ 7abf661e-89e4-42fb-817e-7e18c361c562
# Wrapper to take LLA as input
lluv_transform(lla::LLA;kwargs...) = lluv_transform(
	uconvert(u"°",lla.lon) |> ustrip,
	uconvert(u"°",lla.lat) |> ustrip,
	uconvert(u"m",lla.alt) |> ustrip,
	)

# ╔═╡ 6a27718a-ab6e-4fa5-a18d-5181253fb69c
#=╠═╡ notebook_exclusive
nsper2uv,ll2nsper,geod = lluv_transform(LLA(0,0,600km))
  ╠═╡ notebook_exclusive =#

# ╔═╡ 5f121a73-4cdc-47a6-b505-d56baa060043
ll2nsper(SVector(10,10,50))

# ╔═╡ 41ab1efa-d53f-41e7-9347-fd5979e18c72
#=╠═╡ notebook_exclusive
get_source_crs_geod(ll2nsper)
  ╠═╡ notebook_exclusive =#

# ╔═╡ ed8b3cd2-0b16-416e-b62d-668647d68631
# ellps = Ellipsoid(wgs84_ellipsoid.a,0)
ellps = wgs84_ellipsoid

# ╔═╡ 645a128c-7283-4fbc-a737-e078b51a4f65
sattopoorigin = TropocentricOrigin(LLA(0,0,0km);ellipsoid=ellps)

# ╔═╡ 0ea12ef9-512d-4bfb-8c25-58cc819bb783
satview = UVWfromECEF(sattopoorigin)

# ╔═╡ 64503815-a59e-4f8a-98d1-a1030ee64498
uvwp = satview(geodetic_to_ecef(LLA(10,20,0);ellipsoid=ellps))

# ╔═╡ 10451ec4-335f-4985-a21a-eec5fbd69356
f(uvw) = uvw |> x -> x/norm(x)

# ╔═╡ f7c26528-da9c-489d-9de8-e9d35df60c48
function en(uvw;alt = 600e3)
	u,v,w = uvw
	E = u * alt / (alt - w)
	N = v * alt / (alt - w)
	SVector(E,N)
end

# ╔═╡ 1e35624f-c743-43a2-93de-ebd6f48a55ad
f(uvwp)

# ╔═╡ b13cea79-95ab-467a-b097-41038882a64f
en(uvwp)

# ╔═╡ 39bdfb5c-7f95-46fc-8337-3ffcbdad3626
ll2nsper((20.0,10.0))

# ╔═╡ c4619202-cbd7-4a4c-9052-3661cabb138e
satview.origin.ellipsoid

# ╔═╡ ad5a8282-c083-49d6-9338-a31c9ee085e2
geod

# ╔═╡ 434ef478-3298-4ea7-b8cb-161181abdb2a
md"""
# Satellite View
"""

# ╔═╡ 0ddb5932-89a2-4c95-ab6b-fa73d866e3af
#=╠═╡ notebook_exclusive
LLA(10,10,100)
  ╠═╡ notebook_exclusive =#

# ╔═╡ e72d6e9e-8234-4090-8c8d-187ff5bce5b8
@with_kw_noshow struct SatView
	lla::LLA
end

# ╔═╡ 3b8ce9f3-137b-46a1-81d5-4334e81df27e
SatView(LLA(1,1,100km))

# ╔═╡ 00000000-0000-0000-0000-000000000001
PLUTO_PROJECT_TOML_CONTENTS = """
[deps]
BenchmarkTools = "6e4b80f9-dd63-53aa-95a3-0cdb28fa8baf"
CoordinateTransformations = "150eb455-5306-5404-9cee-2592286d6298"
DocStringExtensions = "ffbed154-4ef7-542d-bbb7-c09d3a79fcae"
LinearAlgebra = "37e2e46d-f89d-539d-b4ee-838fcccc9c8e"
Parameters = "d96e819e-fc66-5662-9728-84c9c7592b0a"
PlutoTest = "cb4044da-4d16-4ffa-a6a3-8cad7f73ebdc"
PlutoUtils = "ed5d0301-4775-4676-b788-cf71e66ff8ed"
Proj4 = "9a7e659c-8ee8-5706-894e-f68f43bc57ea"
Rotations = "6038ab10-8711-5258-84ad-4b1120ba62dc"
SatelliteToolbox = "6ac157d9-b43d-51bb-8fab-48bf53814f4a"
StaticArrays = "90137ffa-7385-5640-81b9-e52037218182"
Unitful = "1986cc42-f94f-5a68-af5c-568840ba703d"

[compat]
BenchmarkTools = "~1.1.3"
CoordinateTransformations = "~0.6.1"
DocStringExtensions = "~0.8.5"
Parameters = "~0.12.2"
PlutoTest = "~0.1.0"
PlutoUtils = "~0.3.4"
Proj4 = "~0.7.5"
Rotations = "~1.0.2"
SatelliteToolbox = "~0.9.2"
StaticArrays = "~1.2.12"
Unitful = "~1.9.0"
"""

# ╔═╡ 00000000-0000-0000-0000-000000000002
PLUTO_MANIFEST_TOML_CONTENTS = """
# This file is machine-generated - editing it directly is not advised

julia_version = "1.7.0-beta2"
manifest_format = "2.0"

[[deps.Adapt]]
deps = ["LinearAlgebra"]
git-tree-sha1 = "84918055d15b3114ede17ac6a7182f68870c16f7"
uuid = "79e6a3ab-5dfb-504d-930d-738a2a938a0e"
version = "3.3.1"

[[deps.ArgTools]]
uuid = "0dad84c5-d112-42e6-8d28-ef12dabb789f"

[[deps.Artifacts]]
uuid = "56f22d72-fd6d-98f1-02f0-08ddc0907c33"

[[deps.AxisAlgorithms]]
deps = ["LinearAlgebra", "Random", "SparseArrays", "WoodburyMatrices"]
git-tree-sha1 = "a4d07a1c313392a77042855df46c5f534076fab9"
uuid = "13072b0f-2c55-5437-9ae7-d433b7a33950"
version = "1.0.0"

[[deps.Base64]]
uuid = "2a0f44e3-6c83-55bd-87e4-b1978d98bd5f"

[[deps.BenchmarkTools]]
deps = ["JSON", "Logging", "Printf", "Statistics", "UUIDs"]
git-tree-sha1 = "aa3aba5ed8f882ed01b71e09ca2ba0f77f44a99e"
uuid = "6e4b80f9-dd63-53aa-95a3-0cdb28fa8baf"
version = "1.1.3"

[[deps.CEnum]]
git-tree-sha1 = "215a9aa4a1f23fbd05b92769fdd62559488d70e9"
uuid = "fa961155-64e5-5f13-b03f-caf6b980ea82"
version = "0.4.1"

[[deps.Chain]]
git-tree-sha1 = "cac464e71767e8a04ceee82a889ca56502795705"
uuid = "8be319e6-bccf-4806-a6f7-6fae938471bc"
version = "0.4.8"

[[deps.ChainRulesCore]]
deps = ["Compat", "LinearAlgebra", "SparseArrays"]
git-tree-sha1 = "bdc0937269321858ab2a4f288486cb258b9a0af7"
uuid = "d360d2e6-b24c-11e9-a2a3-2a2ae2dbcce4"
version = "1.3.0"

[[deps.Compat]]
deps = ["Base64", "Dates", "DelimitedFiles", "Distributed", "InteractiveUtils", "LibGit2", "Libdl", "LinearAlgebra", "Markdown", "Mmap", "Pkg", "Printf", "REPL", "Random", "SHA", "Serialization", "SharedArrays", "Sockets", "SparseArrays", "Statistics", "Test", "UUIDs", "Unicode"]
git-tree-sha1 = "79b9563ef3f2cc5fc6d3046a5ee1a57c9de52495"
uuid = "34da2185-b29b-5c13-b0c7-acf172513d20"
version = "3.33.0"

[[deps.CompilerSupportLibraries_jll]]
deps = ["Artifacts", "Libdl"]
uuid = "e66e0078-7015-5450-92f7-15fbd957f2ae"

[[deps.ConstructionBase]]
deps = ["LinearAlgebra"]
git-tree-sha1 = "f74e9d5388b8620b4cee35d4c5a618dd4dc547f4"
uuid = "187b0558-2788-49d3-abe0-74a17ed4e7c9"
version = "1.3.0"

[[deps.CoordinateTransformations]]
deps = ["LinearAlgebra", "StaticArrays"]
git-tree-sha1 = "6d1c23e740a586955645500bbec662476204a52c"
uuid = "150eb455-5306-5404-9cee-2592286d6298"
version = "0.6.1"

[[deps.Crayons]]
git-tree-sha1 = "3f71217b538d7aaee0b69ab47d9b7724ca8afa0d"
uuid = "a8cc5b0e-0ffa-5ad4-8c14-923d3ee1735f"
version = "4.0.4"

[[deps.DataAPI]]
git-tree-sha1 = "ee400abb2298bd13bfc3df1c412ed228061a2385"
uuid = "9a962f9c-6df0-11e9-0e5d-c546b8b5ee8a"
version = "1.7.0"

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

[[deps.Distributed]]
deps = ["Random", "Serialization", "Sockets"]
uuid = "8ba89e20-285c-5b6f-9357-94700520ee1b"

[[deps.DocStringExtensions]]
deps = ["LibGit2"]
git-tree-sha1 = "a32185f5428d3986f47c2ab78b1f216d5e6cc96f"
uuid = "ffbed154-4ef7-542d-bbb7-c09d3a79fcae"
version = "0.8.5"

[[deps.Downloads]]
deps = ["ArgTools", "LibCURL", "NetworkOptions"]
uuid = "f43a241f-c20a-4ad4-852c-f6b1247861c6"

[[deps.FileIO]]
deps = ["Pkg", "Requires", "UUIDs"]
git-tree-sha1 = "256d8e6188f3f1ebfa1a5d17e072a0efafa8c5bf"
uuid = "5789e2e9-d7fb-5bc7-8068-2c6fae9b9549"
version = "1.10.1"

[[deps.Formatting]]
deps = ["Printf"]
git-tree-sha1 = "8339d61043228fdd3eb658d86c926cb282ae72a8"
uuid = "59287772-0a20-5a39-b81b-1366585eb4c0"
version = "0.4.2"

[[deps.Glob]]
git-tree-sha1 = "4df9f7e06108728ebf00a0a11edee4b29a482bb2"
uuid = "c27321d9-0574-5035-807b-f59d2c89b15c"
version = "1.3.0"

[[deps.HTTP]]
deps = ["Base64", "Dates", "IniFile", "Logging", "MbedTLS", "NetworkOptions", "Sockets", "URIs"]
git-tree-sha1 = "44e3b40da000eab4ccb1aecdc4801c040026aeb5"
uuid = "cd3eb016-35fb-5094-929b-558a96fad6f3"
version = "0.9.13"

[[deps.HypertextLiteral]]
git-tree-sha1 = "1e3ccdc7a6f7b577623028e0095479f4727d8ec1"
uuid = "ac1192a8-f4b3-4bfe-ba22-af5b92cd3ab2"
version = "0.8.0"

[[deps.IniFile]]
deps = ["Test"]
git-tree-sha1 = "098e4d2c533924c921f9f9847274f2ad89e018b8"
uuid = "83e8ac13-25f8-5344-8a64-a9f2b223428f"
version = "0.5.0"

[[deps.InteractiveUtils]]
deps = ["Markdown"]
uuid = "b77e0a4c-d291-57a0-90e8-8db25a27a240"

[[deps.Interpolations]]
deps = ["AxisAlgorithms", "ChainRulesCore", "LinearAlgebra", "OffsetArrays", "Random", "Ratios", "Requires", "SharedArrays", "SparseArrays", "StaticArrays", "WoodburyMatrices"]
git-tree-sha1 = "61aa005707ea2cebf47c8d780da8dc9bc4e0c512"
uuid = "a98d9a8b-a2ab-59e6-89dd-64a1c18fca59"
version = "0.13.4"

[[deps.IteratorInterfaceExtensions]]
git-tree-sha1 = "a3f24677c21f5bbe9d2a714f95dcd58337fb2856"
uuid = "82899510-4779-5014-852e-03e436cf321d"
version = "1.0.0"

[[deps.JLLWrappers]]
deps = ["Preferences"]
git-tree-sha1 = "642a199af8b68253517b80bd3bfd17eb4e84df6e"
uuid = "692b3bcd-3c85-4b1f-b108-f13ce0eb3210"
version = "1.3.0"

[[deps.JSON]]
deps = ["Dates", "Mmap", "Parsers", "Unicode"]
git-tree-sha1 = "8076680b162ada2a031f707ac7b4953e30667a37"
uuid = "682c06a0-de6a-54ab-a142-c8b1cf79cde6"
version = "0.21.2"

[[deps.JpegTurbo_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl", "Pkg"]
git-tree-sha1 = "d735490ac75c5cb9f1b00d8b5509c11984dc6943"
uuid = "aacddb02-875f-59d6-b918-886e6ef4fbf8"
version = "2.1.0+0"

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

[[deps.Libtiff_jll]]
deps = ["Artifacts", "JLLWrappers", "JpegTurbo_jll", "Libdl", "Pkg", "Zlib_jll", "Zstd_jll"]
git-tree-sha1 = "340e257aada13f95f98ee352d316c3bed37c8ab9"
uuid = "89763e89-9b03-5906-acba-b20f662cd828"
version = "4.3.0+0"

[[deps.LinearAlgebra]]
deps = ["Libdl", "libblastrampoline_jll"]
uuid = "37e2e46d-f89d-539d-b4ee-838fcccc9c8e"

[[deps.Logging]]
uuid = "56ddb016-857b-54e1-b83d-db4d58db5568"

[[deps.Markdown]]
deps = ["Base64"]
uuid = "d6f4376e-aef5-505a-96c1-9c027394607a"

[[deps.MbedTLS]]
deps = ["Dates", "MbedTLS_jll", "Random", "Sockets"]
git-tree-sha1 = "1c38e51c3d08ef2278062ebceade0e46cefc96fe"
uuid = "739be429-bea8-5141-9913-cc70e7f3736d"
version = "1.0.3"

[[deps.MbedTLS_jll]]
deps = ["Artifacts", "Libdl"]
uuid = "c8ffd9c3-330d-5841-b78e-0817d7145fa1"

[[deps.Mmap]]
uuid = "a63ad114-7e13-5084-954f-fe012c677804"

[[deps.MozillaCACerts_jll]]
uuid = "14a3606d-f60d-562e-9121-12d972cd8159"

[[deps.NetworkOptions]]
uuid = "ca575930-c2e3-43a9-ace4-1e988b2c1908"

[[deps.OffsetArrays]]
deps = ["Adapt"]
git-tree-sha1 = "c0f4a4836e5f3e0763243b8324200af6d0e0f90c"
uuid = "6fe1bfb0-de20-5000-8ca7-80f57d26f881"
version = "1.10.5"

[[deps.OpenBLAS_jll]]
deps = ["Artifacts", "CompilerSupportLibraries_jll", "Libdl"]
uuid = "4536629a-c528-5b80-bd46-f80d51c5b363"

[[deps.OptionalData]]
git-tree-sha1 = "d047cc114023e12292533bb822b45c23cb51d310"
uuid = "fbd9d27c-2d1c-5c1c-99f2-7497d746985d"
version = "1.0.0"

[[deps.OrderedCollections]]
git-tree-sha1 = "85f8e6578bf1f9ee0d11e7bb1b1456435479d47c"
uuid = "bac558e1-5e72-5ebc-8fee-abe8a469f55d"
version = "1.4.1"

[[deps.PROJ_jll]]
deps = ["Artifacts", "JLLWrappers", "LibCURL_jll", "LibSSH2_jll", "Libdl", "Libtiff_jll", "MbedTLS_jll", "Pkg", "SQLite_jll", "Zlib_jll", "nghttp2_jll"]
git-tree-sha1 = "2435e91710d7f97f53ef7a4872bf1f948dc8e5f8"
uuid = "58948b4f-47e0-5654-a9ad-f609743f8632"
version = "700.202.100+0"

[[deps.Parameters]]
deps = ["OrderedCollections", "UnPack"]
git-tree-sha1 = "2276ac65f1e236e0a6ea70baff3f62ad4c625345"
uuid = "d96e819e-fc66-5662-9728-84c9c7592b0a"
version = "0.12.2"

[[deps.Parsers]]
deps = ["Dates"]
git-tree-sha1 = "477bf42b4d1496b454c10cce46645bb5b8a0cf2c"
uuid = "69de0a69-1ddd-5017-9359-2bf0b02dc9f0"
version = "2.0.2"

[[deps.Pkg]]
deps = ["Artifacts", "Dates", "Downloads", "LibGit2", "Libdl", "Logging", "Markdown", "Printf", "REPL", "Random", "SHA", "Serialization", "TOML", "Tar", "UUIDs", "p7zip_jll"]
uuid = "44cfe95a-1eb2-52ea-b672-e2afdf69b78f"

[[deps.PlutoTest]]
deps = ["HypertextLiteral", "InteractiveUtils", "Markdown", "Test"]
git-tree-sha1 = "3479836b31a31c29a7bac1f09d95f9c843ce1ade"
uuid = "cb4044da-4d16-4ffa-a6a3-8cad7f73ebdc"
version = "0.1.0"

[[deps.PlutoUI]]
deps = ["Base64", "Dates", "InteractiveUtils", "JSON", "Logging", "Markdown", "Random", "Reexport", "Suppressor"]
git-tree-sha1 = "44e225d5837e2a2345e69a1d1e01ac2443ff9fcb"
uuid = "7f904dfe-b85e-4ff6-b463-dae2292396a8"
version = "0.7.9"

[[deps.PlutoUtils]]
deps = ["Chain", "Glob", "HypertextLiteral", "InteractiveUtils", "Markdown", "PlutoTest", "PlutoUI", "PrettyTables", "Reexport", "Requires", "UUIDs"]
git-tree-sha1 = "db3eaef2cc68f99bb41a8600f882e016f718f65a"
uuid = "ed5d0301-4775-4676-b788-cf71e66ff8ed"
version = "0.3.4"

[[deps.PolynomialRoots]]
git-tree-sha1 = "5f807b5345093487f733e520a1b7395ee9324825"
uuid = "3a141323-8675-5d76-9d11-e1df1406c778"
version = "1.0.0"

[[deps.Preferences]]
deps = ["TOML"]
git-tree-sha1 = "00cfd92944ca9c760982747e9a1d0d5d86ab1e5a"
uuid = "21216c6a-2e73-6563-6e65-726566657250"
version = "1.2.2"

[[deps.PrettyTables]]
deps = ["Crayons", "Formatting", "Markdown", "Reexport", "Tables"]
git-tree-sha1 = "0d1245a357cc61c8cd61934c07447aa569ff22e6"
uuid = "08abe8d2-0d0c-5749-adfa-8a2ac140af0d"
version = "1.1.0"

[[deps.Printf]]
deps = ["Unicode"]
uuid = "de0858da-6303-5e67-8744-51eddeeeb8d7"

[[deps.Proj4]]
deps = ["CEnum", "CoordinateTransformations", "PROJ_jll", "StaticArrays"]
git-tree-sha1 = "a26cc8a99169e41c7d60719d4bddf2ce7adb4069"
uuid = "9a7e659c-8ee8-5706-894e-f68f43bc57ea"
version = "0.7.5"

[[deps.REPL]]
deps = ["InteractiveUtils", "Markdown", "Sockets", "Unicode"]
uuid = "3fa0cd96-eef1-5676-8a61-b3b8758bbffb"

[[deps.Random]]
deps = ["Serialization"]
uuid = "9a3f8284-a2c9-5f02-9a11-845980a1fd5c"

[[deps.Ratios]]
deps = ["Requires"]
git-tree-sha1 = "7dff99fbc740e2f8228c6878e2aad6d7c2678098"
uuid = "c84ed2f1-dad5-54f0-aa8e-dbefe2724439"
version = "0.4.1"

[[deps.Reexport]]
git-tree-sha1 = "5f6c21241f0f655da3952fd60aa18477cf96c220"
uuid = "189a3867-3050-52da-a836-e630ba90ab69"
version = "1.1.0"

[[deps.ReferenceFrameRotations]]
deps = ["Crayons", "LinearAlgebra", "Printf", "StaticArrays"]
git-tree-sha1 = "fecac02781f5c475c957d8088c4b43a0a44316b5"
uuid = "74f56ac7-18b3-5285-802d-d4bd4f104033"
version = "1.0.0"

[[deps.RemoteFiles]]
deps = ["Dates", "FileIO", "HTTP"]
git-tree-sha1 = "54527375d877a64c55190fb762d584f927d6d7c3"
uuid = "cbe49d4c-5af1-5b60-bb70-0a60aa018e1b"
version = "0.4.2"

[[deps.Requires]]
deps = ["UUIDs"]
git-tree-sha1 = "4036a3bd08ac7e968e27c203d45f5fff15020621"
uuid = "ae029012-a4dd-5104-9daa-d747884805df"
version = "1.1.3"

[[deps.Rotations]]
deps = ["LinearAlgebra", "StaticArrays", "Statistics"]
git-tree-sha1 = "2ed8d8a16d703f900168822d83699b8c3c1a5cd8"
uuid = "6038ab10-8711-5258-84ad-4b1120ba62dc"
version = "1.0.2"

[[deps.SHA]]
uuid = "ea8e919c-243c-51af-8825-aaa63cd721ce"

[[deps.SQLite_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl", "Pkg", "Zlib_jll"]
git-tree-sha1 = "9a0e24b81e3ce02c4b2eb855476467c7b93b8a8f"
uuid = "76ed43ae-9a5d-5a62-8c75-30186b810ce8"
version = "3.36.0+0"

[[deps.SatelliteToolbox]]
deps = ["Crayons", "Dates", "DelimitedFiles", "Interpolations", "LinearAlgebra", "OptionalData", "Parameters", "PolynomialRoots", "PrettyTables", "Printf", "Reexport", "ReferenceFrameRotations", "RemoteFiles", "SparseArrays", "StaticArrays", "Statistics"]
git-tree-sha1 = "88d5667e29bfe9af5e96ee338fc0ab160e1210d3"
uuid = "6ac157d9-b43d-51bb-8fab-48bf53814f4a"
version = "0.9.2"

[[deps.Serialization]]
uuid = "9e88b42a-f829-5b0c-bbe9-9e923198166b"

[[deps.SharedArrays]]
deps = ["Distributed", "Mmap", "Random", "Serialization"]
uuid = "1a1011a3-84de-559e-8e89-a11a2f7dc383"

[[deps.Sockets]]
uuid = "6462fe0b-24de-5631-8697-dd941f90decc"

[[deps.SparseArrays]]
deps = ["LinearAlgebra", "Random"]
uuid = "2f01184e-e22b-5df5-ae63-d93ebab69eaf"

[[deps.StaticArrays]]
deps = ["LinearAlgebra", "Random", "Statistics"]
git-tree-sha1 = "3240808c6d463ac46f1c1cd7638375cd22abbccb"
uuid = "90137ffa-7385-5640-81b9-e52037218182"
version = "1.2.12"

[[deps.Statistics]]
deps = ["LinearAlgebra", "SparseArrays"]
uuid = "10745b16-79ce-11e8-11f9-7d13ad32a3b2"

[[deps.Suppressor]]
git-tree-sha1 = "a819d77f31f83e5792a76081eee1ea6342ab8787"
uuid = "fd094767-a336-5f1f-9728-57cf17d0bbfb"
version = "0.2.0"

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
git-tree-sha1 = "d0c690d37c73aeb5ca063056283fde5585a41710"
uuid = "bd369af6-aec1-5ad0-b16a-f7cc5008161c"
version = "1.5.0"

[[deps.Tar]]
deps = ["ArgTools", "SHA"]
uuid = "a4e569a6-e804-4fa4-b0f3-eef7a1d5b13e"

[[deps.Test]]
deps = ["InteractiveUtils", "Logging", "Random", "Serialization"]
uuid = "8dfed614-e22c-5e08-85e1-65c5234f0b40"

[[deps.URIs]]
git-tree-sha1 = "97bbe755a53fe859669cd907f2d96aee8d2c1355"
uuid = "5c2747f8-b7ea-4ff2-ba2e-563bfd36b1d4"
version = "1.3.0"

[[deps.UUIDs]]
deps = ["Random", "SHA"]
uuid = "cf7118a7-6976-5b1a-9a39-7adc72f591a4"

[[deps.UnPack]]
git-tree-sha1 = "387c1f73762231e86e0c9c5443ce3b4a0a9a0c2b"
uuid = "3a884ed6-31ef-47d7-9d2a-63182c4928ed"
version = "1.0.2"

[[deps.Unicode]]
uuid = "4ec0a83e-493e-50e2-b9ac-8f72acf5a8f5"

[[deps.Unitful]]
deps = ["ConstructionBase", "Dates", "LinearAlgebra", "Random"]
git-tree-sha1 = "a981a8ef8714cba2fd9780b22fd7a469e7aaf56d"
uuid = "1986cc42-f94f-5a68-af5c-568840ba703d"
version = "1.9.0"

[[deps.WoodburyMatrices]]
deps = ["LinearAlgebra", "SparseArrays"]
git-tree-sha1 = "59e2ad8fd1591ea019a5259bd012d7aee15f995c"
uuid = "efce3f68-66dc-5838-9240-27a6d6f5f9b6"
version = "0.5.3"

[[deps.Zlib_jll]]
deps = ["Libdl"]
uuid = "83775a58-1f1d-513f-b197-d71354ab007a"

[[deps.Zstd_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl", "Pkg"]
git-tree-sha1 = "cc4bf3fdde8b7e3e9fa0351bdeedba1cf3b7f6e6"
uuid = "3161d3a3-bdf6-5164-811a-617609db77b4"
version = "1.5.0+0"

[[deps.libblastrampoline_jll]]
deps = ["Artifacts", "Libdl", "OpenBLAS_jll", "Pkg"]
uuid = "8e850b90-86db-534c-a0d3-1478176c7d93"

[[deps.nghttp2_jll]]
deps = ["Artifacts", "Libdl"]
uuid = "8e850ede-7688-5339-a07c-302acd2aaf8d"

[[deps.p7zip_jll]]
deps = ["Artifacts", "Libdl"]
uuid = "3f19e933-33d8-53b3-aaab-bd5110c3b7a0"
"""

# ╔═╡ Cell order:
# ╠═590cdbce-fc45-11eb-2fde-1d27628251b7
# ╠═bcee47c1-81c1-4c77-af09-22c04374fa4f
# ╠═9e29c3ea-2cda-4726-86a3-20cabdb20245
# ╠═d56dc0b2-204c-410e-ad75-f6abbdae1f7a
# ╠═74422a23-0760-470f-9e1e-43b8c3972f65
# ╠═2ad47a80-881a-4ac5-a61e-0691e6bf35e0
# ╠═77e399b7-0f7e-4ff1-9f8e-fd0f3408e894
# ╟─ac5e6327-98a1-478f-be65-05fa1cff717d
# ╟─d5c40459-9894-43a4-81d1-54eeaf9febb2
# ╟─367ad569-495a-458b-806d-e5e40db12e1a
# ╠═c98d3ea3-e146-40e6-ac02-500b4c0d5d78
# ╟─cc8f63e4-77e4-4bdb-8f40-4e3450007e50
# ╠═0202190c-5906-4ca6-9346-71ae4f51bdad
# ╠═140481fb-9e22-47b8-8118-37811ca04bdd
# ╟─0de61675-b5f5-4c57-afdb-f5ae2ff6b0c1
# ╠═6bc1a3ac-414c-422b-9b6f-c7efea145a8c
# ╠═75d0fc45-87e9-42bc-aab5-dae0cf099eaa
# ╠═34087d1f-9773-4a52-b153-8ffd728deb52
# ╠═efb91b19-8e1e-4a26-ad25-e67f3453c018
# ╠═b15e13ab-71e3-4b78-a9d4-377d113e007c
# ╠═e817a623-cb7e-4de9-a4e6-a00ec736fdca
# ╟─1fc544b8-9d87-4d16-a7f3-93bd533db412
# ╟─f359e8fd-b75f-41ed-a847-9e8b2e3da150
# ╠═e03bb946-7060-436a-9959-04c0a3f32ddf
# ╠═531ca4ea-cf0a-42bd-b84c-321c8993ee9c
# ╠═490456a5-d6e3-4763-8ca2-5f4fe89e8473
# ╠═5f121a73-4cdc-47a6-b505-d56baa060043
# ╟─bf534d5c-b861-4c4c-b645-7848b3eaf0fe
# ╟─f0758e99-9f2b-4934-88eb-7e62cdd5c51f
# ╠═41599efd-45b8-471c-a8ec-2fde36b4f58f
# ╠═11e7154b-9da0-46be-9486-a3a028520fb5
# ╠═23ae9323-9059-43cd-8efa-8a75a10ac236
# ╠═1b546f06-aaea-4cfa-b7aa-df41d94c8dbd
# ╟─5081a3aa-1c19-4a30-aaea-188b9732240f
# ╟─65efffbf-1fe8-48c1-9f47-de3d590b5c15
# ╠═1ca4f2bb-a865-49de-9899-e1ae93ae29be
# ╠═cebf3b11-ae0d-408e-a43b-b71a4561f780
# ╟─40333531-f0a3-451b-aa52-b6e26b242d34
# ╠═5e3c2f13-d9ff-4f45-bb25-547ca5001e7b
# ╟─184f69ae-06d3-4f6d-8526-dd4ab30fadad
# ╠═3179c657-aa27-4465-8a90-51ec991701c8
# ╠═3d630992-f6f5-4af2-beea-171428580037
# ╠═5c450408-fa09-4325-b4f1-422ff7f77b30
# ╠═ef20e76d-8d2b-4e79-89bf-16743d74a063
# ╟─7342d9cd-6684-433d-bd21-e563f7bcd393
# ╟─b4a74622-491a-435d-ac63-3f3892cb47a0
# ╠═e0df66c4-8212-4c9c-93f3-bd992a97092a
# ╠═0b6d85c5-c80b-4439-bf6f-309af42729b3
# ╟─a1ba94a9-965a-47b0-a2af-1b577a22bd50
# ╠═e19794aa-a667-4c7f-a067-d29db663f897
# ╠═11fbbb1a-dbe0-4501-99be-1a32843e4f63
# ╟─490efc34-046d-49c3-a7ad-8e36c9ed6c62
# ╠═7dea3c32-9adf-47cb-880e-83ee272651ec
# ╠═ffec702e-ea68-4da1-9361-cb9d5a58769c
# ╟─6690727c-1adb-4334-a756-609bf8386693
# ╟─dd231bb5-fc61-46ad-acb9-d21e75b2c618
# ╠═4ee2b3d2-df5a-4468-8b27-fb2deff92230
# ╠═8cbfefcb-7d3d-49bd-ab6d-d561e118d211
# ╠═e289acf4-2390-4c5f-8183-0584da9195c4
# ╠═b7318a55-2544-4f00-b815-d73854fae191
# ╠═5d3f7abb-a5a1-47a9-acac-0d5c58c7043c
# ╠═50c37c6b-5671-4434-b5b6-c60cb6a8617c
# ╠═86dde47b-1435-4aa5-91f8-d5e107939b3a
# ╠═33a1d133-6c74-4f63-a405-b61f285abf8c
# ╠═6614b4b5-8ccf-42e7-a9db-6ab808813ed3
# ╟─23b0b1d4-1de0-4e83-be23-45236319f70a
# ╠═a418f9b9-c3a8-4054-abd7-d29df23f8772
# ╠═b9044c02-a02b-4f3a-827a-6da38e70225f
# ╠═7ac21bdc-1a22-41cd-801f-d61950b5c647
# ╠═20308d5c-c83a-4105-b5b7-3067f14f6398
# ╠═9feb8336-c1d7-40b8-953d-87ef0a6d4c11
# ╠═9ad30886-ac69-4903-9d78-34f7bf67ca52
# ╠═7e5e6fec-9f52-4d61-a08a-b85b92e4d2d6
# ╠═6a7a6c49-2183-4a89-a984-923983d8dac5
# ╠═eef9c1ca-5192-45df-8ace-832fdb01776c
# ╠═ce2d9371-6e35-453d-b0f0-74e06c0bb2dc
# ╠═8376d759-b29b-4167-b4a0-0824d9a5c27a
# ╟─e5b30ed2-9868-4ecb-86c6-ef63bdf0e6fb
# ╠═0c805467-20a7-42e3-9ca4-fe8dc8141725
# ╠═41ab1efa-d53f-41e7-9347-fd5979e18c72
# ╟─c023c6f2-ebcc-4bf2-8898-2563bf97ca45
# ╠═c0a080c2-6e70-45e0-8482-25deb97da3e3
# ╠═8171a163-006d-4f80-bd2d-4dd05088055c
# ╟─f68e9146-cdac-42dd-afe3-e8bc8c2211d6
# ╟─189afaa6-1d94-4f34-b44f-66994d728f58
# ╠═f3e17b34-142e-41b7-946a-be800283c4e7
# ╟─f65769b4-04f5-457b-beb6-5865c97108d4
# ╠═f4c1d490-81f5-4243-8592-276020a80d39
# ╠═cb73c175-0ae7-488e-9f9c-6460d1b08a11
# ╠═fa0b1a6f-44ce-4fb8-9e89-673913b9234d
# ╟─8cf22dae-6e53-469f-aa75-f7de1cc79ee4
# ╟─1c9de582-b9ae-4959-ad94-97a9db5802b7
# ╟─8925296c-dcff-4b30-b2c8-0ca976fd1aa2
# ╟─6c8dc4fe-0ca2-4038-b1fc-6e00747b3ad8
# ╠═c4580cdb-dcab-45c6-9462-0200dfdab342
# ╠═b0ce1320-2c57-4a43-9945-4a292f77bf03
# ╟─d173f856-70fb-4f4c-aaf2-ea236a0bd8d8
# ╠═3e7ff56a-cbcd-45b3-a2cb-287d1078d51b
# ╠═b02624f4-6296-4b84-983c-4badbfe0286e
# ╠═eb5c0f1a-ed26-4591-b687-e15f7ee44809
# ╠═19b84a8e-7445-41b1-ae45-8e786634a364
# ╠═9c5a1126-45a4-43e1-97fb-74cf9731c4a7
# ╠═73f6b7b2-7e1f-4851-b085-99c03888bebc
# ╠═d38ac6b1-c756-4646-baac-1daec3410ee3
# ╠═a8ba1d47-1a83-42b1-be08-b252a8eb9377
# ╟─6666d388-8500-451c-9a6c-57aa59b32a5f
# ╠═3916fb1c-1fbf-413b-96a0-b72abc91539c
# ╠═7abf661e-89e4-42fb-817e-7e18c361c562
# ╠═6a27718a-ab6e-4fa5-a18d-5181253fb69c
# ╠═ed8b3cd2-0b16-416e-b62d-668647d68631
# ╠═645a128c-7283-4fbc-a737-e078b51a4f65
# ╠═0ea12ef9-512d-4bfb-8c25-58cc819bb783
# ╠═64503815-a59e-4f8a-98d1-a1030ee64498
# ╠═10451ec4-335f-4985-a21a-eec5fbd69356
# ╠═f7c26528-da9c-489d-9de8-e9d35df60c48
# ╠═1e35624f-c743-43a2-93de-ebd6f48a55ad
# ╠═b13cea79-95ab-467a-b097-41038882a64f
# ╠═39bdfb5c-7f95-46fc-8337-3ffcbdad3626
# ╠═c4619202-cbd7-4a4c-9052-3661cabb138e
# ╠═ad5a8282-c083-49d6-9338-a31c9ee085e2
# ╟─434ef478-3298-4ea7-b8cb-161181abdb2a
# ╠═0ddb5932-89a2-4c95-ab6b-fa73d866e3af
# ╠═e72d6e9e-8234-4090-8c8d-187ff5bce5b8
# ╠═3b8ce9f3-137b-46a1-81d5-4334e81df27e
# ╟─00000000-0000-0000-0000-000000000001
# ╟─00000000-0000-0000-0000-000000000002