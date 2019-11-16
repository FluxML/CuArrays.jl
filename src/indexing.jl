import GPUArrays: allowscalar, @allowscalar

function _getindex(xs::CuArray{T}, i::Integer) where T
  buf = Array{T}(undef)
  copyto!(buf, 1, xs, i, 1)
  buf[]
end

function _setindex!(xs::CuArray{T}, v::T, i::Integer) where T
  copyto!(xs, i, T[v], 1, 1)
end


## logical indexing

Base.getindex(xs::CuArray, bools::AbstractArray{Bool}) = getindex(xs, CuArray(bools))

function Base.getindex(xs::CuArray{T}, bools::CuArray{Bool}) where {T}
  bools = reshape(bools, prod(size(bools)))
  indices = cumsum(bools)  # unique indices for elements that are true

  n = _getindex(indices, length(indices))  # number that are true
  ys = CuArray{T}(undef, n)

  if n > 0
    function kernel(ys::CuDeviceArray{T}, xs::CuDeviceArray{T}, bools, indices)
        i = threadIdx().x + (blockIdx().x - 1) * blockDim().x

        @inbounds if i <= length(xs) && bools[i]
            b = indices[i]   # new position
            ys[b] = xs[i]
        end

        return
    end

    function configurator(kernel)
        config = launch_configuration(kernel.fun)

        threads = min(length(indices), config.threads)
        blocks = cld(length(indices), threads)

        return (threads=threads, blocks=blocks)
    end

    @cuda name="logical_getindex" config=configurator kernel(ys, xs, bools, indices)
  end

  unsafe_free!(indices)

  return ys
end


## find*

function Base.findall(bools::CuArray{Bool})
    I = if VERSION >= v"1.2"
        keytype(bools)
    elseif bools isa CuVector
        Int
    else
        CartesianIndex{ndims(bools)}
    end
    indices = cumsum(reshape(bools, prod(size(bools))))

    n = _getindex(indices, length(indices))
    ys = CuArray{I}(undef, n)

    if n > 0
        function kernel(ys::CuDeviceArray, bools, indices)
            i = threadIdx().x + (blockIdx().x - 1) * blockDim().x

            @inbounds if i <= length(bools) && bools[i]
                i′ = CartesianIndices(bools)[i]
                b = indices[i]   # new position
                ys[b] = i′
            end

            return
        end

        function configurator(kernel)
            config = launch_configuration(kernel.fun)

            threads = min(length(indices), config.threads)
            blocks = cld(length(indices), threads)

            return (threads=threads, blocks=blocks)
        end

        @cuda name="findall" config=configurator kernel(ys, bools, indices)
    end

    unsafe_free!(indices)

    return ys
end

function Base.findall(f::Function, A::CuArray)
    bools = map(f, A)
    ys = findall(bools)
    unsafe_free!(bools)
    return ys
end

function Base.findfirst(testf::Function, xs::CuArray)
    I = if VERSION >= v"1.2"
        keytype(xs)
    else
        eltype(keys(xs))
    end

    y = CuArray([typemax(Int)])

    function kernel(y::CuDeviceArray, xs::CuDeviceArray)
        i = threadIdx().x + (blockIdx().x - 1) * blockDim().x

        @inbounds if i <= length(xs) && testf(xs[i])
            CUDAnative.@atomic y[1] = min(y[1], i)
        end

        return
    end

    function configurator(kernel)
        config = launch_configuration(kernel.fun)

        threads = min(length(xs), config.threads)
        blocks = cld(length(xs), threads)

        return (threads=threads, blocks=blocks)
    end

    @cuda name="findfirst" config=configurator kernel(y, xs)

    first_i = _getindex(y, 1)
    return keys(xs)[first_i]
end

Base.findfirst(xs::CuArray{Bool}) = findfirst(identity, xs)

function Base.findmin(a::CuArray; dims=:)
    if dims != Colon()
        error("Unsupported")
    end
    m = minimum(a)
    i = findfirst(x->x==m, a)
    return (m, i)
end

function Base.findmax(a::CuArray; dims=:)
    if dims != Colon()
        error("Unsupported")
    end
    m = maximum(a)
    i = findfirst(x->x==m, a)
    return (m, i)
end
