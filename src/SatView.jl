### A Pluto.jl notebook ###
# v0.15.1

using Markdown
using InteractiveUtils

# ╔═╡ 590cdbce-fc45-11eb-2fde-1d27628251b7
begin
	using Proj4: geod_geodesic, libproj
	using CoordinateTransformations
	using StaticArrays
	using LinearAlgebra
	using Unitful
	using Unitful.DefaultSymbols
	using Rotations
	using Parameters
	using SatelliteToolbox: geodetic_to_ecef, ecef_to_geodetic, Ellipsoid, wgs84_ellipsoid
end

# ╔═╡ 9e29c3ea-2cda-4726-86a3-20cabdb20245
#=╠═╡ notebook_exclusive
begin
	using BenchmarkTools
	using PlutoTest
	using MacroTools
	using PlutoUtils
	using DocStringExtensions
	using MAT
	import SatelliteToolbox
	import Proj4
end
  ╠═╡ notebook_exclusive =#

# ╔═╡ 74422a23-0760-470f-9e1e-43b8c3972f65
#=╠═╡ notebook_exclusive
hide_cell_shortcut()
  ╠═╡ notebook_exclusive =#

# ╔═╡ 2ad47a80-881a-4ac5-a61e-0691e6bf35e0
#=╠═╡ notebook_exclusive
initialize_eqref()
  ╠═╡ notebook_exclusive =#

# ╔═╡ 77e399b7-0f7e-4ff1-9f8e-fd0f3408e894
#=╠═╡ notebook_exclusive
ToC()
  ╠═╡ notebook_exclusive =#

# ╔═╡ 367ad569-495a-458b-806d-e5e40db12e1a
md"""
# Exports
"""

# ╔═╡ 0573442d-30bc-44c0-9f69-83589e8f2870
md"""
# Helper Functions
"""

# ╔═╡ 31fd624c-c86d-4910-8f93-c7d91641d206
md"""
## Show/Print
"""

# ╔═╡ b8b5f9f6-2e39-42ea-bd47-f7174f726472
function _print_angle(io,val,displayname,last=false)
	print(io,"$displayname=")
	print(io,round(val;digits=2) * rad)
	print(io," (")
	print(io,round(rad2deg(val);digits=2) * °)
	print(io,")")
	last || print(io,", ")
end

# ╔═╡ aa58d03c-a42b-4b0c-84b4-566d154d7f90
function _print_length(io,val,displayname,last=false)
	print(io,"$displayname=")
	mval = val < 1000 ? round(val;digits=2) * m : round(val/1000;digits=2) * km
	print(io,mval)
	last || print(io,", ")
end

# ╔═╡ 184f69ae-06d3-4f6d-8526-dd4ab30fadad
md"""
## Rotation Matrix
"""

# ╔═╡ 352da29b-e1ff-41cf-a7be-b7318056ca3f
md"""
### User-Centric
"""

# ╔═╡ f5e22bff-efc9-4a3c-a70f-8e800d325ae8
# Generic definition
_rotation_matrix(s::Symbol,lat,lon) = _rotation_matrix(Val(s),lat,lon)

# ╔═╡ 3179c657-aa27-4465-8a90-51ec991701c8
begin
	"""
	$SIGNATURES
	
	Compute the rotation matrix to compute the tropocentric coordinates with tropocentric origin in the point located at geodetic coordinates `lat` and `lon` expressed in radians or Unitful Angles (both `rad` and `°`)
	"""
	function _rotation_matrix(::Union{Val{:ENUfromECEF},Val{:ERAfromECEF}},lat,lon)
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
	_rotation_matrix(::Union{Val{:ECEFfromENU},Val{:ECEFfromERA}},lat,lon) = inv(_rotation_matrix(Val(:ENUfromECEF),lat,lon))
end

# ╔═╡ 3d630992-f6f5-4af2-beea-171428580037
#=╠═╡ notebook_exclusive
@test _rotation_matrix(Val(:ENUfromECEF),0°,60°) == SA_F64[0 1 0;-√3/2 0 1/2;1/2 0 √3/2]
  ╠═╡ notebook_exclusive =#

# ╔═╡ 5c450408-fa09-4325-b4f1-422ff7f77b30
#=╠═╡ notebook_exclusive
@test _rotation_matrix(Val(:ENUfromECEF),60°,0°) == SA_F64[-√3/2 1/2 0;0 0 1;1/2 √3/2 0]
  ╠═╡ notebook_exclusive =#

# ╔═╡ e925d962-e6fb-464e-8686-3fa18bc2342b
md"""
### Satellite-Centric
"""

# ╔═╡ 43a98a86-f0ba-4b99-b808-1e698b44a202
begin
	# Define the relevant rotation matrix
		function _rotation_matrix(::Union{Val{:ECEFfromUV},Val{:ECEFfromWND},Val{:LLAfromUV}},lat,lon)
		# Precompute the sines and cosines
		sλ, cλ = sincos(lat)
		sφ, cφ = sincos(lon)
		
		# Generate the rotation matrix as a StaticArray
		return SA_F64[
			 sφ -sλ*cφ -cλ*cφ
			-cφ -sλ*sφ -cλ*sφ
			 0   cλ    -sλ
			] |> RotMatrix
	end
	_rotation_matrix(::Union{Val{:UVfromECEF},Val{:WNDfromECEF},Val{:UVfromLLA}},lat,lon) = inv(_rotation_matrix(Val(:ECEFfromUV),lat,lon))
end

# ╔═╡ 04c443a3-baf1-4f18-9a3e-71ab9421d45d
md"""
## Code Generation
"""

# ╔═╡ 23e1bad7-1df2-48e7-a111-268c5d61a6e5
_origin_transformation_docstring(srcname,dstname) = """
Convert a point from $srcname coordinates to $dstname ones

# Fields
- `origin::SVector{3,Float64}`: ECEF coordinates of the reference CRS origin
- `R::RotMatrix3{Float64}`: Rotation matrix to align the source to the destination CRS axes
- `ellipsoid::Ellipsoid{Float64}`: Reference ellipsoid used for the transformation between ECEF and other coordinates
"""

# ╔═╡ 3a4ffc22-5ace-4cc8-aaa0-5eb91b1ac5f8
function _basic_origin_transformation(srcname,dstname,parent,docstring=_origin_transformation_docstring(srcname,dstname))
		name = Symbol(dstname,:from,srcname)
		expr = quote
		@doc $docstring
		struct $(name) <: $(parent)
			"ECEF coordinates of the CRS origin"
			origin::SVector{3,Float64}
			"Rotation matrix for the tropocentric transformation"
			R::RotMatrix3{Float64}
			"Reference ellipsoid used in the transformation"
			ellipsoid::Ellipsoid{Float64}
		end
		function $(name)(lla::LLA;ellipsoid = wgs84_ellipsoid)
			origin = ECEFfromLLA(ellipsoid)(lla)
			R = _rotation_matrix($(Meta.quot(name)),lla.lat,lla.lon)
			$(name)(origin,R,ellipsoid)
		end
		function $(name)(ecef::StaticVector{3,Float64};ellipsoid = wgs84_ellipsoid)
			lla = LLAfromECEF(ellipsoid)(ecef)
			R = _rotation_matrix($(Meta.quot(name)),lla.lat,lla.lon)
			$(name)(ecef,R,ellipsoid)
		end
	end
	return expr |> Base.remove_linenums!
end

# ╔═╡ 0296570a-1982-4532-94aa-99004173aa00
function _full_origin_transformation(name1,name2,parent)
	block = Expr(:block)
	
	fwdname = Symbol(name1,:from,name2)
	rvsname = Symbol(name2,:from,name1)
	
	# Do the forward direction
	expr = _basic_origin_transformation(name1,name2,parent)
	push!(block.args,expr.args...)
	
	# Do the reverse direction
	expr = _basic_origin_transformation(name2,name1,parent)
	push!(block.args,expr.args...)
	
	# Do the inversions
	expr = quote
		Base.inv(t::$fwdname) = $(rvsname)(t.origin,inv(t.R),t.ellipsoid)
		Base.inv(t::$rvsname) = $(fwdname)(t.origin,inv(t.R),t.ellipsoid)
	end |> Base.remove_linenums!
	push!(block.args,expr.args...)
	
	return block
end

# ╔═╡ 5f7d011b-9e54-4174-9eda-86182fc6be06
# Boilerplate code for generating a UserCentric Transformation
macro user_transformation(name1,name2)
	block = _full_origin_transformation(name1,name2,:UserCentricTransformation)	
	esc(block)
end

# ╔═╡ 12f9aea4-4dc4-41be-ab95-bda99bd26de1
# Boilerplate code for generating a SatCentric Transformation
macro sat_transformation(name1,name2)
	block = _full_origin_transformation(name1,name2,:SatCentricTransformation)	
	esc(block)
end

# ╔═╡ b7587ba5-193b-40ee-a0e8-fd4251d6ba66
md"""
# Angle Types
"""

# ╔═╡ d070e629-59b0-4a69-9ece-e76640a19c2e
const AngleType = Union{typeof(°),typeof(rad)}

# ╔═╡ e61dc24f-3e1f-4dcd-9568-902e9d4ae686
const AngleQuantity = Quantity{<:Real,<:Any,<:AngleType}

# ╔═╡ bb47e669-bf83-405e-bfe1-fb35c3c13d4c
md"""
# SatViewCoordinate types
"""

# ╔═╡ 0ad5adbf-4ffa-4a8b-bc3d-a2668d8495eb
abstract type SatViewCoordinate end

# ╔═╡ bf534d5c-b861-4c4c-b645-7848b3eaf0fe
md"""
## LLA
"""

# ╔═╡ f0758e99-9f2b-4934-88eb-7e62cdd5c51f
md"""
Here we want to define a structure that contains useful informations and functions to perform conversions between the view from the satellite based on it's orbital position and points on ground
"""

# ╔═╡ a6644ab1-8561-4105-9ae3-ec021be62c9b
begin
	"""
	Identify a point on or above earth using geodetic coordinates
	
	# Fields
	- `lat::Float64`: Latitude (`-π/2 <= lat <= π/2`) of the point [rad].
	- `lon::Float64`: Longitude of the point [rad].
	- `alt::Float64`: Altitude of the point above the reference earth ellipsoid [m].
	
	# Constructors
		LLA(lat::Real,lon::Real,alt::Real)
		LLA(lat::AngleQuantity,lon::Real,alt::Real)
		LLA(lat::AngleQuantity,lon::AngleQuantity,alt::Real)
		LLA(lat,lon,alt::Unitful.Length)
	
	where `AngleQuantity` is a `Unitful.Quantity` of unit either `u"rad"` or `u"°"`.
	"""
	@with_kw_noshow struct LLA <: SatViewCoordinate
		lat::Float64 # Latitude in radians
		lon::Float64 # Longitude in radians
		alt::Float64 # Altitude in meters
		
		function LLA(lat::Real,lon::Real,alt::Real)
			l2 = rem2pi(lon,RoundNearest)
			@assert abs(lat) <= π/2 "Latitude should be between -π/2 and π/2"
			new(lat,l2,alt)
		end
	end
	
	# Define a constructor that takes combinations of real numbers and angles/lengths
	LLA(lat::AngleQuantity,lon::Real,alt::Real) = LLA(
		uconvert(u"rad",lat) |> ustrip,
		lon,
		alt)
	LLA(lat::AngleQuantity,lon::AngleQuantity,alt::Real) = LLA(
		lat,
		uconvert(u"rad",lon) |> ustrip,
		alt)
	LLA(lat,lon,alt::Unitful.Length) = LLA(
		lat,
		lon,
		uconvert(u"m",alt) |> ustrip)
	
	# Show
	function Base.show(io::IO,lla::LLA)
		print(io,"LLA(")
		_print_angle(io,lla.lat,"lat",false)
		_print_angle(io,lla.lon,"lon",false)
		_print_length(io,lla.alt,"alt",true)
		print(io,")")
	end
end

# ╔═╡ 007644ab-e85e-4a9f-a58b-32ead002a461
#=╠═╡ notebook_exclusive
LLA(1°,10,1000km)
  ╠═╡ notebook_exclusive =#

# ╔═╡ 11e7154b-9da0-46be-9486-a3a028520fb5
function Base.isapprox(x::T,y::T;kwargs...) where T <: Union{<:SatViewCoordinate,Ellipsoid}
	for s ∈ fieldnames(T)
		f = Base.isapprox(getfield(x,s),getfield(y,s);kwargs...)
		f || return false
	end
	return true
end

# ╔═╡ 23ae9323-9059-43cd-8efa-8a75a10ac236
#=╠═╡ notebook_exclusive
@test LLA(10°,10°,1000) ≈ LLA((10+100*eps())*°,10°,1000)
  ╠═╡ notebook_exclusive =#

# ╔═╡ 1b546f06-aaea-4cfa-b7aa-df41d94c8dbd
#=╠═╡ notebook_exclusive
@test LLA(10°,10°,1000) !== LLA((10+100*eps())*°,10°,1000)
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
	"""
	Elevation, Range and Azimuth for a target point on space as seen from a source point on or above the earth surface
	
	# Fields
	- `el::Float64`: Elevation view angle (`0 <= el <= π/2`) between source and target point [rad].
	- `r::Float64`: Range (`r >= 0`) between the source and target points [m].
	- `az::Float64`: Azimuth view angle between source and target point [rad].
	
	# Constructors
	
		ERA(el::Real,r::Real,az::Real)
		ERA(el::AngleQuantity,r::Real,az::Real)
		ERA(el::AngleQuantity,r::Real,az::AngleQuantity)
		ERA(el,r::Unitful.Length,az)
	
	where `AngleQuantity` is a `Unitful.Quantity` of unit either `u"rad"` or `u"°"`.
	"""
	@with_kw_noshow struct ERA <: SatViewCoordinate
		el::Float64 # Elevation in radians
		r::Float64 # Range in meters
		az::Float64 # Azimuth in radians
		
		function ERA(el::Real,r::Real,az::Real)
			@assert el >= 0 && el <= π/2 "Elevation should be between 0 and π/2"
			@assert r >= 0 "Range must be positive"
			new(el,r,rem2pi(az,RoundNearest))
		end
	end

	# Define a constructor that takes combinations of real numbers and angles/lengths
	ERA(el::AngleQuantity,r::Real,az::Real) = ERA(
		uconvert(u"rad",el) |> ustrip,
		r,
		az,
	)
	ERA(el::AngleQuantity,r::Real,az::AngleQuantity) = ERA(
		el,
		r,
		uconvert(u"rad",az) |> ustrip,
	)
	ERA(el,r::Unitful.Length,az) = ERA(
		el,
		uconvert(u"m",r) |> ustrip,
		az,
	)
	
	# Show
	function Base.show(io::IO,era::ERA)
		print(io,"ERA(")
		_print_angle(io,era.el,"el",false)
		_print_length(io,era.r,"r",false)
		_print_angle(io,era.az,"az",true)
		print(io,")")
	end
end

# ╔═╡ cebf3b11-ae0d-408e-a43b-b71a4561f780
#=╠═╡ notebook_exclusive
@test ERA(10°,1000,20°) == ERA(10°,1km,deg2rad(20)*rad)
  ╠═╡ notebook_exclusive =#

# ╔═╡ 40333531-f0a3-451b-aa52-b6e26b242d34
md"""
# Generic Transformations
"""

# ╔═╡ e2d1cb17-c112-4937-bdb4-9186ff788e41
md"""
The transformations here do not depend on the specific position of the user or the satellite.
"""

# ╔═╡ 0de61675-b5f5-4c57-afdb-f5ae2ff6b0c1
md"""
## ECEF <-> LLA 
"""

# ╔═╡ b0aad62a-01b7-4e16-ac37-d538ceb4c888
begin
	struct ECEFfromLLA <: CoordinateTransformations.Transformation
		ellipsoid::Ellipsoid{Float64}
	end
	struct LLAfromECEF <: CoordinateTransformations.Transformation
		ellipsoid::Ellipsoid{Float64}
	end
	
	Base.inv(t::LLAfromECEF) = ECEFfromLLA(t.ellipsoid)
	Base.inv(t::ECEFfromLLA) = LLAfromECEF(t.ellipsoid)
	
	LLAfromECEF() = LLAfromECEF(wgs84_ellipsoid)
	ECEFfromLLA() = ECEFfromLLA(wgs84_ellipsoid)
	
	function (trans::LLAfromECEF)(ecef::StaticVector{3,<:AbstractFloat})
		el = trans.ellipsoid
		lat,lon,alt = SatelliteToolbox.ecef_to_geodetic(ecef;ellipsoid=el)
		return LLA(lat,lon,alt)
	end
	
	function (trans::ECEFfromLLA)(lat::Number,lon::Number,alt::Number) 
		el = trans.ellipsoid
		ecef = SatelliteToolbox.geodetic_to_ecef(lat,lon,alt;ellipsoid=el)
		return ecef
	end
	(trans::ECEFfromLLA)(lla::LLA) = trans(lla.lat,lla.lon,lla.alt) 
end

# ╔═╡ 90449f44-0ee2-4c07-8306-6dd6b8d5b13a
@benchmark $ECEFfromLLA()($LLA(10°,10°,1000km))

# ╔═╡ 490efc34-046d-49c3-a7ad-8e36c9ed6c62
md"""
## ENU <-> ERA
"""

# ╔═╡ eda8ce97-57cb-4f91-95df-da8263c267e0
quote
	function (::ERAfromENU)(enu::StaticVector{3,T}) where T
	x,y,z = enu
	r = hypot(x, y, z)
	θ = r == 0 ? 0 : acos(z/r)
	ϕ = r == 0 ? 0 : atan(y,x)
	ERA((π/2 - θ) * rad,r * m, ϕ * rad)
end
end |> Meta.dump

# ╔═╡ 7dea3c32-9adf-47cb-880e-83ee272651ec
begin
	# The transformation between ERA and tropocentric is simply a transformation between spherical and cartesian coordinates. While one needs the user location to compute ENU or ERA, the conversion between the two systems (assuming the referene UT to be the same) is indpendent on the specific user location.
struct ERAfromENU <: CoordinateTransformations.Transformation end
struct ENUfromERA <: CoordinateTransformations.Transformation end
	
Base.inv(::ERAfromENU) = ENUfromERA()
Base.inv(::ENUfromERA) = ERAfromENU()
	
function (::ERAfromENU)(enu::StaticVector{3,T}) where T
	x,y,z = enu
	r = hypot(x, y, z)
	θ = r == 0 ? 0 : acos(z/r)
	ϕ = r == 0 ? 0 : atan(y,x)
	ERA((π/2 - θ) * rad,r * m, ϕ * rad)
end
function (::ENUfromERA)(era::ERA)
	θ = π/2 - era.el
	r = era.r
	φ = era.az
	sθ,cθ = sincos(θ)
	sφ,cφ = sincos(φ)
	x = r * sθ * cφ 
	y = r * sθ * sφ 
	z = r * cθ
	# Return the ECEF coordinates
	return SVector(x,y,z)
end
end

# ╔═╡ 8d2fa8ac-71ae-4bc0-9d28-43226e0affd9
#=╠═╡ notebook_exclusive
@test ERAfromENU()(SA_F64[0,0,100e3]) ≈ ERA(90°,100km,0)
  ╠═╡ notebook_exclusive =#

# ╔═╡ 0c91b73b-c1a0-41a0-a958-b2baaf126f58
#=╠═╡ notebook_exclusive
@test ENUfromERA()(ERA(30°,200km,0)) |> ERAfromENU() ≈ ERA(30°,200km,0)
  ╠═╡ notebook_exclusive =#

# ╔═╡ 631f1a17-947e-4d1d-9f0e-ce5d2b934ef8
md"""
# OriginTransformations
"""

# ╔═╡ d5d5004e-da79-436d-9c74-6a4eef92edec
"""
	OriginTransformation <: CoordinateTransformations.Transformation

All `OriginTransformations` are used to transform points in the vicinity of the Earth between Coordinate Reference Systems (CRSs) that do not share the same origin.

These are subtyped into `UserCentricTransformation` and `SatCentricTransformation` depending on whether the reference origin of the transformation is located on the user or on the satellite.

Since the points are assumed to be around Earth, all `OriginTransformations` will have their CRS expressed in ECEF coordinates.

All `OriginTransformation` must have the following 3 fields:
- `origin::Svector{3,Float64}`: The SVector containing the ECEF coordinates of the CRS Origin
- `R::RotMatrix3{Float64}`: The rotation matrix that is needed to rotate between the starting CRS to the target CRS
- `ellipsoid::Ellipsoid{Float64}`: The ellipsoid that is used for computing geodetic points from the transformation
"""
abstract type OriginTransformation <: CoordinateTransformations.Transformation end

# ╔═╡ 7bfbfe62-421f-41bb-9c01-a59fca3fdecf
abstract type UserCentricTransformation <: OriginTransformation end

# ╔═╡ 39f898b6-4b91-410c-b296-fded2b6fbb10
abstract type SatCentricTransformation <: OriginTransformation end

# ╔═╡ f584b127-a13a-4ff2-af00-c603e3a83c6d
md"""
## UserCentric Transformations
"""

# ╔═╡ a1ba94a9-965a-47b0-a2af-1b577a22bd50
md"""
### ECEF <-> ENU
"""

# ╔═╡ 0b255a91-0420-4943-9d2d-669489c07b0d
begin
	# Define the transformations structs and constructors
	@user_transformation ECEF ENU
	
	function (trans::ECEFfromENU)(enu::StaticVector{3,<:AbstractFloat})
		ecef = trans.R * enu + trans.origin
	end
	function (trans::ENUfromECEF)(ecef::StaticVector{3,<:AbstractFloat})
		enu = trans.R * (ecef - trans.origin)
	end
end	

# ╔═╡ 3a4b0cd8-aa77-412d-b512-6daaceefc481
# Test that doing forward and reverse pass leads to the same original LLA point
@test (LLA(10°,15°,1000) |> ECEFfromLLA() |> ENUfromECEF(LLA(12°,12°,0)) |> ECEFfromENU(LLA(12°,12°,0)) |> LLAfromECEF()) ≈ LLA(10°,15°,1000)

# ╔═╡ 8ed9af12-2fff-4e87-a5d8-8fc823125d1f
# Test that the inversion works properly
@test SA_F64[1e6,1e6,1e6] |> ENUfromECEF(LLA(22°,12°,0)) |> inv(ENUfromECEF(LLA(22°,12°,0))) ≈ SA_F64[1e6,1e6,1e6]

# ╔═╡ ceb05ca6-adea-420a-bcc0-809c19709da2
# Test that the enu coordinates with CRS origin on the equator/greenwhich meridian for a point that has only X ECEF coordinates results in an ENU coordinate that only has the third component
@test ENUfromECEF(LLA(0,0,0);ellipsoid=Ellipsoid(6371e3,0))(SA_F64[1e7,0,0]) ≈ SA_F64[0,0,1e7-6371e3]

# ╔═╡ 11fbbb1a-dbe0-4501-99be-1a32843e4f63
#=╠═╡ notebook_exclusive
ecef2enu = ENUfromECEF(LLA(0,0,0))
  ╠═╡ notebook_exclusive =#

# ╔═╡ fbc17dea-1228-483b-a369-52cf1ec6de10
#=╠═╡ notebook_exclusive
ecef_example = SA_F64[1e6,1e6,1e6]
  ╠═╡ notebook_exclusive =#

# ╔═╡ f48de77f-bc86-4a48-b422-b1283ba469a0
#=╠═╡ notebook_exclusive
@benchmark $ERAfromENU()($ecef_example)
  ╠═╡ notebook_exclusive =#

# ╔═╡ c118d97b-9f00-4729-bec3-d4860d1ada53
#=╠═╡ notebook_exclusive
let
	era = ERAfromENU()(ecef_example)
	@benchmark $ENUfromERA()($era)
end
  ╠═╡ notebook_exclusive =#

# ╔═╡ 6690727c-1adb-4334-a756-609bf8386693
md"""
### ERA <-> ECEF
"""

# ╔═╡ dd231bb5-fc61-46ad-acb9-d21e75b2c618
md"""
The transformations defined here allow going from the ECEF coordinates of a satellite to the elevation range and azimuth as seen from a point on ground (which is the tropocentric origin used for the transformation).

The satellite position is expected in ECEF because the altitude of a satellite in orbit above the reference ellipsoid changes with latitude (if the ellipsoid is not a sphere), so by forcing the user to provide ECEF coordinates one has to think about the transformation and there is less risk of putting the same reference orbit altitude regardless of the latitude
"""

# ╔═╡ cf2b533c-810f-4b28-bb11-796686a501fa
begin
	@user_transformation ECEF ERA
	function (trans::ECEFfromERA)(era::ERA)
		ecef = trans.R * ENUfromERA()(era) + trans.origin
	end
	function (trans::ERAfromECEF)(ecef::StaticVector{3,<:AbstractFloat})
		era = ERAfromENU()(trans.R * (ecef - trans.origin))
	end
end	

# ╔═╡ 8cbfefcb-7d3d-49bd-ab6d-d561e118d211
#=╠═╡ notebook_exclusive
ecef2era = ERAfromECEF(LLA(0,0,0))
  ╠═╡ notebook_exclusive =#

# ╔═╡ 8c493d0e-5e87-45d5-a118-3bd025ff6ea0
#=╠═╡ notebook_exclusive
# Test correct forward and reverse pass
@test ERA(10°,600km,20°) |> ECEFfromERA(LLA(10°,20°,0)) |> ERAfromECEF(LLA(10°,20°,0)) ≈ ERA(10°,600km,20°)
  ╠═╡ notebook_exclusive =#

# ╔═╡ e289acf4-2390-4c5f-8183-0584da9195c4
#=╠═╡ notebook_exclusive
# Test that elevation is 90 for a point above
@test ecef2era(SA_F64[wgs84_ellipsoid.a + 600e3,0,0]) ≈ ERA(90°,600km,0°)
  ╠═╡ notebook_exclusive =#

# ╔═╡ b7318a55-2544-4f00-b815-d73854fae191
#=╠═╡ notebook_exclusive
ecef2era(SA_F64[wgs84_ellipsoid.a + 600e3,1e3,0])
  ╠═╡ notebook_exclusive =#

# ╔═╡ 5d3f7abb-a5a1-47a9-acac-0d5c58c7043c
#=╠═╡ notebook_exclusive
ecef2era(SA_F64[wgs84_ellipsoid.a + 600e3,1e3,1e3])
  ╠═╡ notebook_exclusive =#

# ╔═╡ 23b0b1d4-1de0-4e83-be23-45236319f70a
md"""
## Satellite-Centric transformations
"""

# ╔═╡ a418f9b9-c3a8-4054-abd7-d29df23f8772
md"""
The computation of the lat/long position of a point on earth given the view angle (θ,φ or u,v) from the satellite can easily be performed exploiting spherical trigonometry when assuming the earth to be a sphere.

When considering the more appropriate ellipsoid of revolution model, computations become a bit more complex but the formulation can be found in [this recent paper](https://arc.aiaa.org/doi/10.2514/1.G004156)

The paper exploits the cosine directions of the pointing from the spacecraft, expressed in the earth reference frame. These can be obtained directly from the pointing U,V coordinates from the satellite point of view by performing a rotation.

We will identify the SatView CRS with axis names ``U``, ``V`` and ``W``; with axis ``W`` pointing towards the nadir direction, axis ``V`` pointing towards North and ``U`` pointing towards West (so as to have ``UVW`` following the right-hand rule).

Similarly, we will identify the earth reference frame with axes named ``X``, ``Y`` and ``Z`` and following the standard ECEF orientation with ``Z`` exiting the north pole, ``X`` exiting the equator at the longitude of the greenwhich meridian and ``Y`` pointed according to the right-hand rule.

The rotation needed to go from SatView to ECEF coordinates is the one needed to have bring the ``UVW`` axes to coincide with the ``XYZ`` ones (except the translation to align the origins).
It easy to prove that this can be achieved by rotating ``UVW`` first around ``U`` counter-clockwise by ``α = 270° - lat_s`` (obtaining the rotated CRS ``U'V'W'``), and then around ``W'`` counter-clockwise by ``γ = 90° - lon_s`` 



Exploiting the definitions of [rotation matrices](https://en.wikipedia.org/wiki/Rotation_matrix#Basic_rotations) and remembering that for change of CRS we are dealing with [*passive*](https://en.wikipedia.org/wiki/Active_and_passive_transformation) transformations, we can define the rotation matrix to translate points defined in the SatView CRS to the earth reference frame CRS as:
$(texeq("
\\mathbf{R}_{S→E} = 
\\begin{bmatrix}
	{\\rm sin}(lon_s) & -{\\rm sin}(lat_s){\\rm cos}(lon_s)& -{\\rm cos}(lat_s){\\rm cos}(lon_s) \\
	-{\\rm cos}(lon_s) & -{\\rm sin}(lat_s){\\rm sin}(lon_s) & - {\\rm cos}(lat_s){\\rm sin}(lon_s) \\
	0 & {\\rm cos}(lat_s) & -{\\rm sin}(lat_s)
\\end{bmatrix}
"))

"""

# ╔═╡ a9bf7958-4f16-4c54-bde5-eaf4b22708c7
function _intersection_solutions(pointing_ecef,sat_ecef,a,b)
	# Create the vector containing the parameters of the ellipse
	ellps_coeffs = SA_F64[b,b,a]
	
	# Create the vectors used to conveniently represent the 2nd degree equation of t in the paper (equation above (38))
	v1 = pointing_ecef .* ellps_coeffs
	v2 = sat_ecef .* ellps_coeffs
	
	# Find the variables to solve the quadratic equation
	α = v1'v1
	β = 2v1'v2
	γ = v2'v2 - (a*b)^2
	
	# Compute the discriminant
	Δ = β^2 - 4*α*γ
	
	# If the discriminant is negative, no intersection exists
	Δ < 0 && return NaN,NaN
	

	# Compute the two possible values of t
	t₁ = (-β - √Δ)/2α	
	t₂ = (-β + √Δ)/2α
	
	return t₁,t₂
end

# ╔═╡ 5b226be3-ad65-4cb1-9226-20786c76c4c1
# Get the ECEF coordinates of the point where the direction of view from the satellite intercept the earth 
function earth_intersection(pointing_ecef,sat_ecef,a,b)
	
	t₁,t₂ = _intersection_solutions(pointing_ecef,sat_ecef,a,b)
	
	# If no solution exists, t₁ is NaN, so we return a 3d NaN vector
	isnan(t₁) && return SA_F64[NaN,NaN,NaN]
	
	t = abs(t₁) < abs(t₂) ? t₁ : t₂
	
	# Compute the ecef coordinates of the intersectinon on earth
	ecef = sat_ecef + t*pointing_ecef
end

# ╔═╡ 7510f18b-dcb5-47ec-95b2-b5b13ff49288
#=╠═╡ notebook_exclusive
@benchmark $earth_intersection(SA_F64[-.944818,-.200827,-.258819],SA_F64[1.23781e7,1000,1000],6.37814e6,6.35675e6)
  ╠═╡ notebook_exclusive =#

# ╔═╡ ee48ec54-9aee-4b27-823e-8c4ab08ebc31
#=╠═╡ notebook_exclusive
# Test the results with the matlab outputs
@test earth_intersection([-.944818,-.200827,-.258819],[1.23781e7,1000,1000],6.37814e6,6.35675e6) ≈ [5978510.87809898,-1359272.86163475,-1752073.3505726]
  ╠═╡ notebook_exclusive =#

# ╔═╡ 8635e24e-66cc-4390-91a6-f19bd980c313
md"""
### ECEF <-> UV
"""

# ╔═╡ 33c44e13-14fd-4c30-bde4-7e37f0f83b6e
begin
	# Define the transformations structs and constructors
	@sat_transformation ECEF UV
	
	function (trans::ECEFfromUV)(uv::StaticVector{2,<:AbstractFloat},h::Real=0.0)
		# Check that the uv coordinates are valid
		uv² = sum(uv .^ 2)
		@assert uv² <= 1 "u² + v² > 1, the given uv coordinate vector is not valid"
		# Compute the 3d versor identifying the pointing direction from the satellite in WND coordinates
		p̂ = SA_F64[uv..., sqrt(1 - uv²)]
		# Translate the versor in ECEF coordinates
		n̂ = trans.R * p̂
		sat_ecef = trans.origin
		a,b = trans.ellipsoid.a, trans.ellipsoid.b
		ecef = earth_intersection(n̂,sat_ecef,a+h,b+h)
	end
	
	function (trans::UVfromECEF)(ecef::StaticVector{3,<:AbstractFloat})
		# Check if the given ecef coordinate is visible from the satellite position or is obstructed from earth
		pdiff = (ecef - trans.origin)
		
		# Find the magnitude of the difference to compare with the intersection solutions
		t = norm(pdiff)
		
		# Find the intersection points with the ellipsoid
		t₁,t₂ = _intersection_solutions(pdiff./t,trans.origin,trans.ellipsoid.a,trans.ellipsoid.b)
		
		# If both t₁ and t₂ are NaN, it means that no intersection with the ellipsoid is found and so there is no earth blockage
		# If t <= t₁ also no blockage is present
		# If t > t₁ then the earth is blocking the view point so we return NaN
		
		# The 1e-3 is there because the computed distance might have some error that is usually way below one mm, and 1mm shouldn't change anything for our required precision
		!isnan(t₁) && t > t₁+1e-3 && return SA_F64[NaN,NaN]
		
		# Find the coordinates in the West-North-Down CRS
		wnd = trans.R * pdiff
		
		# Normalize the wnd vector
		uv = SVector(wnd[1],wnd[2]) ./  norm(wnd)
	end
end	

# ╔═╡ dacae45f-d877-4a39-828c-d00abab44cca
#=╠═╡ notebook_exclusive
ecef2uv = UVfromECEF(LLA(20°,180°,600km))
  ╠═╡ notebook_exclusive =#

# ╔═╡ a906a763-6996-4bae-8589-1433e78c9ee8
#=╠═╡ notebook_exclusive
@benchmark $ecef2uv(SA_F64[1e7,1e6,1e6])
  ╠═╡ notebook_exclusive =#

# ╔═╡ 14d6099f-4ac9-4935-9110-1742a121e285
#=╠═╡ notebook_exclusive
@benchmark $(inv(ecef2uv))(SA_F64[.1,.1])
  ╠═╡ notebook_exclusive =#

# ╔═╡ 96d534eb-53c1-4b3c-a4e8-15da01d3b9e5
#=╠═╡ notebook_exclusive
_intersection_solutions(ecef2uv.R' * SA_F64[0,0,1],ecef2uv.origin,ecef2uv.ellipsoid.a,ecef2uv.ellipsoid.b)
  ╠═╡ notebook_exclusive =#

# ╔═╡ 413f7721-57f3-4406-93c3-9d7dfae890ef
md"""
### LLA <-> UV
"""

# ╔═╡ 9858a275-4255-4e5d-9538-9f961f349f9a
md"""
We define here the transformations to switch between the satellite point of view in UV and the geodesic coordinates (LLA) of points on or above earth.
The computation is performed accounting for a custom ellipsoid shape of the earth (defaults to the WGS84 one) and an optional target height (above the reference ellipsoid) can be provided when going from UV to LLA.
This target height is used to find the correct geodesic coordinate lat,long when extending the satellite view direction to find the intersection (the same pointing direction results in different lat,long values depending on the target height).
"""

# ╔═╡ 28d6c2a9-80e3-4aa3-aa48-add2e2c9be06
begin
	# Define the transformations structs and constructors
	@sat_transformation UV LLA
	
	function (trans::LLAfromUV)(uv::StaticVector{2,<:AbstractFloat},h::Real=0.0)
		ecef = ECEFfromUV(trans.origin,trans.R,trans.ellipsoid)(uv,h)
		lla = LLAfromECEF(trans.ellipsoid)(ecef)
	end
	function (trans::UVfromLLA)(lla::LLA)
		ecef = ECEFfromLLA(trans.ellipsoid)(lla)
		uv = UVfromECEF(trans.origin,trans.R,trans.ellipsoid)(ecef)
	end
end	

# ╔═╡ c98d3ea3-e146-40e6-ac02-500b4c0d5d78
begin
	export Ellipsoid, LLA, ERA
	export LLAfromECEF, ECEFfromLLA, LLAfromUV, UVfromLLA, ECEFfromENU, ENUfromECEF, ERAfromENU, ENUfromERA, ERAfromECEF, ECEFfromERA, ECEFfromUV, UVfromECEF
end

# ╔═╡ 20819552-af3f-4734-b285-0f994de3d543
#=╠═╡ notebook_exclusive
lla2uv = UVfromLLA(LLA(0°,0°,37000km))
  ╠═╡ notebook_exclusive =#

# ╔═╡ c9c555b4-1bd2-4d05-b9a2-37aed95f4e0f
#=╠═╡ notebook_exclusive
@benchmark $lla2uv($LLA(10°,10°,600km))
  ╠═╡ notebook_exclusive =#

# ╔═╡ a2b6236c-34cd-4d58-8c5c-5b5245da77c1
#=╠═╡ notebook_exclusive
uv2lla = LLAfromUV(LLA(0°,0°,37000km))
  ╠═╡ notebook_exclusive =#

# ╔═╡ 4172882d-7483-4701-a100-d79b308b046d
#=╠═╡ notebook_exclusive
let
	h_target = 1e3
	lla = LLA(81.5°,0°,h_target)
	lla2 = (inv(uv2lla)(lla) |> x -> uv2lla(x,h_target))
	ecef1 = ECEFfromLLA(uv2lla.ellipsoid)(lla)
	ecef2 = ECEFfromLLA(uv2lla.ellipsoid)(lla2)
	# # less than 1m distance between the origin and the forward + return transformation
	@test norm($ecef1 - $ecef2) < 1
end
  ╠═╡ notebook_exclusive =#

# ╔═╡ 083aa535-893a-4f7d-bbd1-a1f4a00040ac
#=╠═╡ notebook_exclusive
uvvct = [@SVector(rand(2))./10 for _ in 1:1000] 
  ╠═╡ notebook_exclusive =#

# ╔═╡ 2b6e1005-9889-4318-afa9-289a0f15c1fe
#=╠═╡ notebook_exclusive
@benchmark $uv2lla(SVector(.1,.1))
  ╠═╡ notebook_exclusive =#

# ╔═╡ eb120cf3-3aaf-4a47-a723-bf849b9dcc20
#=╠═╡ notebook_exclusive
@benchmark $uv2lla.($uvvct)
  ╠═╡ notebook_exclusive =#

# ╔═╡ 308c1273-ed27-478a-bed4-249a0699629e
#=╠═╡ notebook_exclusive
let
	uv2lla = LLAfromUV(LLA(0,0,600km);ellipsoid=Ellipsoid(6371e3,0))
	lla = uv2lla.(uvvct)
	# Save the values of uv in a mat file for checking with matlab
	matwrite(raw"C:\temp\diogesu.mat",Dict(
			"u" => -map(first,uvvct), # U coordinate is opposite in the matlab script
			"v" => map(last,uvvct),
			"lat" => map(x -> rad2deg(x.lat),lla),
			"lon" => map(x -> rad2deg(x.lon),lla)
			),compress=true)
end
  ╠═╡ notebook_exclusive =#

# ╔═╡ d9ecf801-1738-43f3-a417-bb38785d418c
#=╠═╡ notebook_exclusive
# Test that givin uv coordinates with norm greater than 1 throws an error
@test try
	uv2lla(SVector(1,.5))
	return false
catch e
	if e.msg == "u² + v² > 1, the given uv coordinate vector is not valid"
		return true
	else
		return false
	end
end
  ╠═╡ notebook_exclusive =#

# ╔═╡ d173f856-70fb-4f4c-aaf2-ea236a0bd8d8
md"""
# Geodesic Problem
"""

# ╔═╡ 57aa5b4b-9deb-422f-bc92-bde0b0b78df1
md"""
To compute geodesics (lines on the surface of the earth between two points on earth) we still revert to using Proj4 as there is currently no Julia implementation available in the general registry (Geodesy.jl does not have a way to compute the geodesic distance betwee points but only the euclidean distance)
"""

# ╔═╡ fbae2a28-248d-4aaf-9006-b46574a1706d
begin
	"""
	Solve the inverse geodesic problem.

	Args:

		g       - the geod_geodesic object specifying the ellipsoid.
		lonlat1 - point 1 (degrees), where lat ∈ [-90, 90], lon ∈ [-540, 540) 
		lonlat2 - point 2 (degrees), where lat ∈ [-90, 90], lon ∈ [-540, 540) 

	Returns:

		dist    - distance between point 1 and point 2 (meters).
		azi1    - azimuth at point 1 (degrees) ∈ [-180, 180)
		azi2    - (forward) azimuth at point 2 (degrees) ∈ [-180, 180)

	Remarks:

		If either point is at a pole, the azimuth is defined by keeping the longitude fixed,
		writing lat = 90 +/- eps, and taking the limit as eps -> 0+.
	"""
	function geod_inverse(geod::geod_geodesic, lonlat1::AbstractVector{Cdouble}, lonlat2::AbstractVector{Cdouble})
		dist = Ref{Cdouble}()
		azi1 = Ref{Cdouble}()
		azi2 = Ref{Cdouble}()
		ccall((:geod_inverse, libproj), Cvoid, (Ptr{Cvoid},Cdouble,Cdouble,Cdouble,
			  Cdouble,Ptr{Cdouble},Ptr{Cdouble},Ptr{Cdouble}),
			  pointer_from_objref(geod), lonlat1[2], lonlat1[1], lonlat2[2], lonlat2[1], dist, azi1, azi2)
		dist[], azi1[], azi2[]
	end
	
	function geod_inverse(geod::geod_geodesic, lla1::LLA, lla2::LLA)
		lonlat1 = rad2deg.(SA_F64[lla1.lat,lla1.lon])
		lonlat2 = rad2deg.(SA_F64[lla2.lat,lla2.lon])
		geod_inverse(geod,lonlat1,lonlat2)
	end
end

# ╔═╡ f0eafa90-7df9-4630-b819-28682ee54f06
# Define the constructor starting from an Ellipsoid struct
Proj4.geod_geodesic(e::Ellipsoid) = Proj4.geod_geodesic(e.a,e.f)

# ╔═╡ a8d264bb-3fb0-43c7-86a8-1d23dfe476db
#=╠═╡ notebook_exclusive
geod_geodesic(wgs84_ellipsoid)
  ╠═╡ notebook_exclusive =#

# ╔═╡ a066f0bd-0229-48ee-9d2b-7de2f6900d4d
#=╠═╡ notebook_exclusive
geod = geod_geodesic(wgs84_ellipsoid.a,wgs84_ellipsoid.f)
  ╠═╡ notebook_exclusive =#

# ╔═╡ 0df6bd80-3d2f-4192-8a90-96c762b10b26
#=╠═╡ notebook_exclusive
geod_inverse(geod,LLA(0°,0°,0km),LLA(10°,10°,0km))
  ╠═╡ notebook_exclusive =#

# ╔═╡ eb222935-5c6c-49e7-ac84-6a68d1eede3e
#=╠═╡ notebook_exclusive
@benchmark $geod_inverse($geod,$LLA(10°,10°,0km),$LLA(0°,0°,0km))
  ╠═╡ notebook_exclusive =#

# ╔═╡ b9f15ab3-b4d9-4ab0-ad20-95f9ef815eb2
#=╠═╡ notebook_exclusive
begin
	lla1vec = [LLA(rand(),rand(),rand()) for _ in 1:1000]
	lla2vec = [LLA(rand(),rand(),rand()) for _ in 1:1000]
end
  ╠═╡ notebook_exclusive =#

# ╔═╡ c785db0d-82e7-471a-9eb0-037c9d73ccb0
#=╠═╡ notebook_exclusive
@benchmark $geod_inverse.(Ref($geod),$lla1vec,$lla2vec)
  ╠═╡ notebook_exclusive =#

# ╔═╡ 75dba6d8-441d-4af7-b951-b651f94651a3
#=╠═╡ notebook_exclusive
geod
  ╠═╡ notebook_exclusive =#

# ╔═╡ e083dca9-f8d0-4968-b889-079e4c1ffd6f
#=╠═╡ notebook_exclusive
wgs84_ellipsoid
  ╠═╡ notebook_exclusive =#

# ╔═╡ 434ef478-3298-4ea7-b8cb-161181abdb2a
md"""
# Satellite View
"""

# ╔═╡ 896d37cc-38be-497c-bdd3-8189327aaacb


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
MAT = "23992714-dd62-5051-b70f-ba57cb901cac"
MacroTools = "1914dd2f-81c6-5fcd-8719-6d5c9610ff09"
Parameters = "d96e819e-fc66-5662-9728-84c9c7592b0a"
PlutoTest = "cb4044da-4d16-4ffa-a6a3-8cad7f73ebdc"
PlutoUtils = "ed5d0301-4775-4676-b788-cf71e66ff8ed"
Proj4 = "9a7e659c-8ee8-5706-894e-f68f43bc57ea"
Rotations = "6038ab10-8711-5258-84ad-4b1120ba62dc"
SatelliteToolbox = "6ac157d9-b43d-51bb-8fab-48bf53814f4a"
StaticArrays = "90137ffa-7385-5640-81b9-e52037218182"
Unitful = "1986cc42-f94f-5a68-af5c-568840ba703d"

[compat]
BenchmarkTools = "~1.1.4"
CoordinateTransformations = "~0.6.1"
DocStringExtensions = "~0.8.5"
MAT = "~0.10.1"
MacroTools = "~0.5.7"
Parameters = "~0.12.2"
PlutoTest = "~0.1.0"
PlutoUtils = "~0.3.4"
Proj4 = "~0.7.6"
Rotations = "~1.0.2"
SatelliteToolbox = "~0.9.3"
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
git-tree-sha1 = "42ac5e523869a84eac9669eaceed9e4aa0e1587b"
uuid = "6e4b80f9-dd63-53aa-95a3-0cdb28fa8baf"
version = "1.1.4"

[[deps.Blosc]]
deps = ["Blosc_jll"]
git-tree-sha1 = "84cf7d0f8fd46ca6f1b3e0305b4b4a37afe50fd6"
uuid = "a74b3585-a348-5f62-a45c-50e91977d574"
version = "0.7.0"

[[deps.Blosc_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl", "Lz4_jll", "Pkg", "Zlib_jll", "Zstd_jll"]
git-tree-sha1 = "e747dac84f39c62aff6956651ec359686490134e"
uuid = "0b7ba130-8d10-5ba8-a3d6-c5182647fed9"
version = "1.21.0+0"

[[deps.BufferedStreams]]
deps = ["Compat", "Test"]
git-tree-sha1 = "5d55b9486590fdda5905c275bb21ce1f0754020f"
uuid = "e1450e63-4bb3-523b-b2a4-4ffa8c0fd77d"
version = "1.0.0"

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

[[deps.CodecZlib]]
deps = ["TranscodingStreams", "Zlib_jll"]
git-tree-sha1 = "ded953804d019afa9a3f98981d99b33e3db7b6da"
uuid = "944b1d66-785c-5afd-91f1-9de20f533193"
version = "0.7.0"

[[deps.Compat]]
deps = ["Base64", "Dates", "DelimitedFiles", "Distributed", "InteractiveUtils", "LibGit2", "Libdl", "LinearAlgebra", "Markdown", "Mmap", "Pkg", "Printf", "REPL", "Random", "SHA", "Serialization", "SharedArrays", "Sockets", "SparseArrays", "Statistics", "Test", "UUIDs", "Unicode"]
git-tree-sha1 = "727e463cfebd0c7b999bbf3e9e7e16f254b94193"
uuid = "34da2185-b29b-5c13-b0c7-acf172513d20"
version = "3.34.0"

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
git-tree-sha1 = "937c29268e405b6808d958a9ac41bfe1a31b08e7"
uuid = "5789e2e9-d7fb-5bc7-8068-2c6fae9b9549"
version = "1.11.0"

[[deps.Formatting]]
deps = ["Printf"]
git-tree-sha1 = "8339d61043228fdd3eb658d86c926cb282ae72a8"
uuid = "59287772-0a20-5a39-b81b-1366585eb4c0"
version = "0.4.2"

[[deps.Glob]]
git-tree-sha1 = "4df9f7e06108728ebf00a0a11edee4b29a482bb2"
uuid = "c27321d9-0574-5035-807b-f59d2c89b15c"
version = "1.3.0"

[[deps.HDF5]]
deps = ["Blosc", "Compat", "HDF5_jll", "Libdl", "Mmap", "Random", "Requires"]
git-tree-sha1 = "83173193dc242ce4b037f0263a7cc45afb5a0b85"
uuid = "f67ccb44-e63f-5c2f-98bd-6dc0ccc4ba2f"
version = "0.15.6"

[[deps.HDF5_jll]]
deps = ["Artifacts", "JLLWrappers", "LibCURL_jll", "Libdl", "OpenSSL_jll", "Pkg", "Zlib_jll"]
git-tree-sha1 = "fd83fa0bde42e01952757f01149dd968c06c4dba"
uuid = "0234f1f7-429e-5d53-9886-15a909be8d59"
version = "1.12.0+1"

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

[[deps.Lz4_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl", "Pkg"]
git-tree-sha1 = "5d494bc6e85c4c9b626ee0cab05daa4085486ab1"
uuid = "5ced341a-0733-55b8-9ab6-a4889d929147"
version = "1.9.3+0"

[[deps.MAT]]
deps = ["BufferedStreams", "CodecZlib", "HDF5", "SparseArrays"]
git-tree-sha1 = "5c62992f3d46b8dce69bdd234279bb5a369db7d5"
uuid = "23992714-dd62-5051-b70f-ba57cb901cac"
version = "0.10.1"

[[deps.MacroTools]]
deps = ["Markdown", "Random"]
git-tree-sha1 = "0fb723cd8c45858c22169b2e42269e53271a6df7"
uuid = "1914dd2f-81c6-5fcd-8719-6d5c9610ff09"
version = "0.5.7"

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

[[deps.OpenSSL_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl", "Pkg"]
git-tree-sha1 = "15003dcb7d8db3c6c857fda14891a539a8f2705a"
uuid = "458c3c95-2e84-50aa-8efc-19380b2a3a95"
version = "1.1.10+0"

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
git-tree-sha1 = "438d35d2d95ae2c5e8780b330592b6de8494e779"
uuid = "69de0a69-1ddd-5017-9359-2bf0b02dc9f0"
version = "2.0.3"

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
git-tree-sha1 = "5f15f1c647b563e49f655fbbfd4e2ade24bd3c64"
uuid = "9a7e659c-8ee8-5706-894e-f68f43bc57ea"
version = "0.7.6"

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
git-tree-sha1 = "45e428421666073eab6f2da5c9d310d99bb12f9b"
uuid = "189a3867-3050-52da-a836-e630ba90ab69"
version = "1.2.2"

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
git-tree-sha1 = "0a2c0f1565a51487fe58c28f528675dba1008432"
uuid = "6ac157d9-b43d-51bb-8fab-48bf53814f4a"
version = "0.9.3"

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

[[deps.TranscodingStreams]]
deps = ["Random", "Test"]
git-tree-sha1 = "216b95ea110b5972db65aa90f88d8d89dcb8851c"
uuid = "3bb67fe8-82b1-5028-8e26-92a6c54297fa"
version = "0.9.6"

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
# ╠═9e29c3ea-2cda-4726-86a3-20cabdb20245
# ╠═74422a23-0760-470f-9e1e-43b8c3972f65
# ╠═2ad47a80-881a-4ac5-a61e-0691e6bf35e0
# ╠═77e399b7-0f7e-4ff1-9f8e-fd0f3408e894
# ╟─367ad569-495a-458b-806d-e5e40db12e1a
# ╠═c98d3ea3-e146-40e6-ac02-500b4c0d5d78
# ╟─0573442d-30bc-44c0-9f69-83589e8f2870
# ╟─31fd624c-c86d-4910-8f93-c7d91641d206
# ╠═b8b5f9f6-2e39-42ea-bd47-f7174f726472
# ╠═aa58d03c-a42b-4b0c-84b4-566d154d7f90
# ╟─184f69ae-06d3-4f6d-8526-dd4ab30fadad
# ╠═352da29b-e1ff-41cf-a7be-b7318056ca3f
# ╠═f5e22bff-efc9-4a3c-a70f-8e800d325ae8
# ╠═3179c657-aa27-4465-8a90-51ec991701c8
# ╠═3d630992-f6f5-4af2-beea-171428580037
# ╠═5c450408-fa09-4325-b4f1-422ff7f77b30
# ╟─e925d962-e6fb-464e-8686-3fa18bc2342b
# ╠═43a98a86-f0ba-4b99-b808-1e698b44a202
# ╟─04c443a3-baf1-4f18-9a3e-71ab9421d45d
# ╠═23e1bad7-1df2-48e7-a111-268c5d61a6e5
# ╠═3a4ffc22-5ace-4cc8-aaa0-5eb91b1ac5f8
# ╠═0296570a-1982-4532-94aa-99004173aa00
# ╠═5f7d011b-9e54-4174-9eda-86182fc6be06
# ╠═12f9aea4-4dc4-41be-ab95-bda99bd26de1
# ╟─b7587ba5-193b-40ee-a0e8-fd4251d6ba66
# ╠═d070e629-59b0-4a69-9ece-e76640a19c2e
# ╠═e61dc24f-3e1f-4dcd-9568-902e9d4ae686
# ╟─bb47e669-bf83-405e-bfe1-fb35c3c13d4c
# ╠═0ad5adbf-4ffa-4a8b-bc3d-a2668d8495eb
# ╟─bf534d5c-b861-4c4c-b645-7848b3eaf0fe
# ╟─f0758e99-9f2b-4934-88eb-7e62cdd5c51f
# ╠═a6644ab1-8561-4105-9ae3-ec021be62c9b
# ╠═007644ab-e85e-4a9f-a58b-32ead002a461
# ╠═11e7154b-9da0-46be-9486-a3a028520fb5
# ╠═23ae9323-9059-43cd-8efa-8a75a10ac236
# ╠═1b546f06-aaea-4cfa-b7aa-df41d94c8dbd
# ╟─5081a3aa-1c19-4a30-aaea-188b9732240f
# ╟─65efffbf-1fe8-48c1-9f47-de3d590b5c15
# ╠═1ca4f2bb-a865-49de-9899-e1ae93ae29be
# ╠═cebf3b11-ae0d-408e-a43b-b71a4561f780
# ╟─40333531-f0a3-451b-aa52-b6e26b242d34
# ╟─e2d1cb17-c112-4937-bdb4-9186ff788e41
# ╟─0de61675-b5f5-4c57-afdb-f5ae2ff6b0c1
# ╠═b0aad62a-01b7-4e16-ac37-d538ceb4c888
# ╠═90449f44-0ee2-4c07-8306-6dd6b8d5b13a
# ╟─490efc34-046d-49c3-a7ad-8e36c9ed6c62
# ╠═eda8ce97-57cb-4f91-95df-da8263c267e0
# ╠═7dea3c32-9adf-47cb-880e-83ee272651ec
# ╠═8d2fa8ac-71ae-4bc0-9d28-43226e0affd9
# ╠═0c91b73b-c1a0-41a0-a958-b2baaf126f58
# ╠═f48de77f-bc86-4a48-b422-b1283ba469a0
# ╠═c118d97b-9f00-4729-bec3-d4860d1ada53
# ╟─631f1a17-947e-4d1d-9f0e-ce5d2b934ef8
# ╠═d5d5004e-da79-436d-9c74-6a4eef92edec
# ╠═7bfbfe62-421f-41bb-9c01-a59fca3fdecf
# ╠═39f898b6-4b91-410c-b296-fded2b6fbb10
# ╟─f584b127-a13a-4ff2-af00-c603e3a83c6d
# ╟─a1ba94a9-965a-47b0-a2af-1b577a22bd50
# ╠═0b255a91-0420-4943-9d2d-669489c07b0d
# ╠═3a4b0cd8-aa77-412d-b512-6daaceefc481
# ╠═8ed9af12-2fff-4e87-a5d8-8fc823125d1f
# ╠═ceb05ca6-adea-420a-bcc0-809c19709da2
# ╠═11fbbb1a-dbe0-4501-99be-1a32843e4f63
# ╠═fbc17dea-1228-483b-a369-52cf1ec6de10
# ╟─6690727c-1adb-4334-a756-609bf8386693
# ╟─dd231bb5-fc61-46ad-acb9-d21e75b2c618
# ╠═cf2b533c-810f-4b28-bb11-796686a501fa
# ╠═8cbfefcb-7d3d-49bd-ab6d-d561e118d211
# ╠═8c493d0e-5e87-45d5-a118-3bd025ff6ea0
# ╠═e289acf4-2390-4c5f-8183-0584da9195c4
# ╠═b7318a55-2544-4f00-b815-d73854fae191
# ╠═5d3f7abb-a5a1-47a9-acac-0d5c58c7043c
# ╟─23b0b1d4-1de0-4e83-be23-45236319f70a
# ╟─a418f9b9-c3a8-4054-abd7-d29df23f8772
# ╠═5b226be3-ad65-4cb1-9226-20786c76c4c1
# ╠═a9bf7958-4f16-4c54-bde5-eaf4b22708c7
# ╠═7510f18b-dcb5-47ec-95b2-b5b13ff49288
# ╠═ee48ec54-9aee-4b27-823e-8c4ab08ebc31
# ╟─8635e24e-66cc-4390-91a6-f19bd980c313
# ╠═33c44e13-14fd-4c30-bde4-7e37f0f83b6e
# ╠═dacae45f-d877-4a39-828c-d00abab44cca
# ╠═a906a763-6996-4bae-8589-1433e78c9ee8
# ╠═14d6099f-4ac9-4935-9110-1742a121e285
# ╠═96d534eb-53c1-4b3c-a4e8-15da01d3b9e5
# ╟─413f7721-57f3-4406-93c3-9d7dfae890ef
# ╟─9858a275-4255-4e5d-9538-9f961f349f9a
# ╠═28d6c2a9-80e3-4aa3-aa48-add2e2c9be06
# ╠═20819552-af3f-4734-b285-0f994de3d543
# ╠═c9c555b4-1bd2-4d05-b9a2-37aed95f4e0f
# ╠═a2b6236c-34cd-4d58-8c5c-5b5245da77c1
# ╠═4172882d-7483-4701-a100-d79b308b046d
# ╠═083aa535-893a-4f7d-bbd1-a1f4a00040ac
# ╠═2b6e1005-9889-4318-afa9-289a0f15c1fe
# ╠═eb120cf3-3aaf-4a47-a723-bf849b9dcc20
# ╠═308c1273-ed27-478a-bed4-249a0699629e
# ╠═d9ecf801-1738-43f3-a417-bb38785d418c
# ╟─d173f856-70fb-4f4c-aaf2-ea236a0bd8d8
# ╟─57aa5b4b-9deb-422f-bc92-bde0b0b78df1
# ╠═fbae2a28-248d-4aaf-9006-b46574a1706d
# ╠═f0eafa90-7df9-4630-b819-28682ee54f06
# ╠═a8d264bb-3fb0-43c7-86a8-1d23dfe476db
# ╠═a066f0bd-0229-48ee-9d2b-7de2f6900d4d
# ╠═0df6bd80-3d2f-4192-8a90-96c762b10b26
# ╠═eb222935-5c6c-49e7-ac84-6a68d1eede3e
# ╠═b9f15ab3-b4d9-4ab0-ad20-95f9ef815eb2
# ╠═c785db0d-82e7-471a-9eb0-037c9d73ccb0
# ╠═75dba6d8-441d-4af7-b951-b651f94651a3
# ╠═e083dca9-f8d0-4968-b889-079e4c1ffd6f
# ╟─434ef478-3298-4ea7-b8cb-161181abdb2a
# ╠═896d37cc-38be-497c-bdd3-8189327aaacb
# ╠═e72d6e9e-8234-4090-8c8d-187ff5bce5b8
# ╠═3b8ce9f3-137b-46a1-81d5-4334e81df27e
# ╟─00000000-0000-0000-0000-000000000001
# ╟─00000000-0000-0000-0000-000000000002
