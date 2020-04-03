using NNlib

# Activation functions

@cufunc σ(x) = ifelse(x < -80, zero(x), one(x) / (one(x) + exp(-x)))

@cufunc function logσ(x)
  max_v = max(zero(x), -x)
  z = exp(-max_v) + exp(-x-max_v)
  -(max_v + log(z))
end

@cufunc elu(x, α = one(x)) =
  ifelse(x ≥ 0, x/1, α * (exp(x) - one(x)))

@cufunc swish(x) = x * σ(x)

@cufunc function gelu(x)
  λ = oftype(x/1, √(2/π))
  α = oftype(x/1, 0.044715)
  h = oftype(x/1, 0.5)
  h * x * (one(x) + tanh(λ * (x + α * x^3)))
end

@cufunc function selu(x)
  λ = oftype(x/1, 1.0507009873554804934193349852946)
  α = oftype(x/1, 1.6732632423543772848170429916717)
  λ * ifelse(x > 0, x/1, α * (exp(x) - 1))
end

@cufunc softplus(x) = ifelse(x > 0, x + log1p(exp(-x)), log1p(exp(x)))


# Batched matrix multiplication
# Using storage_type from https://github.com/FluxML/NNlib.jl/pull/191

NNlib._batched_gemm!(::Type{<:CuArray}, transA::Char, transB::Char, α::Number, A, B, β::Number, C) =
    CuArrays.CUBLAS.gemm_strided_batched!(transA, transB, α, A, B, β, C)

# This is https://github.com/JuliaLang/julia/pull/35304, here just for testing now:
Base.similar(A::PermutedDimsArray, T::Type, dims::Base.Dims) = similar(parent(A), T, dims)
# @which Base.similar(PermutedDimsArray(rand(2,2), (2,1)), Int, Base.Dims{2}((3,3)))

