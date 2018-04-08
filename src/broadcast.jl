using Base.Cartesian
using Base.Broadcast: newindex, _broadcast_getindex

@generated function broadcast_kernel(f, C::AbstractArray, keeps::K, Idefaults::ID, A::AT, Bs::BT) where {K,ID,AT,BT}
    N = length(Bs.parameters)+1
    quote
        A_1 = A
        @nexprs $(N-1) i-> A_{i+1} = Bs[i]
        @nexprs $N i -> keep_i = keeps[i]
        @nexprs $N i -> Idefault_i = Idefaults[i]

        I = CartesianIndex(@cuindex C)
        @nexprs $N i -> I_i = newindex(I, keep_i, Idefault_i)
        @nexprs $N i -> @inbounds val_i = _broadcast_getindex(A_i, I_i)
        result = @ncall $N f val
        @inbounds C[I] = result
    end
end

@inline function _broadcast!(f, C::AbstractArray, keeps, Idefaults, A, Bs)
    blk, thr = cudims(C)
    @cuda blocks=blk threads=thr broadcast_kernel(f, C, keeps, Idefaults, A, Bs)
    return C
end

using Base.Broadcast: map_newindexer, _broadcast_eltype, broadcast_indices,
    check_broadcast_indices

Base.Broadcast.broadcast_indices(::Type{CuArray}, A::Ref) = ()
Base.Broadcast.broadcast_indices(::Type{CuArray}, A) = indices(A)

# TODO: computed eltype broadcast?
@inline function broadcast_t(f, T, shape, A, Bs::Vararg{Any,N}) where N
    isleaftype(T) || error("Broadcast output type $T is not concrete")
    C = similar(CuArray{T}, shape)
    keeps, Idefaults = map_newindexer(shape, A, Bs)
    _broadcast!(f, C, keeps, Idefaults, A, Bs)
end

# Called by Base broadcasting mechanisms (in place and out of place)

Base.Broadcast._containertype(::Type{<:CuArray}) = CuArray
Base.Broadcast.promote_containertype(::Type{Any}, ::Type{CuArray}) = CuArray
Base.Broadcast.promote_containertype(::Type{CuArray}, ::Type{Any}) = CuArray

@inline function Base.Broadcast.broadcast_c!(f, ::Type{CuArray}, ::Type, C, A, Bs::Vararg{Any,N}) where N
    shape = indices(C)
    @boundscheck check_broadcast_indices(shape, A, Bs...)
    keeps, Idefaults = map_newindexer(shape, A, Bs)
    _broadcast!(f, C, keeps, Idefaults, A, Bs)
end

@inline function Base.Broadcast.broadcast_c(f, ::Type{CuArray}, A, Bs...)
    T = _broadcast_eltype(f, A, Bs...)
    shape = broadcast_indices(A, Bs...)
    iter = CartesianRange(shape)
    if isleaftype(T)
        return broadcast_t(f, T, shape, A, Bs...)
    end
    if isempty(iter)
        return similar(CuArray{T}, shape)
    end
    return broadcast_t(f, Any, shape, A, Bs...)
end

# Hacky interop

Base.Broadcast._containertype(::Type{<:RowVector{<:Any,<:CuArray}}) = CuArray
cudaconvert(x::RowVector{<:Any,<:CuArray}) = RowVector(cudaconvert(x.vec))

# Broadcast function fixes

import NNlib: @fix, _cufunc

_cufunc(f,x::CuArray,xs...) = cufunc(f)

cufunc(x) = x

libdevice = :[
  cos, cospi, sin, sinpi, tan, acos, asin, atan, atan2,
  cosh, sinh, tanh, acosh, asinh, atanh,
  log, log10, log1p, log2, logb, ilogb,
  exp, exp2, exp10, expm1, ldexp,
  erf, erfinv, erfc, erfcinv, erfcx,
  brev, clz, ffs, byte_perm, popc,
  isfinite, isinf, isnan, nearbyint,
  nextafter, signbit, copysign, abs,
  sqrt, rsqrt, cbrt, rcbrt, pow,
  ceil, floor, saturate,
  lgamma, tgamma,
  j0, j1, jn, y0, y1, yn,
  normcdf, normcdfinv, hypot,
  fma, sad, dim, mul24, mul64hi, hadd, rhadd, scalbn].args

for f in libdevice
  isdefined(Base, f) || continue
  @eval cufunc(::typeof(Base.$f)) = CUDAnative.$f
end

# ForwardDiff Integration

using MacroTools

function replace_device(ex)
  MacroTools.postwalk(ex) do x
    x in libdevice ? :(CUDAnative.$x) : x
  end
end

macro cufunc(ex)
  def = MacroTools.splitdef(ex)
  f = def[:name]
  def[:name] = Symbol(:cu, f)
  def[:body] = replace_device(def[:body])
  quote
    $(esc(MacroTools.combinedef(def)))
    CuArrays.cufunc(::typeof($(esc(f)))) = $(esc(def[:name]))
  end
end

using ForwardDiff: Dual, value, partials, unary_dual_definition
using DiffRules

for f in libdevice
  if haskey(DiffRules.DEFINED_DIFFRULES, (:Base,f,1))
    f == :tanh && continue
    diffrule = DiffRules.DEFINED_DIFFRULES[(:Base,f,1)]
    DiffRules.DEFINED_DIFFRULES[(:CUDAnative,f,1)] =
      (args...) -> replace_device(diffrule(args...))
    eval(unary_dual_definition(:CUDAnative, f))
  end
end

DiffRules.DEFINED_DIFFRULES[(:CUDAnative, :tanh, 1)] = x ->
  replace_device(:(1-tanh(x)^2))
eval(unary_dual_definition(:CUDAnative, :tanh))
