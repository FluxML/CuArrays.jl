# Pkg.test runs with --check_bounds=1, forcing all bounds checks.
# This is incompatible with CUDAnative (see JuliaGPU/CUDAnative.jl#98)
if Base.JLOptions().check_bounds == 1
  file = @__FILE__
  run(```
    $(Base.julia_cmd())
    --color=$(Base.have_color ? "yes" : "no")
    --compiled-modules=$(Bool(Base.JLOptions().use_compiled_modules) ? "yes" : "no")
    --startup-file=$(Base.JLOptions().startupfile != 2 ? "yes" : "no")
    --code-coverage=$(["none", "user", "all"][1+Base.JLOptions().code_coverage])
    $(file)
    ```)
  exit()
end

using CuArrays

using CUDAnative
import CUDAdrv

using Test
using Random
using LinearAlgebra


Random.seed!(1)
CuArrays.allowscalar(false)

testf(f, xs...) = GPUArrays.TestSuite.compare(f, CuArray, xs...)

using GPUArrays, GPUArrays.TestSuite

@testset "CuArrays" begin
@testset "GPUArray Testsuite" begin
    TestSuite.test_construction(CuArray)
    TestSuite.test_gpuinterface(CuArray)
    TestSuite.test_indexing(CuArray)
    TestSuite.test_io(CuArray)
    TestSuite.test_base(CuArray)
    #TestSuite.test_vectors(CuArray)
    TestSuite.test_mapreduce(CuArray)
    #TestSuite.test_broadcasting(CuArray)
    TestSuite.test_linalg(CuArray)
    TestSuite.test_fft(CuArray)
    TestSuite.test_blas(CuArray)
    TestSuite.test_random(CuArray)
end

@testset "Array" begin
  xs = CuArray(2, 3)
  @test collect(CuArray([1 2; 3 4])) == [1 2; 3 4]
  @test collect(cu[1, 2, 3]) == [1, 2, 3]
  @test collect(cu([1, 2, 3])) == [1, 2, 3]
  @test testf(vec, rand(5,3))
end

@testset "Broadcast" begin
  @test testf((x)       -> fill!(x, 1),  rand(3,3))
  @test testf((x, y)    -> map(+, x, y), rand(2, 3), rand(2, 3))
  @test testf((x)       -> sin.(x),      rand(2, 3))
  @test testf((x)       -> 2x,           rand(2, 3))
  @test testf((x, y)    -> x .+ y,       rand(2, 3), rand(1, 3))
  @test testf((z, x, y) -> z .= x .+ y,  rand(2, 3), rand(2, 3), rand(2))
end

# https://github.com/JuliaGPU/CUDAnative.jl/issues/223
@testset "Ref Broadcast" begin
  foobar(idx, A) = A[idx]
  @test CuArray([42]) == foobar.(CuArray([1]), Base.RefValue(CuArray([42])))
end

using ForwardDiff: Dual
using NNlib

@testset "Broadcast Fix" begin
  @test testf(x -> log.(x), rand(3,3))
  @test testf((x,xs) -> log.(x.+xs), Ref(1), rand(3,3))

  if CuArrays.cudnn_available()
    @test testf(x -> logσ.(x), rand(5))

    f(x) = logσ.(x)
    ds = Dual.(rand(5),1)
    @test f(ds) ≈ collect(f(CuArray(ds)))
  end
end

@testset "Reduce" begin
  @test testf(x -> sum(x, dims=1), rand(2, 3))
  @test testf(x -> sum(x, dims=2), rand(2, 3))
  @test testf(x -> sum(x -> x^2, x, dims=1), rand(2, 3))
  @test testf(x -> prod(x, dims=2), rand(2, 3))

  @test testf(x -> sum(x), rand(2, 3))
  @test testf(x -> prod(x), rand(2, 3))
end

@testset "0D" begin
  x = CuArray{Float64}()
  x .= 1
  @test collect(x)[] == 1
  x /= 2
  @test collect(x)[] == 0.5
end

@testset "Slices" begin
  x = cu([1:10;])
  y = x[6:10]
  @test x.buf == y.buf
  @test collect(y) == [6, 7, 8, 9, 10]
  CuArrays._setindex!(y, -1f0, 3)
  @test collect(y) == [6, 7, -1, 9, 10]
  @test collect(x) == [1, 2, 3, 4, 5, 6, 7, -1, 9, 10]
  @test collect(CuMatrix{eltype(y)}(I, 5, 5)*y) == collect(y)
end

@testset "$f! with diagonal $d" for (f, f!) in ((triu, triu!), (tril, tril!)),
                                          d in -2:2
  A = randn(10, 10)
  @test f(A, d) == Array(f!(CuArray(A), d))
end

if CuArrays.cudnn_available()
  include("nnlib.jl")
end
include("blas.jl")
include("solver.jl")
include("fft.jl")
include("rand.jl")

end
