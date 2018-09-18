
# CURAND status codes
const CURAND_STATUS_SUCCESS = 0
const CURAND_STATUS_VERSION_MISMATCH = 100
const CURAND_STATUS_NOT_INITIALIZED = 101
const CURAND_STATUS_ALLOCATION_FAILED = 102
const CURAND_STATUS_TYPE_ERROR = 103
const CURAND_STATUS_OUT_OF_RANGE = 104
const CURAND_STATUS_LENGTH_NOT_MULTIPLE = 105
const CURAND_STATUS_DOUBLE_PRECISION_REQUIRED = 106
const CURAND_STATUS_LAUNCH_FAILURE = 201
const CURAND_STATUS_PREEXISTING_FAILURE = 202
const CURAND_STATUS_INITIALIZATION_FAILED = 203
const CURAND_STATUS_ARCH_MISMATCH = 204
const CURAND_STATUS_INTERNAL_ERROR = 999

# CURAND RNG types (curandRngType)
const CURAND_RNG_TEST = 0
const CURAND_RNG_PSEUDO_DEFAULT = 100
const CURAND_RNG_PSEUDO_XORWOW = 101
const CURAND_RNG_PSEUDO_MRG32K3A = 121
const CURAND_RNG_PSEUDO_MTGP32 = 141
const CURAND_RNG_PSEUDO_MT19937 = 142
const CURAND_RNG_PSEUDO_PHILOX4_32_10 = 161
const CURAND_RNG_QUASI_DEFAULT = 200
const CURAND_RNG_QUASI_SOBOL32 = 201
const CURAND_RNG_QUASI_SCRAMBLED_SOBOL32 = 202
const CURAND_RNG_QUASI_SOBOL64 = 203
const CURAND_RNG_QUASI_SCRAMBLED_SOBOL64 = 204

# CURAND ordering of results in memory
const CURAND_ORDERING_PSEUDO_BEST = 100
const CURAND_ORDERING_PSEUDO_DEFAULT = 101
const CURAND_ORDERING_PSEUDO_SEEDED = 102
const CURAND_ORDERING_QUASI_DEFAULT = 201

# CURAND choice of direction vector set
const CURAND_DIRECTION_VECTORS_32_JOEKUO6 = 101
const CURAND_SCRAMBLED_DIRECTION_VECTORS_32_JOEKUO6 = 102
const CURAND_DIRECTION_VECTORS_64_JOEKUO6 = 103
const CURAND_SCRAMBLED_DIRECTION_VECTORS_64_JOEKUO6 = 104

# CURAND method
const CURAND_CHOOSE_BEST = 0
const CURAND_ITR = 1
const CURAND_KNUTH = 2
const CURAND_HITR = 3
const CURAND_M1 = 4
const CURAND_M2 = 5
const CURAND_BINARY_SEARCH = 6
const CURAND_DISCRETE_GAUSS = 7
const CURAND_REJECTION = 8
const CURAND_DEVICE_API = 9
const CURAND_FAST_REJECTION = 10
const CURAND_3RD = 11
const CURAND_DEFINITION = 12
const CURAND_POISSON = 13


const curandStatus_t = UInt32

mutable struct RNG
    ptr::Ptr{Nothing}
    rng_type::Int
end

mutable struct DiscreteDistribution
    ptr::Ptr{Nothing}
end
