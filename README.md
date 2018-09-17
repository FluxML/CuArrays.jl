# CuArrays

[![][gitlab-img]][gitlab-url]
[![][codecov-img]][codecov-url]

[gitlab-img]: https://gitlab.com/JuliaGPU/CuArrays.jl/badges/master/pipeline.svg
[gitlab-url]: https://gitlab.com/JuliaGPU/CuArrays.jl/pipelines

[codecov-img]: https://codecov.io/gh/JuliaGPU/CuArrays.jl/branch/master/graph/badge.svg
[codecov-url]: https://codecov.io/gh/JuliaGPU/CuArrays.jl

CuArrays provides a fully-functional GPU array, which can give significant speedups over normal arrays without code changes. CuArrays are implemented fully in Julia, making the implementation [elegant and extremely generic](http://mikeinnes.github.io/2017/08/24/cudanative.html).

## Features

```julia
xs = cu(rand(5, 5))
ys = cu[1, 2, 3]
xs_cpu = collect(xs)
```

Because `CuArray` is an `AbstractArray`, it doesn't have much of a learning curve; just use your favourite array ops as usual. The following are supported (on arbitrary numbers of arguments, dimensions etc):

* Conversions and `copy!` with CPU arrays
* General indexing (`xs[1:2, 5, :]`)
* `permutedims`
* Concatenation (`vcat(x, y)`, `cat(3, xs, ys, zs)`)
* `map`, fused broadcast (`zs .= xs.^2 .+ ys .* 2`)
* `fill!(xs, 0)`
* Reduction over dimensions (`reducedim(+, xs, 3)`, `sum(x -> x^2, xs, 1)` etc)
* Reduction to scalar (`reduce(*, 1, xs)`, `sum(xs)` etc)
* Various BLAS operations (matrix\*matrix, matrix\*vector)
* FFTs, using the AbstractFFTs API

We welcome issues or PRs for functionality not on this list.

Note that some operations not on this list will work, but be slow, due to Base's generic implementations. This is intentional, to enable a "make it work, then make it fast" workflow. When you're ready you can disable slow fallback methods:

```julia
julia> CuArrays.allowscalar(false)
julia> xs[5]
ERROR: getindex is disabled
```
