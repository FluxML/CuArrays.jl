using Base.Cartesian

function cudims(n::Integer)
  threads = 256
  ceil(Int, n / threads), threads
end

cudims(a::AbstractArray) = cudims(length(a))

@inline ind2sub_(a::AbstractArray{T,0}, i) where T = ()
@inline ind2sub_(a, i) = Tuple(CartesianIndices(a)[i])

macro cuindex(A)
  quote
    A = $(esc(A))
    i = (blockIdx().x-UInt32(1)) * blockDim().x + threadIdx().x
    i > length(A) && return
    ind2sub_(A, i)
  end
end

function Base.fill!(xs::CuArray, x)
  function kernel(xs, x)
    I = @cuindex xs
    xs[I...] = x
    return
  end
  blk, thr = cudims(xs)
  @cuda blocks=blk threads=thr kernel(xs, convert(eltype(xs), x))
  return xs
end

Base.fill(::Type{CuArray}, x, dims) = fill!(CuArray{typeof(x)}(dims), x)

genperm(I::NTuple{N}, perm::NTuple{N}) where N =
  ntuple(d->I[perm[d]], Val{N})

function Base.permutedims!(dest::CuArray, src::CuArray, perm::NTuple)
  function kernel(dest, src, perm)
    I = @cuindex src
    @inbounds dest[genperm(I, perm)...] = src[I...]
    return
  end
  blk, thr = cudims(dest)
  @cuda blocks=blk threads=thr kernel(dest, src, perm)
  return dest
end

Base.permutedims!(dest::CuArray, src::CuArray, perm) =
  permutedims!(dest, src, (perm...,))

allequal(x) = true
allequal(x, y, z...) = x == y && allequal(y, z...)

function Base.map!(f, y::CuArray, xs::CuArray...)
  @assert allequal(size.((y, xs...))...)
  return y .= f.(xs...,)
end

function Base.map(f, y::CuArray, xs::CuArray...)
  @assert allequal(size.((y, xs...))...)
  return f.(y, xs...)
end

# Break ambiguities with base
Base.map!(f, y::CuArray) =
  invoke(map!, Tuple{Any,CuArray,Vararg{CuArray}}, f, y)
Base.map!(f, y::CuArray, x::CuArray) =
  invoke(map!, Tuple{Any,CuArray,Vararg{CuArray}}, f, y, x)
Base.map!(f, y::CuArray, x1::CuArray, x2::CuArray) =
  invoke(map!, Tuple{Any,CuArray,Vararg{CuArray}}, f, y, x1, x2)

# Concatenation

@generated function nindex(i::T, ls::NTuple{N,T}) where {N,T}
  na = one(i)
  quote
    Base.@_inline_meta
    $(foldr((n, els) -> :(i ≤ ls[$n] ? ($n, i) : (i -= ls[$n]; $els)), :($na, $na), one(i):i(N)))
  end
end

@inline function catindex(dim, I::NTuple{N}, shapes) where N
  @inbounds x, i = nindex(I[dim], getindex.(shapes, dim))
  x, ntuple(n -> n == dim ? i : I[n], Val{N})
end

function growdims(dim, x)
  if ndims(x) >= dim
    x
  else
    reshape(x, size.((x,), 1:dim)...)
  end
end

function _cat(dim, dest, xs...)
  function kernel(dim, dest, xs)
    I = @cuindex dest
    @inbounds n, I′ = catindex(dim, Int.(I), size.(xs))
    @inbounds dest[I...] = xs[n][I′...]
    return
  end
  xs = growdims.(dim, xs)
  blk, thr = cudims(dest)
  @cuda blocks=blk threads=thr kernel(dim, dest, xs)
  return dest
end

function Base.cat_t(dims::Integer, T::Type, x::CuArray, xs::CuArray...)
  catdims = Base.dims2cat(dims)
  shape = Base.cat_shape(catdims, (), size.((x, xs...))...)
  dest = Base.cat_similar(x, T, shape)
  _cat(dims, dest, x, xs...)
end

Base.vcat(xs::CuArray...) = cat(1, xs...)
Base.hcat(xs::CuArray...) = cat(2, xs...)
